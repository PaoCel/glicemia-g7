import Foundation

/// Trend direction as reported by Dexcom Share (and mirrored by the mock source).
enum TrendDirection: String, Codable, CaseIterable {
    case doubleUp
    case singleUp
    case fortyFiveUp
    case flat
    case fortyFiveDown
    case singleDown
    case doubleDown
    case notComputable
    case rateOutOfRange
    case unknown

    /// Dexcom Share encodes trend as an Int 0...9 (0 = none).
    init(shareValue: Int) {
        switch shareValue {
        case 1: self = .doubleUp
        case 2: self = .singleUp
        case 3: self = .fortyFiveUp
        case 4: self = .flat
        case 5: self = .fortyFiveDown
        case 6: self = .singleDown
        case 7: self = .doubleDown
        case 8: self = .notComputable
        case 9: self = .rateOutOfRange
        default: self = .unknown
        }
    }

    /// Single SF Symbol used for the glyph. Double arrows are drawn as two of these.
    var symbolName: String {
        switch self {
        case .doubleUp, .singleUp: return "arrow.up"
        case .fortyFiveUp: return "arrow.up.right"
        case .flat: return "arrow.right"
        case .fortyFiveDown: return "arrow.down.right"
        case .doubleDown, .singleDown: return "arrow.down"
        case .notComputable, .rateOutOfRange, .unknown: return "questionmark"
        }
    }

    /// True when the trend must be rendered as a stacked pair of arrows.
    var isDouble: Bool {
        self == .doubleUp || self == .doubleDown
    }

    var isKnown: Bool {
        switch self {
        case .notComputable, .rateOutOfRange, .unknown: return false
        default: return true
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .doubleUp: return "in forte salita"
        case .singleUp: return "in salita"
        case .fortyFiveUp: return "in lieve salita"
        case .flat: return "stabile"
        case .fortyFiveDown: return "in lieve discesa"
        case .singleDown: return "in discesa"
        case .doubleDown: return "in forte discesa"
        case .notComputable, .rateOutOfRange, .unknown: return "trend non disponibile"
        }
    }
}

/// Where a reading came from. Kept out of the main Watch screen by design.
/// Distinct from the `GlucoseSource` protocol: this is provenance, that is machinery.
enum ReadingOrigin: String, Codable {
    case mock
    case dexcomShare
    case bleDirect
    case cache

    var displayName: String {
        switch self {
        case .mock: return "Simulatore"
        case .dexcomShare: return "Dexcom Share"
        case .bleDirect: return "Sensore diretto"
        case .cache: return "Ultimo valore salvato"
        }
    }
}

struct GlucoseReading: Equatable {
    let mgdl: Int
    let trend: TrendDirection
    let date: Date
    let source: ReadingOrigin

    static func == (lhs: GlucoseReading, rhs: GlucoseReading) -> Bool {
        lhs.mgdl == rhs.mgdl && lhs.trend == rhs.trend
            && abs(lhs.date.timeIntervalSince(rhs.date)) < 1 && lhs.source == rhs.source
    }
}

// MARK: - Clinical ranges

enum GlucoseRange {
    case low
    case inRange
    case high

    /// Thresholds are intentionally conservative; tuned later with the real tester.
    static func of(_ mgdl: Int) -> GlucoseRange {
        if mgdl < 70 { return .low }
        if mgdl > 180 { return .high }
        return .inRange
    }
}

// MARK: - Freshness

/// How old a reading is allowed to be before the UI must stop implying it is current.
/// Dexcom G7 publishes every 5 minutes, so anything under 6 minutes is a normal cadence.
enum Freshness {
    case fresh
    case delayed
    case stale

    static let delayedAfter: TimeInterval = 6 * 60
    static let staleAfter: TimeInterval = 12 * 60

    static func of(age: TimeInterval) -> Freshness {
        if age >= staleAfter { return .stale }
        if age >= delayedAfter { return .delayed }
        return .fresh
    }
}

/// Transport / source health, orthogonal to freshness.
enum LinkState: Equatable {
    case ok
    case updating
    case phoneUnreachable
    case sourceError(String)
}
