import SwiftUI

@MainActor
final class CommunicationViewModel: ObservableObject {
    static let defaultCorporateEmail = "alfonsomarcos@talentosostenibleconsulting.es"
    static let defaultSignature = "Marcos Daniel Alfonso\nwww.talentosostenibleconsulting.es\n637754638"

    @Published var accounts: [MailAccountOption] = []
    @Published var selectedAccount: MailAccountOption?
    @Published var messages: [MailMessageSummary] = []
    @Published var selectedMessage: MailMessageSummary?
    @Published var messageBody = ""
    @Published var composeTo = ""
    @Published var composeSubject = ""
    @Published var composeBody = ""
    @Published var loading = false
    @Published var errorMessage = ""

    var unreadCount: Int {
        messages.filter { !$0.isRead }.count
    }

    func account(matching address: String) -> MailAccountOption? {
        guard !address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return accounts.first {
            $0.address.localizedCaseInsensitiveCompare(address) == .orderedSame
        }
    }

    func loadAccounts(preferredAccountID: String? = nil, preferredAddress: String? = nil) {
        loading = true
        errorMessage = ""
        Task {
            do {
                let loadedAccounts = try await Task.detached {
                    try MailAppClient.fetchAccounts()
                }.value
                accounts = loadedAccounts
                if let preferredAccountID,
                   let preferred = loadedAccounts.first(where: { $0.id == preferredAccountID }) {
                    selectedAccount = preferred
                } else if let preferredAddress,
                          let preferred = loadedAccounts.first(where: { $0.address.localizedCaseInsensitiveCompare(preferredAddress) == .orderedSame }) {
                    selectedAccount = preferred
                } else if selectedAccount == nil {
                    selectedAccount = loadedAccounts.first
                }
                if let selectedAccount {
                    await loadMessages(for: selectedAccount)
                }
                loading = false
            } catch {
                loading = false
                errorMessage = error.localizedDescription
            }
        }
    }

    func loadMessages(for account: MailAccountOption) async {
        loading = true
        errorMessage = ""
        do {
            let loadedMessages = try await Task.detached {
                try MailAppClient.fetchMessages(accountName: account.name)
            }.value
            messages = loadedMessages
            if let first = loadedMessages.first {
                selectedMessage = first
                await loadBody(for: first, in: account)
            } else {
                selectedMessage = nil
                messageBody = "Sin correos en la bandeja de entrada."
            }
            loading = false
        } catch {
            loading = false
            errorMessage = error.localizedDescription
        }
    }

    func loadBody(for message: MailMessageSummary, in account: MailAccountOption) async {
        loading = true
        errorMessage = ""
        do {
            let body = try await Task.detached {
                try MailAppClient.fetchMessageBody(accountName: account.name, messageID: message.messageID)
            }.value
            messageBody = body.isEmpty ? "Sin contenido visible." : body
            loading = false
        } catch {
            loading = false
            errorMessage = error.localizedDescription
        }
    }

    func openReply() {
        guard let account = selectedAccount, let message = selectedMessage else { return }
        do {
            try MailAppClient.reply(accountName: account.name, messageID: message.messageID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func composeNew() {
        guard let account = selectedAccount else { return }
        do {
            try MailAppClient.compose(accountName: account.name, to: composeTo, subject: composeSubject, body: composeBody)
            composeTo = ""
            composeSubject = ""
            composeBody = ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct CommunicationCenterView: View {
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var viewModel = CommunicationViewModel()
    @AppStorage("communication.corporateAccountID") private var corporateAccountID = ""
    @AppStorage("communication.corporateEmail") private var corporateEmail = CommunicationViewModel.defaultCorporateEmail
    @AppStorage("communication.signature") private var corporateSignature = CommunicationViewModel.defaultSignature
    @State private var searchText = ""
    @State private var unreadOnly = false
    @State private var showingSettings = false

    private var filteredMessages: [MailMessageSummary] {
        viewModel.messages.filter { message in
            let passesUnread = !unreadOnly || !message.isRead
            let passesSearch = searchText.isEmpty ||
                message.subject.localizedCaseInsensitiveContains(searchText) ||
                message.sender.localizedCaseInsensitiveContains(searchText)
            return passesUnread && passesSearch
        }
    }

    private var selectedAccountIsCorporate: Bool {
        viewModel.selectedAccount?.id == corporateAccountID
    }

    private var corporateAccountInMail: MailAccountOption? {
        viewModel.account(matching: corporateEmail)
    }

    private var corporateStatusTitle: String {
        if corporateEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Correo corporativo sin definir"
        }
        if selectedAccountIsCorporate || viewModel.selectedAccount?.address.localizedCaseInsensitiveCompare(corporateEmail) == .orderedSame {
            return "Cuenta corporativa operativa"
        }
        if corporateAccountInMail != nil {
            return "Cuenta detectada en Mail, pendiente de activarla en la app"
        }
        return "Cuenta corporativa no encontrada en Mail"
    }

    private var corporateStatusDetail: String {
        if corporateEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Define la direccion corporativa para que la app pueda usarla como cuenta principal."
        }
        if selectedAccountIsCorporate || viewModel.selectedAccount?.address.localizedCaseInsensitiveCompare(corporateEmail) == .orderedSame {
            return "La app ya usara esta cuenta por defecto para leer y redactar correos corporativos."
        }
        if corporateAccountInMail != nil {
            return "La cuenta ya esta en Mail del Mac. Solo falta marcarla como corporativa dentro de Comunicacion."
        }
        return "Configura primero la cuenta en Mail del Mac. En tu caso es el siguiente paso obligatorio para dejar el correo operativo."
    }

    private var corporateStatusColor: Color {
        if selectedAccountIsCorporate || viewModel.selectedAccount?.address.localizedCaseInsensitiveCompare(corporateEmail) == .orderedSame {
            return .green
        }
        if corporateAccountInMail != nil {
            return .orange
        }
        return .red
    }

    var body: some View {
        ZStack {
            communicationBackground

            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Comunicacion")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        Text("Bandeja conectada con Mail.app para revisar y responder desde tu cuenta corporativa.")
                            .foregroundColor(.white.opacity(0.8))
                    }
                    Spacer()
                    if !viewModel.accounts.isEmpty {
                        Picker("Cuenta", selection: $viewModel.selectedAccount) {
                            ForEach(viewModel.accounts, id: \.id) { account in
                                Text(account.displayName).tag(Optional(account))
                            }
                        }
                        .frame(width: 340)
                        .onChange(of: viewModel.selectedAccount) { newValue in
                            guard let newValue else { return }
                            Task { await viewModel.loadMessages(for: newValue) }
                        }
                        Button(selectedAccountIsCorporate ? "Cuenta corporativa" : "Marcar corporativa") {
                            corporateAccountID = viewModel.selectedAccount?.id ?? ""
                            if let address = viewModel.selectedAccount?.address, !address.isEmpty {
                                corporateEmail = address
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                    Button("Recargar") {
                        if let account = viewModel.selectedAccount {
                            Task { await viewModel.loadMessages(for: account) }
                        } else {
                            viewModel.loadAccounts(
                                preferredAccountID: corporateAccountID.isEmpty ? nil : corporateAccountID,
                                preferredAddress: corporateEmail.isEmpty ? CommunicationViewModel.defaultCorporateEmail : corporateEmail
                            )
                        }
                    }
                    .buttonStyle(.bordered)
                    Button("Configuracion") {
                        showingSettings = true
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal)
                .padding(.top)
                .padding(.bottom, 8)
                .padding(.vertical, 24)
                .padding(.horizontal, 28)
                .background(
                    LinearGradient(
                        colors: [Color(red: 0.17, green: 0.21, blue: 0.47), Color(red: 0.32, green: 0.28, blue: 0.72), Color(red: 0.09, green: 0.14, blue: 0.31)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 28, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                )
                .padding(.horizontal)

                HStack(spacing: 12) {
                    communicationStatCard(title: "Cuenta activa", value: viewModel.selectedAccount?.address.isEmpty == false ? viewModel.selectedAccount?.address ?? "-" : viewModel.selectedAccount?.name ?? "-", accent: .blue)
                    communicationStatCard(title: "Correos", value: "\(viewModel.messages.count)", accent: .green)
                    communicationStatCard(title: "No leidos", value: "\(viewModel.unreadCount)", accent: .orange)
                }
                .padding(.horizontal)

                HStack(alignment: .center, spacing: 12) {
                    Circle()
                        .fill(corporateStatusColor)
                        .frame(width: 10, height: 10)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(corporateStatusTitle)
                            .fontWeight(.semibold)
                        Text(corporateStatusDetail)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if let corporateAccountInMail,
                       !selectedAccountIsCorporate,
                       viewModel.selectedAccount?.id != corporateAccountInMail.id {
                        Button("Activar cuenta corporativa") {
                            corporateAccountID = corporateAccountInMail.id
                            viewModel.selectedAccount = corporateAccountInMail
                            Task { await viewModel.loadMessages(for: corporateAccountInMail) }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
                .background(communicationMessageBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(.horizontal)

                if !viewModel.errorMessage.isEmpty {
                    Text(viewModel.errorMessage)
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                }

                HSplitView {
                    VStack(spacing: 0) {
                        HStack {
                            TextField("Buscar por asunto o remitente", text: $searchText)
                                .textFieldStyle(.roundedBorder)
                            Toggle("No leidos", isOn: $unreadOnly)
                                .toggleStyle(.switch)
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 10)

                        if viewModel.loading && viewModel.messages.isEmpty {
                            ProgressView()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            List(filteredMessages, selection: $viewModel.selectedMessage) { message in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(message.subject)
                                            .fontWeight(message.isRead ? .regular : .semibold)
                                        Spacer()
                                        Text(message.receivedAt)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Text(message.sender)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                            .onChange(of: viewModel.selectedMessage) { newValue in
                                guard let newValue, let account = viewModel.selectedAccount else { return }
                                Task { await viewModel.loadBody(for: newValue, in: account) }
                            }
                        }
                    }
                    .frame(minWidth: 360)
                    .background(communicationPanelBackground)

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(viewModel.selectedMessage?.subject ?? "Correo")
                                .font(.title3)
                                .fontWeight(.semibold)
                            Spacer()
                            Button("Responder") {
                                viewModel.openReply()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(viewModel.selectedMessage == nil)
                        }

                        if selectedAccountIsCorporate {
                            Text("Cuenta corporativa activa")
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.12))
                                .foregroundColor(.blue)
                                .clipShape(Capsule())
                        }

                        if let selectedMessage = viewModel.selectedMessage {
                            Text(selectedMessage.sender)
                                .foregroundColor(.secondary)
                        }

                        ScrollView {
                            Text(viewModel.messageBody.isEmpty ? "Selecciona un correo para leerlo." : viewModel.messageBody)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(communicationMessageBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }

                        Divider()

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Nuevo correo")
                                .font(.headline)
                            TextField("Para", text: $viewModel.composeTo)
                            TextField("Asunto", text: $viewModel.composeSubject)
                            TextEditor(text: $viewModel.composeBody)
                                .frame(minHeight: 150)
                                .scrollContentBackground(.hidden)
                                .padding(8)
                                .background(communicationMessageBackground)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.2)))
                            Text("Firma corporativa activa: \(corporateSignature.replacingOccurrences(of: "\n", with: " · "))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            HStack {
                                Button("Restaurar firma") {
                                    viewModel.composeBody = corporateSignature
                                }
                                .buttonStyle(.bordered)
                                Spacer()
                                Button("Redactar en Mail") {
                                    if viewModel.composeBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                        viewModel.composeBody = corporateSignature
                                    }
                                    viewModel.composeNew()
                                    viewModel.composeBody = corporateSignature
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                    }
                    .padding()
                    .background(communicationPanelBackground)
                }
            }
        }
        .padding(.vertical)
        .sheet(isPresented: $showingSettings) {
            CommunicationSettingsView(
                corporateEmail: $corporateEmail,
                corporateSignature: $corporateSignature,
                selectedAccount: viewModel.selectedAccount,
                detectedAccount: corporateAccountInMail,
                activateDetectedAccount: {
                    guard let corporateAccountInMail else { return }
                    corporateAccountID = corporateAccountInMail.id
                    viewModel.selectedAccount = corporateAccountInMail
                    Task { await viewModel.loadMessages(for: corporateAccountInMail) }
                }
            )
        }
        .onAppear {
            if corporateEmail.isEmpty {
                corporateEmail = CommunicationViewModel.defaultCorporateEmail
            }
            if corporateSignature.isEmpty {
                corporateSignature = CommunicationViewModel.defaultSignature
            }
            if viewModel.composeBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                viewModel.composeBody = corporateSignature
            }
            viewModel.loadAccounts(
                preferredAccountID: corporateAccountID.isEmpty ? nil : corporateAccountID,
                preferredAddress: corporateEmail
            )
        }
    }

    private var communicationBackground: some View {
        LinearGradient(
            colors: colorScheme == .dark
                ? [Color(red: 0.08, green: 0.09, blue: 0.15), Color(red: 0.06, green: 0.07, blue: 0.11)]
                : [Color(red: 0.96, green: 0.97, blue: 1.0), Color(red: 0.92, green: 0.94, blue: 0.99)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var communicationPanelBackground: some ShapeStyle {
        colorScheme == .dark ? AnyShapeStyle(Color.white.opacity(0.05)) : AnyShapeStyle(.ultraThinMaterial)
    }

    private var communicationMessageBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.86)
    }

    private func communicationStatCard(title: String, value: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.headline)
                .lineLimit(2)
            Rectangle()
                .fill(accent)
                .frame(width: 42, height: 3)
                .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(communicationMessageBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct CommunicationSettingsView: View {
    @Binding var corporateEmail: String
    @Binding var corporateSignature: String
    let selectedAccount: MailAccountOption?
    let detectedAccount: MailAccountOption?
    let activateDetectedAccount: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Configuracion corporativa")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Button("Cerrar") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()

            Form {
                Section("Correo corporativo") {
                    TextField("Direccion corporativa", text: $corporateEmail)
                    if let detectedAccount {
                        HStack {
                            Text("Cuenta detectada en Mail")
                            Spacer()
                            Text(detectedAccount.displayName)
                                .foregroundColor(.secondary)
                        }
                        Button("Usar esta cuenta en la app") {
                            activateDetectedAccount()
                        }
                        .buttonStyle(.bordered)
                    } else {
                        Text("Cuando esta direccion exista en Mail del Mac, la app podra activarla automaticamente.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if let selectedAccount {
                        HStack {
                            Text("Cuenta activa actual")
                            Spacer()
                            Text(selectedAccount.displayName)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Section("Firma corporativa") {
                    TextEditor(text: $corporateSignature)
                        .frame(height: 140)
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 620, height: 520)
    }
}