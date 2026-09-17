import SwiftUI

/// iPhone version of the one-second read: value, trend, age. Same hierarchy as the
/// Watch so the two screens feel like one product.
struct PhoneHeroView: View {
    let reading: GlucoseReading?
    let age: TimeInterval?
    let freshness: Freshness
    let link: LinkState

    var body: some View {
        VStack(spacing: 6) {
            HStack(alignment: .center, spacing: 14) {
                Text(reading.map { GlucoseFormatting.value($0.mgdl) } ?? GlucoseFormatting.placeholder)
                    .font(.system(size: 86, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(valueColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)

                if let reading = reading {
                    TrendGlyph(trend: reading.trend, size: 30, weight: .semibold)
                        .foregroundColor(valueColor)
                }
            }

            Text("mg/dL")
                .font(.caption)
                .foregroundColor(GlucoseTheme.secondaryText)

            if let reading = reading {
                RangeBadge(mgdl: reading.mgdl, freshness: freshness, compact: false)
                    .padding(.top, 6)
            }

            if freshness == .stale, reading != nil {
                StaleBadge(compact: false)
                    .padding(.top, 10)
            }

            AgeLabel(age: age, freshness: freshness, link: link, compact: false)
                .padding(.top, 8)

            if let reading = reading {
                Text("rilevazione delle \(GlucoseFormatting.clock(reading.date))")
                    .font(.caption2)
                    .foregroundColor(GlucoseTheme.secondaryText)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var valueColor: Color {
        guard let reading = reading else { return GlucoseTheme.secondaryText }
        return GlucoseTheme.valueColor(reading.mgdl, freshness: freshness)
    }
}
