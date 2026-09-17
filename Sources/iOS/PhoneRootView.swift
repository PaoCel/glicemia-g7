import SwiftUI

struct PhoneRootView: View {
    @EnvironmentObject private var model: PhoneModel

    var body: some View {
        if model.isDexcomConfigured {
            ConnectedRootView()
        } else {
            WelcomeView()
        }
    }
}

/// The screen once there is an account. Everything on it answers a question the person
/// wearing the sensor would actually ask: what is my glucose, is the watch getting it,
/// is anything broken. Counters, session ids and transport details are not here.
private struct ConnectedRootView: View {
    @EnvironmentObject private var model: PhoneModel
    @State private var showAccount = false

    private var age: TimeInterval? {
        model.reading.map { model.now.timeIntervalSince($0.date) }
    }

    private var freshness: Freshness {
        Freshness.of(age: age ?? .greatestFiniteMagnitude)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 26) {
                    PhoneHeroView(reading: model.reading, age: age, freshness: freshness, link: model.link)
                        .padding(.top, 16)

                    if let error = model.sourceError {
                        problemCard(error)
                    }

                    watchCard
                    accountRow
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 34)
            }
            .background(GlucoseTheme.background.ignoresSafeArea())
            .navigationTitle("Glicemia")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        model.refreshNow()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .accessibilityLabel("Aggiorna adesso")
                }
            }
            .sheet(isPresented: $showAccount) {
                NavigationStack { DexcomAccountView() }
                    .preferredColorScheme(.dark)
            }
        }
    }

    // MARK: - Pieces

    private func problemCard(_ error: GlucoseSourceError) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(GlucoseTheme.warning)
            VStack(alignment: .leading, spacing: 4) {
                Text(headline(for: error))
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(GlucoseTheme.primaryText)
                Text(detail(for: error))
                    .font(.footnote)
                    .foregroundColor(GlucoseTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(GlucoseTheme.warning.opacity(0.14))
        )
    }

    private var watchCard: some View {
        HStack(spacing: 12) {
            Image(systemName: watchGlyph)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(watchTint)
                .frame(width: 20)
            Text("Apple Watch")
                .font(.subheadline)
                .foregroundColor(GlucoseTheme.primaryText)
            Spacer(minLength: 12)
            Text(watchText)
                .font(.subheadline)
                .foregroundColor(GlucoseTheme.secondaryText)
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(white: 0.11))
        )
        .accessibilityElement(children: .combine)
    }

    private var accountRow: some View {
        Button {
            showAccount = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "person.crop.circle")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(GlucoseTheme.secondaryText)
                    .frame(width: 20)
                Text("Account Dexcom")
                    .font(.subheadline)
                    .foregroundColor(GlucoseTheme.primaryText)
                Spacer(minLength: 12)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(GlucoseTheme.secondaryText)
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(white: 0.11))
            )
        }
    }

    // MARK: - Wording

    private var watchText: String {
        if !model.watchPaired { return "nessuno abbinato" }
        if !model.watchAppInstalled { return "app non installata" }
        return "riceve i dati"
    }

    private var watchGlyph: String {
        model.watchPaired && model.watchAppInstalled ? "applewatch" : "applewatch.slash"
    }

    private var watchTint: Color {
        model.watchPaired && model.watchAppInstalled
            ? Color(red: 0.42, green: 0.85, blue: 0.52)
            : GlucoseTheme.warning
    }

    private func headline(for error: GlucoseSourceError) -> String {
        switch error {
        case .credentialsRejected: return "Account da ricollegare"
        case .noDataPublished: return "Dexcom non sta pubblicando"
        case .unreachable: return "Nessuna connessione"
        case .server: return "Problema del servizio Dexcom"
        }
    }

    private func detail(for error: GlucoseSourceError) -> String {
        switch error {
        case .credentialsRejected:
            return "Le credenziali non sono più valide. Aprile in Account Dexcom e ricollegale."
        case .noDataPublished:
            return "Nell'app Dexcom attiva Condivisione, con almeno una persona che ti segue. Durante il riscaldamento del sensore è normale."
        case .unreachable:
            return "Il valore mostrato è l'ultimo ricevuto. Riprovo da solo."
        case .server(let message):
            return message
        }
    }
}
