import Foundation

/// Polls Dexcom Share and hands readings to whoever is listening.
///
/// The cadence follows the sensor rather than the clock: a G7 publishes every five
/// minutes, so after a reading the next poll is scheduled just after the next one is
/// due. Polling faster only burns battery and invites throttling.
final class DexcomShareSource: GlucoseSource {

    var onReading: ((GlucoseReading) -> Void)?
    var onError: ((GlucoseSourceError) -> Void)?

    let displayName = "Dexcom Share"

    private let client: DexcomShareClient
    private let region: DexcomRegion

    private var loop: Task<Void, Never>?
    private var lastReadingDate: Date?
    private var consecutiveFailures = 0

    /// G7 publishes on a five minute cadence.
    private static let publishInterval: TimeInterval = 5 * 60
    /// Small lag so we ask after the value has landed on the server, not while it lands.
    private static let publishLag: TimeInterval = 25
    /// Never hammer the service, whatever the caller asks for.
    private static let minimumSpacing: TimeInterval = 45

    init(credentials: DexcomCredentials) {
        self.client = DexcomShareClient(credentials: credentials)
        self.region = credentials.region
    }

    func start() {
        guard loop == nil else { return }
        loop = Task { [weak self] in
            await self?.run()
        }
    }

    func stop() {
        loop?.cancel()
        loop = nil
    }

    func refreshNow() {
        // Restarting the loop makes it poll immediately, then fall back into cadence.
        stop()
        start()
    }

    func fetchOnce() async -> Bool {
        do {
            let reading = try await client.fetchLatestReading()
            lastReadingDate = reading.date
            consecutiveFailures = 0
            await MainActor.run { self.onReading?(reading) }
            return true
        } catch let error as DexcomShareError {
            let sourceError = error.asSourceError
            await MainActor.run { self.onError?(sourceError) }
            return false
        } catch {
            let message = error.localizedDescription
            await MainActor.run { self.onError?(.unreachable(message)) }
            return false
        }
    }

    // MARK: - Loop

    private func run() async {
        while !Task.isCancelled {
            let wait = await poll()
            guard !Task.isCancelled else { return }
            try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
        }
    }

    /// Performs one fetch and returns how long to wait before the next one.
    private func poll() async -> TimeInterval {
        do {
            let reading = try await client.fetchLatestReading()
            consecutiveFailures = 0
            lastReadingDate = reading.date
            await MainActor.run { self.onReading?(reading) }
            return delayAfter(reading: reading)
        } catch let error as DexcomShareError {
            let sourceError = error.asSourceError
            await MainActor.run { self.onError?(sourceError) }

            if sourceError == .credentialsRejected {
                // Retrying a rejected password locks the Dexcom account. Stop and wait
                // for the user to fix it in the settings screen.
                stop()
                return .greatestFiniteMagnitude
            }
            consecutiveFailures += 1
            return backoffDelay()
        } catch {
            consecutiveFailures += 1
            let message = error.localizedDescription
            await MainActor.run { self.onError?(.unreachable(message)) }
            return backoffDelay()
        }
    }

    private func delayAfter(reading: GlucoseReading) -> TimeInterval {
        let nextExpected = reading.date
            .addingTimeInterval(Self.publishInterval + Self.publishLag)
        let delay = nextExpected.timeIntervalSinceNow

        // A reading older than one interval means we are behind: poll again soon rather
        // than sleeping until a moment that has already passed.
        return min(max(delay, Self.minimumSpacing), Self.publishInterval)
    }

    private func backoffDelay() -> TimeInterval {
        // 30s, 60s, 120s, 240s, then hold at five minutes.
        let base: TimeInterval = 30
        let delay = base * pow(2, Double(min(consecutiveFailures - 1, 3)))
        return min(delay, Self.publishInterval)
    }
}
