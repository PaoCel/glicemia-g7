import SwiftUI
import WatchKit

struct WatchRootView: View {
    @EnvironmentObject private var model: WatchModel

    var body: some View {
        TabView {
            GlucoseScreen()
            DetailScreen()
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
    }
}

/// The one-second read. Value dominates, trend is immediately recognisable, age is
/// legible but clearly secondary. Nothing technical lives on this screen.
struct GlucoseScreen: View {
    @EnvironmentObject private var model: WatchModel

    /// 38 mm Series 3 is 136 pt wide; the value has to fit three digits there without
    /// scaling down, so the base size is derived from the actual screen.
    private var valueSize: CGFloat {
        let width = WKInterfaceDevice.current().screenBounds.width
        return width <= 140 ? 50 : 58
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            Text(model.reading.map { GlucoseFormatting.value($0.mgdl) } ?? GlucoseFormatting.placeholder)
                .font(.system(size: valueSize, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .accessibilityLabel(valueAccessibility)

            if let reading = model.reading, reading.trend.isKnown {
                TrendGlyph(trend: reading.trend, size: 22, weight: .bold)
                    .foregroundColor(valueColor)
                    .padding(.top, reading.trend.isDouble ? 2 : 0)
            }

            if let reading = model.reading {
                RangeBadge(mgdl: reading.mgdl, freshness: model.freshness, compact: true)
                    .padding(.top, 4)
            }

            if model.freshness == .stale, model.reading != nil {
                StaleBadge(compact: true)
                    .padding(.top, 5)
            }

            AgeLabel(age: model.age, freshness: model.freshness, link: model.link, compact: true)
                .padding(.top, 5)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(GlucoseTheme.background)
        .onTapGesture {
            model.fetchIfNeeded(force: true)
            model.requestSnapshot()
        }
        .onAppear {
            model.fetchIfNeeded()
            model.requestSnapshot()
        }
    }

    private var valueColor: Color {
        guard let reading = model.reading else { return GlucoseTheme.secondaryText }
        return GlucoseTheme.valueColor(reading.mgdl, freshness: model.freshness)
    }

    private var valueAccessibility: String {
        guard let reading = model.reading else { return "nessun valore disponibile" }
        return "\(reading.mgdl) milligrammi per decilitro"
    }
}

/// Page two. Not a debug screen: it answers "when was this measured" and "is it
/// updating by itself", and offers the one action worth having.
struct DetailScreen: View {
    @EnvironmentObject private var model: WatchModel

    var body: some View {
        List {
            if let reading = model.reading {
                row("Rilevazione", GlucoseFormatting.clock(reading.date))
            }

            row("Aggiornamento", model.isStandalone ? "dal Watch" : "tramite iPhone")
            row("iPhone", model.reachable ? "connesso" : "non raggiungibile")

            if let error = model.lastError {
                row("Problema", error)
            }

            Button("Aggiorna") {
                model.fetchIfNeeded(force: true)
                model.requestSnapshot()
            }
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(GlucoseTheme.secondaryText)
            Text(value)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(GlucoseTheme.primaryText)
        }
        .padding(.vertical, 2)
    }
}
