import SwiftUI
import CoreData

struct LeadListView: View {
    @Environment(\.managedObjectContext) private var context
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \CDLead.createdAt, ascending: false)],
        animation: .default
    ) private var leads: FetchedResults<CDLead>

    @State private var searchText = ""
    @State private var showingForm = false
    @State private var selectedLead: CDLead?
    @State private var showingConvert = false
    @State private var leadToConvert: CDLead?

    var filteredLeads: [CDLead] {
        if searchText.isEmpty { return Array(leads) }
        return leads.filter {
            ($0.firstName ?? "").localizedCaseInsensitiveContains(searchText) ||
            ($0.lastName ?? "").localizedCaseInsensitiveContains(searchText) ||
            ($0.companyName ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Leads")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Spacer()
                TextField("Buscar...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 200)
                Button("Nuevo lead") {
                    selectedLead = nil
                    showingForm = true
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
            .padding()

            Table(filteredLeads) {
                TableColumn("Nombre") { lead in
                    Text("\(lead.firstName ?? "") \(lead.lastName ?? "")")
                        .fontWeight(.medium)
                }
                TableColumn("Empresa") { lead in
                    Text(lead.companyName ?? "-")
                }
                TableColumn("Email") { lead in
                    Text(lead.email ?? "-")
                }
                TableColumn("Fuente") { lead in
                    Text(lead.source ?? "-")
                }
                TableColumn("Puntuacion") { lead in
                    Text("\(lead.score)")
                        .fontWeight(.medium)
                }
                TableColumn("Estado") { lead in
                    StatusBadge(text: lead.status ?? "new", color: leadColor(lead.status ?? "new"))
                }
                TableColumn("Acciones") { lead in
                    HStack(spacing: 6) {
                        CallActionsMenu(
                            primaryPhone: lead.phone,
                            secondaryPhone: nil,
                            email: lead.email
                        ) { action in
                            let fullName = "\(lead.firstName ?? "") \(lead.lastName ?? "")".trimmingCharacters(in: .whitespaces)
                            let leadName = fullName.isEmpty ? "Lead sin nombre" : fullName
                            let companyNote = (lead.companyName ?? "").isEmpty ? "" : "\nEmpresa: \(lead.companyName ?? "")"
                            CallIntegrationHelper.perform(
                                action: action,
                                primaryPhone: lead.phone,
                                secondaryPhone: nil,
                                email: lead.email,
                                context: context,
                                subject: leadName,
                                notes: "Lead comercial\(companyNote)"
                            )
                        }

                        Button("Editar") {
                            selectedLead = lead
                            showingForm = true
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        if !lead.isConverted {
                            Button("Convertir") {
                                leadToConvert = lead
                                showingConvert = true
                            }
                            .buttonStyle(.bordered)
                            .tint(.blue)
                            .controlSize(.small)
                        }
                        Button("Eliminar") {
                            context.delete(lead)
                            PersistenceController.shared.save()
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                        .controlSize(.small)
                    }
                }
            }
        }
        .sheet(isPresented: $showingForm) {
            LeadFormView(lead: selectedLead)
        }
        .alert("Convertir lead a contacto", isPresented: $showingConvert) {
            Button("Convertir") { convertLead() }
            Button("Cancelar", role: .cancel) {}
        } message: {
            if let lead = leadToConvert {
                Text("Se creara un contacto con los datos de \(lead.firstName ?? "") \(lead.lastName ?? "")")
            }
        }
    }

    private func convertLead() {
        guard let lead = leadToConvert else { return }
        let contact = CDContact(context: context)
        contact.id = UUID()
        contact.firstName = lead.firstName
        contact.lastName = lead.lastName
        contact.email = lead.email
        contact.phone = lead.phone
        contact.jobTitle = lead.jobTitle
        contact.status = "active"
        contact.createdAt = Date()
        contact.updatedAt = Date()
        lead.isConverted = true
        lead.status = "converted"
        lead.updatedAt = Date()
        PersistenceController.shared.save()
    }

    private func leadColor(_ status: String) -> Color {
        switch status {
        case "new": return .blue
        case "contacted": return .orange
        case "qualified": return .green
        case "converted": return .purple
        case "lost": return .red
        default: return .gray
        }
    }
}

struct LeadFormView: View {
    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss

    let lead: CDLead?

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var companyName = ""
    @State private var jobTitle = ""
    @State private var source = "web"
    @State private var status = "new"
    @State private var score: Int32 = 0
    @State private var notes = ""

    let sourceOptions = ["web", "referido", "linkedin", "evento", "llamada", "otro"]
    let statusOptions = ["new", "contacted", "qualified", "lost"]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(lead != nil ? "Editar lead" : "Nuevo lead")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Button("Cancelar") { dismiss() }
                    .buttonStyle(.bordered)
                Button("Guardar") { save() }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .disabled(firstName.isEmpty || lastName.isEmpty)
            }
            .padding()

            Form {
                Section("Datos del lead") {
                    TextField("Nombre", text: $firstName)
                    TextField("Apellido", text: $lastName)
                    TextField("Email", text: $email)
                    TextField("Telefono", text: $phone)
                    TextField("Empresa", text: $companyName)
                    TextField("Cargo", text: $jobTitle)
                }
                Section("Clasificacion") {
                    Picker("Fuente", selection: $source) {
                        ForEach(sourceOptions, id: \.self) { Text($0) }
                    }
                    Picker("Estado", selection: $status) {
                        ForEach(statusOptions, id: \.self) { Text($0) }
                    }
                    Stepper("Puntuacion: \(score)", value: $score, in: 0...100)
                }
                Section("Notas") {
                    TextEditor(text: $notes)
                        .frame(height: 80)
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 500, height: 550)
        .onAppear {
            guard let l = lead else { return }
            firstName = l.firstName ?? ""
            lastName = l.lastName ?? ""
            email = l.email ?? ""
            phone = l.phone ?? ""
            companyName = l.companyName ?? ""
            jobTitle = l.jobTitle ?? ""
            source = l.source ?? "web"
            status = l.status ?? "new"
            score = l.score
            notes = l.notes ?? ""
        }
    }

    private func save() {
        let isNewLead = lead == nil
        let l = lead ?? CDLead(context: context)
        if lead == nil {
            l.id = UUID()
            l.createdAt = Date()
        }
        l.firstName = firstName
        l.lastName = lastName
        l.email = email
        l.phone = phone
        l.companyName = companyName
        l.jobTitle = jobTitle
        l.source = source
        l.status = status
        l.score = score
        l.notes = notes
        l.updatedAt = Date()
        PersistenceController.shared.save()
        if isNewLead {
            WorkflowAutomationEngine.executeActiveWorkflows(
                triggerType: "nuevo_lead",
                context: context,
                lead: l
            )
        }
        dismiss()
    }
}
