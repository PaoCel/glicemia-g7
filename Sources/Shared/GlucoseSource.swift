import Foundation

/// Everything that can produce readings for the iPhone looks like this. The Watch never
/// sees a source: it only ever receives what the iPhone decided was the current value.
protocol GlucoseSource: AnyObject {
    var onReading: ((GlucoseReading) -> Void)? { get set }
    var onError: ((GlucoseSourceError) -> Void)? { get set }

    /// Human-readable name for the status screen.
    var displayName: String { get }

    func start()
    func stop()
    /// User asked for a value now. Sources may ignore it if one is already in flight.
    func refreshNow()

    /// A single fetch that reports when it is done. Used by background refresh, where
    /// the system gives a few seconds and expects to be told the work has finished.
    /// Returns true if a reading was produced.
    func fetchOnce() async -> Bool
}

/// Errors are deliberately coarse: the UI only needs to know whether the user has to do
/// something, and whether the last reading is still worth showing (it always is).
enum GlucoseSourceError: Error, Equatable {
    /// Username or password rejected. Needs the user.
    case credentialsRejected
    /// Credentials accepted but the account publishes nothing: Share is off, or there is
    /// no follower, or the sensor is in warm-up.
    case noDataPublished
    /// Transient: no network, timeout, server hiccup. Worth retrying on our own.
    case unreachable(String)
    /// Anything else the server said.
    case server(String)

    /// Short Italian text for the iPhone status list.
    var shortDescription: String {
        switch self {
        case .credentialsRejected: return "credenziali rifiutate"
        case .noDataPublished: return "nessun dato pubblicato"
        case .unreachable: return "server non raggiungibile"
        case .server(let message): return message
        }
    }

    /// True when only the user can fix it, so the UI should insist rather than retry.
    var needsUser: Bool {
        switch self {
        case .credentialsRejected, .noDataPublished: return true
        case .unreachable, .server: return false
        }
    }
}
