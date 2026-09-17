import ClockKit

/// Complication for the watch face.
///
/// Deliberately built on the classic families — modular, utilitarian, circular,
/// extra large. The `graphic*` families require an Apple Watch Series 4 or newer, so
/// a Series 3 would simply show nothing if those were the only ones offered. The
/// graphic variants are provided as well, but they are the extra, not the baseline.
final class ComplicationController: NSObject, CLKComplicationDataSource {

    private var reading: GlucoseReading? { LastReadingStore.shared.load() }

    func getComplicationDescriptors(handler: @escaping ([CLKComplicationDescriptor]) -> Void) {
        handler([
            CLKComplicationDescriptor(
                identifier: "glicemia",
                displayName: "Glicemia",
                supportedFamilies: CLKComplicationFamily.allCases
            )
        ])
    }

    func getTimelineEndDate(for complication: CLKComplication, withHandler handler: @escaping (Date?) -> Void) {
        // Only ever the current value: a glucose reading cannot be predicted forward,
        // and a timeline of guesses on a watch face would be worse than nothing.
        handler(nil)
    }

    func getPrivacyBehavior(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationPrivacyBehavior) -> Void) {
        // Health data disappears when the watch leaves the wrist.
        handler(.hideOnLockScreen)
    }

    func getCurrentTimelineEntry(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTimelineEntry?) -> Void) {
        guard let template = template(for: complication.family, reading: reading) else {
            handler(nil)
            return
        }
        handler(CLKComplicationTimelineEntry(date: Date(), complicationTemplate: template))
    }

    func getLocalizableSampleTemplate(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTemplate?) -> Void) {
        let sample = GlucoseReading(mgdl: 112, trend: .flat, date: Date(), source: .mock)
        handler(template(for: complication.family, reading: sample))
    }

    // MARK: - Templates

    /// Value plus trend arrow. The age is left out on purpose: a complication that the
    /// system may not refresh for twenty minutes must not print a number of minutes
    /// that stopped being true ten minutes ago.
    private func template(for family: CLKComplicationFamily, reading: GlucoseReading?) -> CLKComplicationTemplate? {
        let value = reading.map { GlucoseFormatting.value($0.mgdl) } ?? GlucoseFormatting.placeholder
        let arrow = reading.map { Self.arrow(for: $0.trend) } ?? " "

        let valueProvider = CLKSimpleTextProvider(text: value)
        let arrowProvider = CLKSimpleTextProvider(text: arrow)
        let combinedProvider = CLKSimpleTextProvider(text: "\(value) \(arrow)")

        switch family {
        case .modularSmall:
            return CLKComplicationTemplateModularSmallStackText(
                line1TextProvider: valueProvider,
                line2TextProvider: arrowProvider
            )
        case .modularLarge:
            return CLKComplicationTemplateModularLargeStandardBody(
                headerTextProvider: CLKSimpleTextProvider(text: "Glicemia"),
                body1TextProvider: combinedProvider,
                body2TextProvider: CLKSimpleTextProvider(text: ageText(reading))
            )
        case .utilitarianSmall, .utilitarianSmallFlat:
            return CLKComplicationTemplateUtilitarianSmallFlat(textProvider: combinedProvider)
        case .utilitarianLarge:
            return CLKComplicationTemplateUtilitarianLargeFlat(textProvider: combinedProvider)
        case .circularSmall:
            return CLKComplicationTemplateCircularSmallStackText(
                line1TextProvider: valueProvider,
                line2TextProvider: arrowProvider
            )
        case .extraLarge:
            return CLKComplicationTemplateExtraLargeStackText(
                line1TextProvider: valueProvider,
                line2TextProvider: arrowProvider
            )
        case .graphicCircular:
            return CLKComplicationTemplateGraphicCircularStackText(
                line1TextProvider: valueProvider,
                line2TextProvider: arrowProvider
            )
        case .graphicCorner:
            return CLKComplicationTemplateGraphicCornerStackText(
                innerTextProvider: arrowProvider,
                outerTextProvider: valueProvider
            )
        case .graphicBezel, .graphicRectangular, .graphicExtraLarge:
            return CLKComplicationTemplateGraphicRectangularStandardBody(
                headerTextProvider: CLKSimpleTextProvider(text: "Glicemia"),
                body1TextProvider: combinedProvider,
                body2TextProvider: CLKSimpleTextProvider(text: ageText(reading))
            )
        @unknown default:
            return nil
        }
    }

    private func ageText(_ reading: GlucoseReading?) -> String {
        guard let reading = reading else { return "nessun dato" }
        return GlucoseFormatting.age(Date().timeIntervalSince(reading.date))
    }

    /// Text arrows rather than symbols: at complication sizes a glyph rendered by the
    /// font stays legible where an image turns to mush.
    static func arrow(for trend: TrendDirection) -> String {
        switch trend {
        case .doubleUp: return "⇈"
        case .singleUp: return "↑"
        case .fortyFiveUp: return "↗"
        case .flat: return "→"
        case .fortyFiveDown: return "↘"
        case .singleDown: return "↓"
        case .doubleDown: return "⇊"
        case .notComputable, .rateOutOfRange, .unknown: return "?"
        }
    }

    /// Asks the system to redraw every complication this app owns.
    static func reload() {
        let server = CLKComplicationServer.sharedInstance()
        server.activeComplications?.forEach { server.reloadTimeline(for: $0) }
    }
}
