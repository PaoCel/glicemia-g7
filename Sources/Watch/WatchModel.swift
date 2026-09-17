import Foundation
import Combine
import WatchConnectivity

/// Watch side of the link. It never talks to the network: the iPhone is the only source
/// of truth, and the last value is cached so an unreachable iPhone still leaves
/// something readable on the wrist.
final class WatchModel: NSObject, ObservableObject {

    /// Background tasks and the complication data source run outside the view
    /// hierarchy, so the model cannot be owned by a view.
    static let shared = WatchModel()

    @Published private(set) var reading: GlucoseReading?
    @Published private(set) var now = Date()
    @Published private(set) var reachable = false
    @Published private(set) var isRequesting = false
    @Published private(set) var lastError: String?
    @Published private(set) var receivedCount = 0

    private let store = LastReadingStore.shared
    private var sequence = 0
    private var tick: AnyCancellable?

    /// The Watch talks to Dexcom itself. Network access on the Watch is routed through
    /// the paired iPhone by the operating system, which does not require our iPhone app
    /// to be awake — only the phone to be in range. Depending on the iPhone app instead
    /// would mean the wrist shows a stale number whenever iOS has suspended it, which
    /// defeats the point of having a Watch app at all.
    private var dexcom: DexcomShareSource?
    private var isFetching = false

    /// Below this age a reading is current enough that a network round trip on a
    /// Series 3 costs more battery than it is worth.
    private static let freshEnough: TimeInterval = 4 * 60

    private override init() {
        super.init()
        reading = store.load()
        sequence = store.sequence

        tick = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] date in self?.now = date }

        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        } else {
            lastError = "WatchConnectivity non supportato"
        }

        reloadDexcom()
    }

    var isStandalone: Bool { dexcom != nil }

    private func reloadDexcom() {
        dexcom?.stop()
        dexcom = nil

        guard let credentials = DexcomCredentialStore.load() else { return }

        let source = DexcomShareSource(credentials: credentials)
        source.onReading = { [weak self] reading in
            self?.ingestLocal(reading)
        }
        source.onError = { [weak self] error in
            // A failure here is not worth shouting about while the iPhone may still be
            // able to supply the value; it is recorded and superseded by the next win.
            self?.lastError = error.shortDescription
            self?.isFetching = false
        }
        dexcom = source
    }

    private func ingestLocal(_ reading: GlucoseReading) {
        isFetching = false
        lastError = nil

        // The iPhone may have delivered the same reading first; whichever arrives
        // second must not restart the age.
        if let current = self.reading, reading.date <= current.date { return }

        self.reading = reading
        store.save(reading)
        ComplicationController.reload()
    }

    /// Fetches straight from Dexcom when the value on screen is no longer current.
    /// Called when the app comes to the front and from background refresh.
    func fetchIfNeeded(force: Bool = false) {
        guard let dexcom = dexcom, !isFetching else { return }
        if !force, let age = age, age < Self.freshEnough { return }

        isFetching = true
        Task { [weak self] in
            _ = await dexcom.fetchOnce()
            guard let self = self else { return }
            await MainActor.run { self.isFetching = false }
        }
    }

    var age: TimeInterval? {
        reading.map { now.timeIntervalSince($0.date) }
    }

    var freshness: Freshness {
        Freshness.of(age: age ?? .greatestFiniteMagnitude)
    }

    /// What the age line should say, combining data age with transport health.
    var link: LinkState {
        if isRequesting || isFetching { return .updating }
        if let error = lastError { return .sourceError(error) }
        if !reachable && freshness != .fresh { return .phoneUnreachable }
        return .ok
    }

    // MARK: - Actions

    func requestSnapshot() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated, session.isReachable else { return }

        isRequesting = true
        session.sendMessage(
            [WatchLink.MessageKind.key: WatchLink.MessageKind.requestSnapshot],
            replyHandler: { [weak self] reply in
                DispatchQueue.main.async {
                    self?.isRequesting = false
                    self?.apply(reply)
                }
            },
            errorHandler: { [weak self] error in
                DispatchQueue.main.async {
                    self?.isRequesting = false
                    self?.lastError = error.localizedDescription
                }
            }
        )
    }

    // MARK: - Ingest

    private func apply(_ payload: [String: Any]) {
        guard let snapshot = WatchLink.decode(payload) else { return }
        // Application context and live messages can race; the sequence keeps the newer one.
        guard snapshot.sequence >= sequence else { return }

        sequence = snapshot.sequence
        store.sequence = snapshot.sequence
        receivedCount += 1
        lastError = snapshot.error

        if let reading = snapshot.reading {
            self.reading = reading
            store.save(reading)
            ComplicationController.reload()
        }
    }
}

extension WatchModel: WCSessionDelegate {

    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            if let error = error { self.lastError = error.localizedDescription }
            self.reachable = session.isReachable
            // Whatever the phone last pushed is already waiting here after a cold launch.
            self.apply(session.receivedApplicationContext)
            self.requestSnapshot()
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.reachable = session.isReachable
            if session.isReachable {
                self.lastError = nil
                self.requestSnapshot()
            }
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext context: [String: Any]) {
        DispatchQueue.main.async { self.apply(context) }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        DispatchQueue.main.async { self.apply(message) }
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        DispatchQueue.main.async { self.applyCredentials(userInfo) }
    }

    private func applyCredentials(_ payload: [String: Any]) {
        guard payload[WatchLink.MessageKind.key] as? String == WatchLink.MessageKind.credentials else {
            apply(payload)
            return
        }

        if payload[WatchLink.CredentialKey.cleared] as? Bool == true {
            DexcomCredentialStore.clear()
            reloadDexcom()
            return
        }

        guard
            let username = payload[WatchLink.CredentialKey.username] as? String,
            let password = payload[WatchLink.CredentialKey.password] as? String
        else { return }

        let region = DexcomRegion(rawValue: payload[WatchLink.CredentialKey.region] as? String ?? "")
            ?? .outsideUS

        try? DexcomCredentialStore.save(
            DexcomCredentials(username: username, password: password, region: region)
        )
        reloadDexcom()
        fetchIfNeeded(force: true)
    }
}
