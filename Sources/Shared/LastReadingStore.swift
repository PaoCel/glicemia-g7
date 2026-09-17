import Foundation

/// Survives app termination on both sides. The Watch shows this when the iPhone is
/// unreachable, rather than falling back to an empty screen.
final class LastReadingStore {
    static let shared = LastReadingStore()

    private let defaults = UserDefaults.standard
    private enum K {
        static let mgdl = "last.mgdl"
        static let trend = "last.trend"
        static let date = "last.date"
        static let source = "last.source"
        static let sequence = "last.sequence"
    }

    private init() {}

    var sequence: Int {
        get { defaults.integer(forKey: K.sequence) }
        set { defaults.set(newValue, forKey: K.sequence) }
    }

    func save(_ reading: GlucoseReading) {
        defaults.set(reading.mgdl, forKey: K.mgdl)
        defaults.set(reading.trend.rawValue, forKey: K.trend)
        defaults.set(reading.date.timeIntervalSince1970, forKey: K.date)
        defaults.set(reading.source.rawValue, forKey: K.source)
    }

    /// Forgets the cached reading. Used when the source changes: a value produced by
    /// the simulator must not survive into a session backed by the real sensor.
    func clear() {
        defaults.removeObject(forKey: K.mgdl)
        defaults.removeObject(forKey: K.trend)
        defaults.removeObject(forKey: K.date)
        defaults.removeObject(forKey: K.source)
    }

    func load() -> GlucoseReading? {
        let timestamp = defaults.double(forKey: K.date)
        guard timestamp > 0, let trendRaw = defaults.string(forKey: K.trend) else { return nil }
        return GlucoseReading(
            mgdl: defaults.integer(forKey: K.mgdl),
            trend: TrendDirection(rawValue: trendRaw) ?? .unknown,
            date: Date(timeIntervalSince1970: timestamp),
            source: ReadingOrigin(rawValue: defaults.string(forKey: K.source) ?? "") ?? .cache
        )
    }
}
