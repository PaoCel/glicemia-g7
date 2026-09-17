import Foundation
import Combine
import WatchConnectivity

/// Owns the glucose source on the iPhone and mirrors every reading to the Watch.
/// The source is Dexcom Share once an account is configured, and the simulator until
/// then, so the app is usable end to end before any credentials exist.
final class PhoneModel: NSObject, ObservableObject {

    @Published private(set) var reading: GlucoseReading?
    @Published private(set) var link: LinkState = .ok
    @Published private(set) var now = Date()

    @Published private(set) var sourceName: String = ""
    @Published private(set) var sourceError: GlucoseSourceError?
    @Published private(set) var isDexcomConfigured = false
    @Published private(set) var dexcomUsername: String?

    @Published private(set) var watchReachable = false
    @Published private(set) var watchAppInstalled = false
    @Published private(set) var watchPaired = false
    @Published private(set) var lastMirrorError: String?

    private var source: GlucoseSource?
    private let store = LastReadingStore.shared
    private var sequence = 0
    private var tick: AnyCancellable?

    override init() {
        super.init()
        reading = store.load()
        sequence = store.sequence

        tick = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] date in self?.now = date }

        activateSession()
        reloadSource()
    }

    // MARK: - Source

    /// Rebuilds the source from whatever is currently configured. Called at launch and
    /// whenever the account changes.
    func reloadSource() {
        source?.stop()
        source = nil
        sourceError = nil

        let credentials = DexcomCredentialStore.load()
        isDexcomConfigured = credentials != nil
        dexcomUsername = credentials?.username

        // Anything left over from a source we are no longer using is discarded rather
        // than shown next to a status line that now claims a different provider.
        let expectedOrigin: ReadingOrigin = credentials == nil ? .mock : .dexcomShare
        if let cached = reading, cached.source != expectedOrigin {
            reading = nil
            store.clear()
        }

        let source: GlucoseSource = credentials.map { DexcomShareSource(credentials: $0) }
            ?? MockGlucoseSource()

        source.onReading = { [weak self] reading in
            self?.ingest(reading)
        }
        source.onError = { [weak self] error in
            self?.handle(error)
        }

        self.source = source
        self.sourceName = source.displayName
        source.start()
    }

    func refreshNow() {
        link = .updating
        source?.refreshNow()
    }

    /// Entry point for `BGAppRefreshTask`. One fetch, one mirror, then tell the system
    /// we are done — holding the task open past its budget gets the app penalised.
    func performBackgroundRefresh() async -> Bool {
        guard let source = source else { return false }
        return await source.fetchOnce()
    }

    // MARK: - Account

    func saveCredentials(_ credentials: DexcomCredentials) throws {
        try DexcomCredentialStore.save(credentials)
        reloadSource()
        sendCredentialsToWatch()
    }

    /// The Watch fetches from Dexcom by itself, so it needs the account too. Queued
    /// rather than sent live: it has to arrive even if the Watch is currently asleep.
    private func sendCredentialsToWatch() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated, session.isWatchAppInstalled else { return }

        if let credentials = DexcomCredentialStore.load() {
            session.transferUserInfo(WatchLink.encodeCredentials(
                username: credentials.username,
                password: credentials.password,
                region: credentials.region.rawValue
            ))
        } else {
            session.transferUserInfo(WatchLink.encodeClearedCredentials())
        }
    }

    /// Checks a username and password without committing them, so a typo never replaces
    /// a working account.
    func verifyCredentials(_ credentials: DexcomCredentials) async -> Result<Void, GlucoseSourceError> {
        let client = DexcomShareClient(credentials: credentials)
        do {
            try await client.verifyCredentials()
            return .success(())
        } catch let error as DexcomShareError {
            return .failure(error.asSourceError)
        } catch {
            return .failure(.unreachable(error.localizedDescription))
        }
    }

    func clearCredentials() {
        DexcomCredentialStore.clear()
        reloadSource()
        sendCredentialsToWatch()
    }

    // MARK: - Ingest

    private func ingest(_ reading: GlucoseReading) {
        // Within one source, readings must move forward in time: re-polling the same
        // value must not reset its age. Across sources the rule cannot apply, because
        // the simulator stamps every reading with the current time while Dexcom stamps
        // it with the sensor's — so a real reading is almost always "older" than the
        // last simulated one, and would be discarded forever.
        if let current = self.reading,
           current.source == reading.source,
           reading.date <= current.date {
            self.link = .ok
            self.sourceError = nil
            return
        }

        self.reading = reading
        self.link = .ok
        self.sourceError = nil
        // Simulated values are never cached: they must not be what the app shows after
        // a relaunch, and they must not outlive the simulator itself.
        if reading.source == .mock {
            store.clear()
        } else {
            store.save(reading)
        }
        sequence += 1
        store.sequence = sequence
        mirror()
    }

    private func handle(_ error: GlucoseSourceError) {
        // The last good reading stays on screen: an error about fetching a new value
        // says nothing about the validity of the one already shown.
        sourceError = error
        link = .sourceError(error.shortDescription)
        mirror()
    }

    // MARK: - WatchConnectivity

    private func activateSession() {
        guard WCSession.isSupported() else {
            lastMirrorError = "WatchConnectivity non supportato"
            return
        }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    private func mirror() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }

        let payload = WatchLink.encode(
            reading: reading,
            error: sourceError?.shortDescription,
            sequence: sequence
        )
        do {
            // Application context is the reliable path on a Series 3: it is coalesced,
            // survives the Watch app being suspended, and does not need reachability.
            try session.updateApplicationContext(payload)
            lastMirrorError = nil
        } catch {
            lastMirrorError = error.localizedDescription
        }

        // With a complication on the watch face this is the highest priority channel
        // there is, and the only one that wakes the Watch app on its own. The daily
        // budget is small, so it is spent only on readings, never on error updates.
        if session.isComplicationEnabled,
           reading != nil,
           session.remainingComplicationUserInfoTransfers > 0 {
            session.transferCurrentComplicationUserInfo(payload)
        }

        // When the Watch app is in the foreground, this arrives immediately instead of
        // waiting for the system to schedule the context update.
        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil) { [weak self] error in
                DispatchQueue.main.async { self?.lastMirrorError = error.localizedDescription }
            }
        }
    }

    private func refreshWatchState(_ session: WCSession) {
        watchReachable = session.isReachable
        watchAppInstalled = session.isWatchAppInstalled
        watchPaired = session.isPaired
    }
}

extension PhoneModel: WCSessionDelegate {

    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            if let error = error {
                self.lastMirrorError = error.localizedDescription
            }
            self.refreshWatchState(session)
            if state == .activated {
                self.mirror()
                self.sendCredentialsToWatch()
            }
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.refreshWatchState(session)
            if session.isReachable { self.mirror() }
        }
    }

    func sessionWatchStateDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.refreshWatchState(session)
            self.sendCredentialsToWatch()
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard message[WatchLink.MessageKind.key] as? String == WatchLink.MessageKind.requestSnapshot else { return }
        DispatchQueue.main.async { self.mirror() }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        DispatchQueue.main.async {
            replyHandler(WatchLink.encode(
                reading: self.reading,
                error: self.sourceError?.shortDescription,
                sequence: self.sequence
            ))
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        // Required when the user switches to a different paired Watch.
        WCSession.default.activate()
    }
}
