import Foundation

enum GlucoseFormatting {
    /// Compact relative age, sized for the Series 3 screen: "adesso", "2 min fa", "1 h 05 fa".
    static func age(_ interval: TimeInterval) -> String {
        let seconds = max(0, Int(interval.rounded()))
        if seconds < 45 { return "adesso" }

        let minutes = Int((Double(seconds) / 60).rounded())
        if minutes < 60 { return "\(minutes) min fa" }

        let hours = minutes / 60
        let rest = minutes % 60
        if hours < 24 {
            return rest == 0 ? "\(hours) h fa" : String(format: "%d h %02d fa", hours, rest)
        }
        let days = hours / 24
        return days == 1 ? "ieri" : "\(days) g fa"
    }

    /// Absolute clock time, used on iPhone where there is room for it.
    static func clock(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "it_IT")
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    static func value(_ mgdl: Int) -> String { "\(mgdl)" }

    static let placeholder = "--"
}
