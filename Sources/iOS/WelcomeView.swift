import SwiftUI

/// First thing the app shows when there is no account. Connecting Dexcom is not a
/// setting buried somewhere: without it the app has nothing to display, so it is the
/// whole screen until it is done.
struct WelcomeView: View {
    @State private var showAccount = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                BrandMark(size: 132)
                    .padding(.top, 48)

                Text("Glicemia")
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .foregroundColor(GlucoseTheme.primaryText)
                    .padding(.top, 22)

                Text("La glicemia sul polso, in un secondo.")
                    .font(.subheadline)
                    .foregroundColor(GlucoseTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.top, 6)

                VStack(alignment: .leading, spacing: 18) {
                    requirement(
                        "1",
                        "Il tuo account Dexcom",
                        "Le stesse credenziali con cui entri nell'app Dexcom."
                    )
                    requirement(
                        "2",
                        "Condivisione attiva",
                        "Nell'app Dexcom, con almeno una persona che ti segue."
                    )
                }
                .padding(.top, 44)
                .padding(.horizontal, 4)

                Button {
                    showAccount = true
                } label: {
                    Text("Collega l'account Dexcom")
                        .font(.headline)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(GlucoseTheme.primaryText)
                        )
                }
                .padding(.top, 40)

                Text("Gli avvisi di glicemia alta o bassa restano all'app Dexcom. Questa app mostra il valore, non avvisa.")
                    .font(.footnote)
                    .foregroundColor(GlucoseTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.top, 28)
                    .padding(.bottom, 40)
            }
            .padding(.horizontal, 26)
        }
        .background(GlucoseTheme.background.ignoresSafeArea())
        .sheet(isPresented: $showAccount) {
            NavigationStack { DexcomAccountView() }
                .preferredColorScheme(.dark)
        }
    }

    private func requirement(_ number: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(number)
                .font(.footnote.weight(.bold))
                .foregroundColor(.black)
                .frame(width: 22, height: 22)
                .background(Circle().fill(GlucoseTheme.secondaryText))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(GlucoseTheme.primaryText)
                Text(detail)
                    .font(.footnote)
                    .foregroundColor(GlucoseTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
