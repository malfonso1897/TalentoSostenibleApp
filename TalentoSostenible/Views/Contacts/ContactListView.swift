import SwiftUI
import CoreData
import AppKit

struct ContactListView: View {
    @Environment(\.managedObjectContext) private var context
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \CDContact.lastName, ascending: true)],
        animation: .default
    ) private var contacts: FetchedResults<CDContact>

    @State private var searchText = ""
    @State private var showingForm = false
    @State private var selectedContact: CDContact?

    var filteredContacts: [CDContact] {
        if searchText.isEmpty { return Array(contacts) }
        return contacts.filter {
            ($0.firstName ?? "").localizedCaseInsensitiveContains(searchText) ||
            ($0.lastName ?? "").localizedCaseInsensitiveContains(searchText) ||
            ($0.email ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Contactos")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Spacer()
                TextField("Buscar...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 200)
                Button("Nuevo contacto") {
                    selectedContact = nil
                    showingForm = true
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
            .padding()

            // Table
            Table(filteredContacts) {
                TableColumn("Nombre") { contact in
                    Text("\(contact.firstName ?? "") \(contact.lastName ?? "")")
                        .fontWeight(.medium)
                }
                TableColumn("Email") { contact in
                    Text(contact.email ?? "-")
                }
                TableColumn("Telefono") { contact in
                    Text(contact.phone ?? "-")
                }
                TableColumn("Empresa") { contact in
                    Text(contact.company?.name ?? "-")
                }
                TableColumn("Estado") { contact in
                    StatusBadge(text: contact.status ?? "active", color: contactStatusColor(contact.status ?? "active"))
                }
                TableColumn("Acciones") { contact in
                    HStack(spacing: 8) {
                        CallActionsMenu(
                            primaryPhone: contact.mobile,
                            secondaryPhone: contact.phone,
                            email: contact.email
                        ) { action in
                            CallIntegrationHelper.perform(
                                action: action,
                                primaryPhone: contact.mobile,
                                secondaryPhone: contact.phone,
                                email: contact.email,
                                context: context,
                                subject: "\(contact.firstName ?? "") \(contact.lastName ?? "")".trimmingCharacters(in: .whitespaces),
                                contact: contact,
                                company: contact.company,
                                notes: contact.email
                            )
                        }

                        Button("Editar") {
                            selectedContact = contact
                            showingForm = true
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        Button("Eliminar") {
                            deleteContact(contact)
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                        .controlSize(.small)
                    }
                }
            }
        }
        .sheet(isPresented: $showingForm) {
            ContactFormView(contact: selectedContact)
        }
    }

    private func deleteContact(_ contact: CDContact) {
        context.delete(contact)
        PersistenceController.shared.save()
    }

    private func contactStatusColor(_ status: String) -> Color {
        switch status {
        case "active": return .green
        case "inactive": return .gray
        case "customer": return .blue
        case "prospect": return .orange
        default: return .gray
        }
    }
}

struct ContactFormView: View {
    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss

    let contact: CDContact?

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var taxId = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var mobile = ""
    @State private var jobTitle = ""
    @State private var address = ""
    @State private var postalCode = ""
    @State private var city = ""
    @State private var province = ""
    @State private var country = ""
    @State private var status = "active"
    @State private var notes = ""

    let statusOptions = ["active", "inactive", "customer", "prospect"]

    var isEditing: Bool { contact != nil }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(isEditing ? "Editar contacto" : "Nuevo contacto")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Button("Cancelar") { dismiss() }
                    .buttonStyle(.bordered)
                Button("Guardar") { save() }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
            }
            .padding()

            Form {
                Section("Datos personales") {
                    TextField("Nombre", text: $firstName)
                    TextField("Apellido", text: $lastName)
                    TextField("NIF", text: $taxId)
                    TextField("Email", text: $email)
                    TextField("Telefono", text: $phone)
                    TextField("Movil", text: $mobile)
                    TextField("Cargo", text: $jobTitle)
                }
                Section("Ubicacion") {
                    TextField("Direccion", text: $address)
                    TextField("Codigo postal", text: $postalCode)
                    TextField("Ciudad", text: $city)
                    TextField("Provincia", text: $province)
                    TextField("Pais", text: $country)
                }
                Section("Estado") {
                    Picker("Estado", selection: $status) {
                        ForEach(statusOptions, id: \.self) { Text($0) }
                    }
                }
                Section("Notas") {
                    TextEditor(text: $notes)
                        .frame(height: 80)
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 500, height: 600)
        .onAppear { loadData() }
    }

    private func loadData() {
        guard let c = contact else { return }
        firstName = c.firstName ?? ""
        lastName = c.lastName ?? ""
        taxId = c.taxId ?? ""
        email = c.email ?? ""
        phone = c.phone ?? ""
        mobile = c.mobile ?? ""
        jobTitle = c.jobTitle ?? ""
        address = c.address ?? ""
        postalCode = c.postalCode ?? ""
        city = c.city ?? ""
        province = c.province ?? ""
        country = c.country ?? ""
        status = c.status ?? "active"
        notes = c.notes ?? ""
    }

    private func save() {
        let c = contact ?? CDContact(context: context)
        if contact == nil {
            c.id = UUID()
            c.createdAt = Date()
        }
        c.firstName = firstName
        c.lastName = lastName
        c.taxId = taxId
        c.email = email
        c.phone = phone
        c.mobile = mobile
        c.jobTitle = jobTitle
        c.address = address
        c.postalCode = postalCode
        c.city = city
        c.province = province
        c.country = country
        c.status = status
        c.notes = notes
        c.updatedAt = Date()
        PersistenceController.shared.save()
        dismiss()
    }
}

enum CallLaunchAction: String, CaseIterable, Identifiable {
    case phone
    case facetimeAudio
    case facetimeVideo

    var id: String { rawValue }

    var title: String {
        switch self {
        case .phone: return "Llamada"
        case .facetimeAudio: return "Audio FaceTime"
        case .facetimeVideo: return "Video FaceTime"
        }
    }

    var icon: String {
        switch self {
        case .phone: return "phone.fill"
        case .facetimeAudio: return "phone.badge.waveform.fill"
        case .facetimeVideo: return "video.fill"
        }
    }
}

struct CallActionsMenu: View {
    let primaryPhone: String?
    let secondaryPhone: String?
    let email: String?
    let onSelect: (CallLaunchAction) -> Void

    private var actions: [CallLaunchAction] {
        CallIntegrationHelper.availableActions(primaryPhone: primaryPhone, secondaryPhone: secondaryPhone, email: email)
    }

    var body: some View {
        Menu("Comunicar") {
            ForEach(actions) { action in
                Button(action.title) {
                    onSelect(action)
                }
            }
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .disabled(actions.isEmpty)
    }
}

enum CallIntegrationHelper {
    static func availableActions(primaryPhone: String?, secondaryPhone: String?, email: String?) -> [CallLaunchAction] {
        var actions: [CallLaunchAction] = []
        if preferredPhone(primaryPhone: primaryPhone, secondaryPhone: secondaryPhone) != nil {
            actions.append(.phone)
            actions.append(.facetimeAudio)
        } else if cleanEmail(email) != nil {
            actions.append(.facetimeAudio)
        }

        if preferredPhone(primaryPhone: primaryPhone, secondaryPhone: secondaryPhone) != nil || cleanEmail(email) != nil {
            actions.append(.facetimeVideo)
        }

        return actions
    }

    static func perform(
        action: CallLaunchAction,
        primaryPhone: String?,
        secondaryPhone: String?,
        email: String?,
        context: NSManagedObjectContext?,
        subject: String,
        contact: CDContact? = nil,
        company: CDCompany? = nil,
        opportunity: CDOpportunity? = nil,
        notes: String? = nil
    ) {
        switch action {
        case .phone:
            guard let phone = preferredPhone(primaryPhone: primaryPhone, secondaryPhone: secondaryPhone) else { return }
            openURL("tel://\(phone)")
        case .facetimeAudio:
            if let phone = preferredPhone(primaryPhone: primaryPhone, secondaryPhone: secondaryPhone) {
                openURL("facetime-audio://\(phone)")
            } else if let mail = cleanEmail(email) {
                openURL("facetime-audio://\(mail)")
            } else {
                return
            }
        case .facetimeVideo:
            if let mail = cleanEmail(email) {
                openURL("facetime://\(mail)")
            } else if let phone = preferredPhone(primaryPhone: primaryPhone, secondaryPhone: secondaryPhone) {
                openURL("facetime://\(phone)")
            } else {
                return
            }
        }

        logActivity(
            context: context,
            action: action,
            subject: subject,
            contact: contact,
            company: company,
            opportunity: opportunity,
            notes: notes
        )
    }

    private static func preferredPhone(primaryPhone: String?, secondaryPhone: String?) -> String? {
        cleanPhone(primaryPhone) ?? cleanPhone(secondaryPhone)
    }

    private static func cleanPhone(_ value: String?) -> String? {
        guard let value else { return nil }
        let cleaned = value.filter { $0.isNumber || $0 == "+" }
        return cleaned.isEmpty ? nil : cleaned
    }

    private static func cleanEmail(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    private static func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }

    private static func logActivity(
        context: NSManagedObjectContext?,
        action: CallLaunchAction,
        subject: String,
        contact: CDContact?,
        company: CDCompany?,
        opportunity: CDOpportunity?,
        notes: String?
    ) {
        guard let context else { return }

        let activity = CDActivity(context: context)
        activity.id = UUID()
        activity.subject = activitySubject(for: action, subject: subject)
        activity.activityType = action == .facetimeVideo ? "meeting" : "call"
        activity.notes = activityNotes(for: action, notes: notes)
        activity.contact = contact
        activity.company = company
        activity.opportunity = opportunity
        activity.isCompleted = true
        activity.workflowStatus = "done"
        activity.createdAt = Date()
        activity.updatedAt = Date()
        PersistenceController.shared.save()
    }

    private static func activitySubject(for action: CallLaunchAction, subject: String) -> String {
        let base = subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Sin destinatario" : subject
        switch action {
        case .phone: return "Llamada iniciada con \(base)"
        case .facetimeAudio: return "Audio FaceTime iniciado con \(base)"
        case .facetimeVideo: return "Video FaceTime iniciado con \(base)"
        }
    }

    private static func activityNotes(for action: CallLaunchAction, notes: String?) -> String {
        let channel: String
        switch action {
        case .phone: channel = "Canal: telefono"
        case .facetimeAudio: channel = "Canal: FaceTime Audio"
        case .facetimeVideo: channel = "Canal: FaceTime Video"
        }

        guard let notes, !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return channel
        }
        return "\(channel)\n\(notes)"
    }
}
