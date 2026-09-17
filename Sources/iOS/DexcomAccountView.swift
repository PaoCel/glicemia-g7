import SwiftUI

/// Two different screens behind one entry point, because they answer two different
/// questions. Before connecting: "what do I type in". After connecting: "is it working,
/// and how do I get out". The second is deliberately not an editable form — nothing
/// here should look like a preference to fiddle with.
struct DexcomAccountView: View {
    @EnvironmentObject private var model: PhoneModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            if model.isDexcomConfigured {
                ConnectedAccountView()
            } else {
                ConnectAccountForm()
            }
        }
        .background(GlucoseTheme.background.ignoresSafeArea())
        .navigationTitle("Account Dexcom")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Connecting

private struct ConnectAccountForm: View {
    @EnvironmentObject private var model: PhoneModel
    @Environment(\.dismiss) private var dismiss

    @State private var username = ""
    @State private var password = ""
    @State private var region: DexcomRegion = .outsideUS
    @State private var isVerifying = false
    @State private var failure: String?

    @FocusState private var focus: Field?
    private enum Field { case username, password }

    private var canSubmit: Bool {
        !username.trimmingCharacters(in: .whitespaces).isEmpty
            && !password.isEmpty
            && !isVerifying
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("Inserisci le credenziali dell'account Dexcom di chi indossa il sensore. Non quelle di chi lo segue.")
                    .font(.subheadline)
                    .foregroundColor(GlucoseTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)

                VStack(spacing: 10) {
                    FieldBox(label: "Nome utente o email") {
                        TextField("", text: $username)
                            .textContentType(.username)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.emailAddress)
                            .focused($focus, equals: .username)
                            .submitLabel(.next)
                            .onSubmit { focus = .password }
                    }
                    FieldBox(label: "Password") {
                        SecureField("", text: $password)
                            .textContentType(.password)
                            .focused($focus, equals: .password)
                            .submitLabel(.go)
                            .onSubmit { if canSubmit { Task { await verifyAndSave() } } }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("REGIONE")
                        .font(.caption.weight(.semibold))
                        .tracking(0.8)
                        .foregroundColor(GlucoseTheme.secondaryText)

                    Picker("Regione", selection: $region) {
                        ForEach(DexcomRegion.allCases) { region in
                            Text(region.displayName).tag(region)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text("In Italia è Europa. Sbagliare regione dà lo stesso errore di una password sbagliata.")
                        .font(.caption)
                        .foregroundColor(GlucoseTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let failure = failure {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(GlucoseTheme.warning)
                        Text(failure)
                            .font(.footnote)
                            .foregroundColor(GlucoseTheme.primaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(GlucoseTheme.warning.opacity(0.14))
                    )
                }

                Button {
                    Task { await verifyAndSave() }
                } label: {
                    HStack(spacing: 10) {
                        if isVerifying { ProgressView().tint(.black) }
                        Text(isVerifying ? "Verifica in corso" : "Verifica e collega")
                            .font(.headline)
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(canSubmit ? GlucoseTheme.primaryText : Color(white: 0.35))
                    )
                }
                .disabled(!canSubmit)

                Text("La password viene verificata prima di essere salvata, e resta nel portachiavi del telefono.")
                    .font(.caption)
                    .foregroundColor(GlucoseTheme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, 30)
            }
            .padding(.horizontal, 22)
        }
        .onAppear { focus = .username }
    }

    private func verifyAndSave() async {
        isVerifying = true
        failure = nil
        defer { isVerifying = false }

        let credentials = DexcomCredentials(
            username: username.trimmingCharacters(in: .whitespaces),
            password: password,
            region: region
        )

        switch await model.verifyCredentials(credentials) {
        case .success:
            do {
                try model.saveCredentials(credentials)
                password = ""
                dismiss()
            } catch {
                failure = "Non è stato possibile salvare la password nel portachiavi."
            }
        case .failure(let error):
            failure = Self.message(for: error)
        }
    }

    static func message(for error: GlucoseSourceError) -> String {
        switch error {
        case .credentialsRejected:
            return "Credenziali rifiutate. Controlla nome utente, password e regione. Dopo alcuni tentativi sbagliati Dexcom blocca l'account per un po'."
        case .noDataPublished:
            return "L'account è corretto ma non pubblica dati. Nell'app Dexcom attiva Condivisione e assicurati che ci sia almeno una persona che ti segue."
        case .unreachable(let detail):
            return "Server Dexcom non raggiungibile: \(detail)"
        case .server(let message):
            return message
        }
    }
}

private struct FieldBox<Content: View>: View {
    let label: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.caption)
                .foregroundColor(GlucoseTheme.secondaryText)
            content
                .font(.body)
                .foregroundColor(GlucoseTheme.primaryText)
                .textFieldStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(white: 0.13))
        )
    }
}

// MARK: - Connected

private struct ConnectedAccountView: View {
    @EnvironmentObject private var model: PhoneModel
    @Environment(\.dismiss) private var dismiss
    @State private var showDisconnect = false

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 42))
                    .foregroundColor(Color(red: 0.42, green: 0.85, blue: 0.52))

                Text("Account collegato")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(GlucoseTheme.primaryText)

                if let username = model.dexcomUsername {
                    Text(username)
                        .font(.subheadline)
                        .foregroundColor(GlucoseTheme.secondaryText)
                }
            }
            .padding(.top, 44)

            if let error = model.sourceError, error.needsUser {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(GlucoseTheme.warning)
                    Text(ConnectAccountForm.message(for: error))
                        .font(.footnote)
                        .foregroundColor(GlucoseTheme.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(GlucoseTheme.warning.opacity(0.14))
                )
                .padding(.top, 28)
            }

            Spacer(minLength: 30)

            Button(role: .destructive) {
                showDisconnect = true
            } label: {
                Text("Scollega account")
                    .font(.subheadline.weight(.medium))
            }
            .padding(.bottom, 34)
        }
        .padding(.horizontal, 22)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .confirmationDialog(
            "Scollegare l'account Dexcom?",
            isPresented: $showDisconnect,
            titleVisibility: .visible
        ) {
            Button("Scollega", role: .destructive) {
                model.clearCredentials()
                dismiss()
            }
            Button("Annulla", role: .cancel) {}
        } message: {
            Text("L'app smetterà di mostrare la glicemia, sul telefono e sull'orologio, finché non ricolleghi un account.")
        }
    }
}
