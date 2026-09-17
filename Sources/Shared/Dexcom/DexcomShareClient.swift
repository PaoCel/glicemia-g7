import Foundation

/// Minimal client for the Dexcom Share service — the same endpoints the official
/// "Follow" app uses. There is no public SDK, so the shapes below are the ones the
/// service actually returns rather than anything documented.
///
/// Two things have to be true on the Dexcom side or the account publishes nothing:
/// Share must be switched on in the Dexcom app, and there must be at least one
/// follower invited. That case is reported as `.noDataPublished` instead of an error,
/// because it is a setup problem the user can fix.
actor DexcomShareClient {

    /// The identifier the Share service expects from Follow-style clients.
    private static let applicationId = "d89443d2-327c-4a6f-89e5-496bbb0317db"
    private static let emptySession = "00000000-0000-0000-0000-000000000000"

    private let credentials: DexcomCredentials
    private let session: URLSession

    private var accountId: String?
    private var sessionId: String?

    init(credentials: DexcomCredentials) {
        self.credentials = credentials

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 25
        configuration.timeoutIntervalForResource = 40
        configuration.waitsForConnectivity = false
        self.session = URLSession(configuration: configuration)
    }

    // MARK: - Public surface

    /// Latest reading, logging in first if needed. A session that the server has
    /// forgotten is retried exactly once, so a stale session never surfaces as an error.
    func fetchLatestReading() async throws -> GlucoseReading {
        do {
            return try await readLatest(sessionId: try await activeSession())
        } catch DexcomShareError.sessionInvalid {
            sessionId = nil
            return try await readLatest(sessionId: try await activeSession())
        }
    }

    /// Used by the "verifica" button in the settings screen: proves the credentials
    /// work without caring whether a reading exists yet.
    func verifyCredentials() async throws {
        sessionId = nil
        accountId = nil
        _ = try await activeSession()
    }

    // MARK: - Session

    private func activeSession() async throws -> String {
        if let sessionId = sessionId { return sessionId }

        let accountId: String
        if let cached = self.accountId {
            accountId = cached
        } else {
            accountId = try await fetchAccountId()
            self.accountId = accountId
        }

        let id: String = try await postForString(
            path: "General/LoginPublisherAccountById",
            body: [
                "accountId": accountId,
                "password": credentials.password,
                "applicationId": Self.applicationId,
            ]
        )
        guard id != Self.emptySession else { throw DexcomShareError.credentialsRejected }
        sessionId = id
        return id
    }

    private func fetchAccountId() async throws -> String {
        let id: String = try await postForString(
            path: "General/AuthenticatePublisherAccount",
            body: [
                "accountName": credentials.username,
                "password": credentials.password,
                "applicationId": Self.applicationId,
            ]
        )
        guard id != Self.emptySession else { throw DexcomShareError.credentialsRejected }
        return id
    }

    // MARK: - Readings

    private func readLatest(sessionId: String) async throws -> GlucoseReading {
        var components = URLComponents()
        components.scheme = "https"
        components.host = credentials.region.host
        components.path = "/ShareWebServices/Services/Publisher/ReadPublisherLatestGlucoseValues"
        components.queryItems = [
            URLQueryItem(name: "sessionId", value: sessionId),
            // A day of history costs nothing and survives a phone that was offline.
            URLQueryItem(name: "minutes", value: "1440"),
            URLQueryItem(name: "maxCount", value: "1"),
        ]
        guard let url = components.url else { throw DexcomShareError.malformedResponse }

        let data = try await perform(request(url: url, body: nil))
        let entries = try decodeEntries(from: data)
        guard let entry = entries.first else { throw DexcomShareError.noDataPublished }

        return GlucoseReading(
            mgdl: entry.value,
            trend: entry.trend,
            date: entry.date,
            source: .dexcomShare
        )
    }

    // MARK: - Transport

    private func request(url: URL, body: [String: String]?) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        // The Share service rejects requests without a Follow-style user agent.
        request.setValue("Dexcom Share/3.0.2.11 CFNetwork/672.0.2 Darwin/14.0.0",
                         forHTTPHeaderField: "User-Agent")
        if let body = body {
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }
        return request
    }

    private func postForString(path: String, body: [String: String]) async throws -> String {
        guard let url = URL(string: "https://\(credentials.region.host)/ShareWebServices/Services/\(path)") else {
            throw DexcomShareError.malformedResponse
        }
        let data = try await perform(request(url: url, body: body))

        // The service answers with a bare quoted JSON string.
        guard let raw = String(data: data, encoding: .utf8) else {
            throw DexcomShareError.malformedResponse
        }
        return raw.trimmingCharacters(in: CharacterSet(charactersIn: "\"\n\r "))
    }

    private func perform(_ request: URLRequest) async throws -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw DexcomShareError.transport(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw DexcomShareError.malformedResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw Self.error(fromFault: data, statusCode: http.statusCode)
        }
        return data
    }

    /// Share reports failures as a JSON object with a `Code`, not as a plain HTTP status.
    private static func error(fromFault data: Data, statusCode: Int) -> DexcomShareError {
        guard let fault = try? JSONDecoder().decode(Fault.self, from: data) else {
            return .transport("HTTP \(statusCode)")
        }
        return error(from: fault)
    }

    private static func error(from fault: Fault) -> DexcomShareError {
        switch fault.code {
        case "SessionIdNotFound", "SessionNotValid":
            return .sessionInvalid
        case "SSO_AuthenticateAccountNotFound",
             "SSO_AuthenticatePasswordInvalid",
             "AccountPasswordInvalid",
             "SSO_AuthenticateMaxAttemptsExceeed":
            return .credentialsRejected
        case "MonitoringSessionNotActive", "MonitorSessionNotFound", "InvalidArgument":
            return .noDataPublished
        default:
            return .service(fault.message ?? fault.code)
        }
    }

    private struct Fault: Decodable {
        let code: String
        let message: String?

        enum CodingKeys: String, CodingKey {
            case code = "Code"
            case message = "Message"
        }
    }

    // MARK: - Entry decoding

    private func decodeEntries(from data: Data) throws -> [Entry] {
        if let entries = try? JSONDecoder().decode([Entry].self, from: data) {
            return entries
        }
        // An account that publishes nothing answers with a fault object where the
        // array should be, with a 200 status.
        if let fault = try? JSONDecoder().decode(Fault.self, from: data) {
            throw Self.error(from: fault)
        }
        throw DexcomShareError.malformedResponse
    }

    struct Entry: Decodable {
        let value: Int
        let trend: TrendDirection
        let date: Date

        enum CodingKeys: String, CodingKey {
            case value = "Value"
            case trend = "Trend"
            case wt = "WT"
            case st = "ST"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            value = try container.decode(Int.self, forKey: .value)

            // Older deployments answer with the numeric trend, newer ones with its name.
            if let raw = try? container.decode(Int.self, forKey: .trend) {
                trend = TrendDirection(shareValue: raw)
            } else if let name = try? container.decode(String.self, forKey: .trend) {
                trend = Entry.trend(named: name)
            } else {
                trend = .unknown
            }

            // WT is the sensor's wall time; ST is the phone's. WT is the one to trust.
            let stamp = (try? container.decode(String.self, forKey: .wt))
                ?? (try? container.decode(String.self, forKey: .st))
            guard let stamp = stamp, let date = Entry.date(fromShareStamp: stamp) else {
                throw DexcomShareError.malformedResponse
            }
            self.date = date
        }

        /// "Date(1615229400000)" and "/Date(1615229400000+0000)/" both appear in the wild.
        static func date(fromShareStamp stamp: String) -> Date? {
            let digits = stamp.drop { !$0.isNumber }.prefix { $0.isNumber }
            guard let milliseconds = Double(digits) else { return nil }
            return Date(timeIntervalSince1970: milliseconds / 1000)
        }

        static func trend(named name: String) -> TrendDirection {
            switch name.lowercased() {
            case "doubleup": return .doubleUp
            case "singleup": return .singleUp
            case "fortyfiveup": return .fortyFiveUp
            case "flat": return .flat
            case "fortyfivedown": return .fortyFiveDown
            case "singledown": return .singleDown
            case "doubledown": return .doubleDown
            case "notcomputable": return .notComputable
            case "rateoutofrange": return .rateOutOfRange
            default: return .unknown
            }
        }
    }
}

enum DexcomShareError: Error {
    case credentialsRejected
    case sessionInvalid
    case noDataPublished
    case transport(String)
    case service(String)
    case malformedResponse

    /// Collapsed into the source-level vocabulary the UI understands.
    var asSourceError: GlucoseSourceError {
        switch self {
        case .credentialsRejected: return .credentialsRejected
        case .noDataPublished: return .noDataPublished
        case .transport(let detail): return .unreachable(detail)
        case .sessionInvalid: return .unreachable("sessione scaduta")
        case .service(let message): return .server(message)
        case .malformedResponse: return .server("risposta non riconosciuta")
        }
    }
}
