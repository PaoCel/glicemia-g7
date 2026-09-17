import SwiftUI

/// Colour is never the only carrier of meaning here: every state that colour marks is
/// also marked by a glyph, a label or a weight change. The Series 3 screen is small and
/// often viewed in bad light.
enum GlucoseTheme {
    static let background = Color.black
    static let primaryText = Color.white
    static let secondaryText = Color(white: 0.62)

    static let inRange = Color.white
    static let low = Color(red: 1.00, green: 0.45, blue: 0.38)
    static let high = Color(red: 1.00, green: 0.78, blue: 0.24)

    static let warning = Color(red: 1.00, green: 0.78, blue: 0.24)

    static func valueColor(_ mgdl: Int, freshness: Freshness) -> Color {
        // Once a reading is stale its colour stops encoding urgency, because acting on a
        // 20 minute old "low" is worse than acting on no value at all.
        guard freshness != .stale else { return secondaryText }
        switch GlucoseRange.of(mgdl) {
        case .low: return low
        case .high: return high
        case .inRange: return inRange
        }
    }

    /// Non-colour marker for out-of-range values.
    static func rangeGlyph(_ mgdl: Int) -> String? {
        switch GlucoseRange.of(mgdl) {
        case .low: return "arrow.down.to.line"
        case .high: return "arrow.up.to.line"
        case .inRange: return nil
        }
    }
}
