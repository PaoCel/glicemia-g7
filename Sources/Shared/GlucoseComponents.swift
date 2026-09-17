import SwiftUI

/// Trend arrow. Double arrows are drawn as two stacked glyphs so the difference between
/// "salita" and "forte salita" survives the Series 3 screen size.
struct TrendGlyph: View {
    let trend: TrendDirection
    var size: CGFloat
    var weight: Font.Weight = .semibold

    var body: some View {
        Group {
            if trend.isDouble {
                VStack(spacing: -size * 0.34) {
                    icon
                    icon
                }
            } else {
                icon
            }
        }
        .accessibilityLabel(trend.accessibilityLabel)
    }

    private var icon: some View {
        Image(systemName: trend.symbolName)
            .font(.system(size: size, weight: weight))
    }
}

/// The "how recent is this" line. State is carried by text and glyph, never by colour
/// alone, and the label grows in weight as the reading gets older.
struct AgeLabel: View {
    let age: TimeInterval?
    let freshness: Freshness
    let link: LinkState
    var compact: Bool

    var body: some View {
        HStack(spacing: compact ? 4 : 6) {
            if let glyph = glyph {
                Image(systemName: glyph)
                    .font(.system(size: compact ? 11 : 13, weight: .semibold))
            }
            Text(text)
                .font(.system(size: compact ? 14 : 15, weight: fontWeight))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .foregroundColor(tint)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private var text: String {
        switch link {
        case .phoneUnreachable:
            guard let age = age else { return "iPhone non connesso" }
            return compact ? "\(GlucoseFormatting.age(age)) · no iPhone" : "\(GlucoseFormatting.age(age)) · iPhone non connesso"
        case .sourceError:
            guard let age = age else { return "errore sorgente" }
            return "\(GlucoseFormatting.age(age)) · errore"
        case .updating:
            guard let age = age else { return "in aggiornamento" }
            return "\(GlucoseFormatting.age(age))"
        case .ok:
            guard let age = age else { return "nessun dato" }
            return GlucoseFormatting.age(age)
        }
    }

    private var glyph: String? {
        switch link {
        case .phoneUnreachable: return "iphone.slash"
        case .sourceError: return "exclamationmark.triangle.fill"
        case .updating: return "arrow.triangle.2.circlepath"
        case .ok:
            switch freshness {
            case .fresh: return nil
            case .delayed: return "clock"
            case .stale: return "exclamationmark.triangle.fill"
            }
        }
    }

    private var fontWeight: Font.Weight {
        switch freshness {
        case .fresh: return .regular
        case .delayed: return .semibold
        case .stale: return .bold
        }
    }

    private var tint: Color {
        if case .ok = link, freshness == .fresh { return GlucoseTheme.secondaryText }
        switch freshness {
        case .fresh: return GlucoseTheme.secondaryText
        case .delayed: return GlucoseTheme.primaryText
        case .stale: return GlucoseTheme.warning
        }
    }

    private var accessibilityText: String {
        guard let age = age else { return "nessun dato disponibile" }
        let base = "aggiornato \(GlucoseFormatting.age(age))"
        switch freshness {
        case .fresh: return base
        case .delayed: return base + ", in ritardo"
        case .stale: return base + ", non aggiornato"
        }
    }
}

/// Explicit "this is not a current reading" marker. Deliberately textual: on a stale
/// screen the value stays visible, but it must be impossible to read it as live.
struct StaleBadge: View {
    var compact: Bool

    var body: some View {
        Text("NON ATTUALE")
            .font(.system(size: compact ? 9 : 11, weight: .heavy))
            .tracking(compact ? 0.5 : 1)
            .foregroundColor(GlucoseTheme.warning)
            .padding(.horizontal, compact ? 5 : 8)
            .padding(.vertical, compact ? 2 : 3)
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(GlucoseTheme.warning, lineWidth: 1)
            )
    }
}

/// Out-of-range marker. The word does the work; the glyph and the colour only
/// reinforce it, so the meaning survives a small screen in bad light.
struct RangeBadge: View {
    let mgdl: Int
    let freshness: Freshness
    var compact: Bool

    var body: some View {
        if let glyph = GlucoseTheme.rangeGlyph(mgdl), freshness != .stale {
            HStack(spacing: compact ? 3 : 5) {
                Image(systemName: glyph)
                    .font(.system(size: compact ? 10 : 12, weight: .bold))
                Text(GlucoseRange.of(mgdl) == .low ? "BASSO" : "ALTO")
                    .font(.system(size: compact ? 11 : 13, weight: .heavy))
                    .tracking(compact ? 0.4 : 0.8)
            }
            .foregroundColor(GlucoseTheme.valueColor(mgdl, freshness: freshness))
        }
    }
}
