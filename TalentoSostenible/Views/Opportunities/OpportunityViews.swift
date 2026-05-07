import SwiftUI
import CoreData

struct OpportunityListView: View {
    @Environment(\.managedObjectContext) private var context
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \CDOpportunity.createdAt, ascending: false)],
        animation: .default
    ) private var opportunities: FetchedResults<CDOpportunity>

    @State private var searchText = ""
    @State private var showingForm = false
    @State private var selectedOpp: CDOpportunity?

    var filteredOpps: [CDOpportunity] {
        if searchText.isEmpty { return Array(opportunities) }
        return opportunities.filter {
            ($0.name ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Oportunidades")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Spacer()
                TextField("Buscar...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 200)
                Button("Nueva oportunidad") {
                    selectedOpp = nil
                    showingForm = true
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
            .padding()

            Table(filteredOpps) {
                TableColumn("Nombre") { opp in
                    Text(opp.name ?? "")
                        .fontWeight(.medium)
                }
                TableColumn("Empresa") { opp in
                    Text(opp.company?.name ?? "-")
                }
                TableColumn("Valor") { opp in
                    Text(String(format: "%.0f EUR", opp.amount))
                }
                TableColumn("Probabilidad") { opp in
                    Text("\(opp.probability)%")
                }
                TableColumn("Etapa") { opp in
                    StatusBadge(text: stageLabel(opp.stage ?? ""), color: stageColor(opp.stage ?? ""))
                }
                TableColumn("Cierre") { opp in
                    if let date = opp.expectedCloseDate {
                        Text(date, style: .date)
                            .font(.caption)
                    } else {
                        Text("-")
                    }
                }
                TableColumn("Acciones") { opp in
                    HStack(spacing: 8) {
                        CallActionsMenu(
                            primaryPhone: opp.contact?.mobile,
                            secondaryPhone: opp.contact?.phone ?? opp.company?.phone,
                            email: opp.contact?.email ?? opp.company?.email
                        ) { action in
                            let notes = [
                                opp.company?.name.map { "Empresa: \($0)" },
                                opp.contact.map { "Contacto: \(($0.firstName ?? "") + " " + ($0.lastName ?? "")).trimmingCharacters(in: .whitespaces)" }
                            ]
                            .compactMap { $0 }
                            .joined(separator: "\n")

                            CallIntegrationHelper.perform(
                                action: action,
                                primaryPhone: opp.contact?.mobile,
                                secondaryPhone: opp.contact?.phone ?? opp.company?.phone,
                                email: opp.contact?.email ?? opp.company?.email,
                                context: context,
                                subject: opp.name ?? "Oportunidad sin nombre",
                                contact: opp.contact,
                                company: opp.company,
                                opportunity: opp,
                                notes: notes.isEmpty ? nil : notes
                            )
                        }

                        Button("Editar") {
                            selectedOpp = opp
                            showingForm = true
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        Button("Eliminar") {
                            context.delete(opp)
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
            OpportunityFormView(opportunity: selectedOpp)
        }
    }

    func stageLabel(_ stage: String) -> String {
        switch stage {
        case "prospecting": return "Prospeccion"
        case "qualification": return "Cualificacion"
        case "proposal": return "Propuesta"
        case "negotiation": return "Negociacion"
        case "closed_won": return "Ganada"
        case "closed_lost": return "Perdida"
        default: return stage
        }
    }

    func stageColor(_ stage: String) -> Color {
        switch stage {
        case "prospecting": return .gray
        case "qualification": return .blue
        case "proposal": return .orange
        case "negotiation": return .purple
        case "closed_won": return .green
        case "closed_lost": return .red
        default: return .gray
        }
    }
}

struct OpportunityFormView: View {
    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \CDCompany.name, ascending: true)]) private var companies: FetchedResults<CDCompany>
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \CDContact.lastName, ascending: true)]) private var contacts: FetchedResults<CDContact>

    let opportunity: CDOpportunity?

    @State private var name = ""
    @State private var amount: Double = 0
    @State private var probability: Int32 = 50
    @State private var stage = "prospecting"
    @State private var expectedCloseDate = Date()
    @State private var notes = ""
    @State private var selectedCompany: CDCompany?
    @State private var selectedContact: CDContact?

    let stageOptions = ["prospecting", "qualification", "proposal", "negotiation", "closed_won", "closed_lost"]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(opportunity != nil ? "Editar oportunidad" : "Nueva oportunidad")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Button("Cancelar") { dismiss() }
                    .buttonStyle(.bordered)
                Button("Guardar") { save() }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .disabled(name.isEmpty)
            }
            .padding()

            Form {
                Section("Datos") {
                    TextField("Nombre", text: $name)
                    TextField("Valor (EUR)", value: $amount, format: .number)
                    Stepper("Probabilidad: \(probability)%", value: $probability, in: 0...100, step: 5)
                    Picker("Etapa", selection: $stage) {
                        ForEach(stageOptions, id: \.self) { Text($0) }
                    }
                    DatePicker("Fecha cierre estimada", selection: $expectedCloseDate, displayedComponents: .date)
                }
                Section("Relaciones") {
                    Picker("Empresa", selection: $selectedCompany) {
                        Text("Sin empresa").tag(nil as CDCompany?)
                        ForEach(companies) { company in
                            Text(company.name ?? "").tag(company as CDCompany?)
                        }
                    }
                    Picker("Contacto", selection: $selectedContact) {
                        Text("Sin contacto").tag(nil as CDContact?)
                        ForEach(contacts) { contact in
                            Text("\(contact.firstName ?? "") \(contact.lastName ?? "")").tag(contact as CDContact?)
                        }
                    }
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
            guard let o = opportunity else { return }
            name = o.name ?? ""
            amount = o.amount
            probability = o.probability
            stage = o.stage ?? "prospecting"
            expectedCloseDate = o.expectedCloseDate ?? Date()
            notes = o.notes ?? ""
            selectedCompany = o.company
            selectedContact = o.contact
        }
    }

    private func save() {
        let previousStage = opportunity?.stage
        let o = opportunity ?? CDOpportunity(context: context)
        if opportunity == nil {
            o.id = UUID()
            o.createdAt = Date()
        }
        o.name = name
        o.amount = amount
        o.probability = probability
        o.stage = stage
        o.expectedCloseDate = expectedCloseDate
        o.notes = notes
        o.company = selectedCompany
        o.contact = selectedContact
        o.updatedAt = Date()
        PersistenceController.shared.save()
        if previousStage != nil, previousStage != stage {
            WorkflowAutomationEngine.executeActiveWorkflows(
                triggerType: "cambio_etapa",
                context: context,
                opportunity: o,
                details: ["etapa_anterior": previousStage ?? "", "etapa_nueva": stage]
            )
        }
        dismiss()
    }
}

struct PipelineView: View {
    @Environment(\.managedObjectContext) private var context
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \CDOpportunity.amount, ascending: false)],
        predicate: NSPredicate(format: "stage != %@ AND stage != %@", "closed_won", "closed_lost")
    ) private var opportunities: FetchedResults<CDOpportunity>

    let stages = ["prospecting", "qualification", "proposal", "negotiation"]
    let stageLabels = ["Prospeccion", "Cualificacion", "Propuesta", "Negociacion"]
    let stageColors: [Color] = [.gray, .blue, .orange, .purple]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Pipeline")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding()

            HStack(alignment: .top, spacing: 12) {
                ForEach(0..<stages.count, id: \.self) { index in
                    let stage = stages[index]
                    let stageOpps = opportunities.filter { $0.stage == stage }
                    let total = stageOpps.reduce(0.0) { $0 + $1.amount }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(stageLabels[index])
                                .font(.headline)
                            Spacer()
                            Text("\(stageOpps.count)")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(stageColors[index].opacity(0.15))
                                .cornerRadius(8)
                        }
                        Text(String(format: "%.0f EUR", total))
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Divider()

                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(stageOpps) { opp in
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(opp.name ?? "")
                                            .fontWeight(.medium)
                                            .font(.callout)
                                        Text(opp.company?.name ?? "")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text(String(format: "%.0f EUR - %d%%", opp.amount, opp.probability))
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(10)
                                    .background(Color(nsColor: .controlBackgroundColor))
                                    .cornerRadius(8)
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(stageColors[index].opacity(0.3)))
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(nsColor: .windowBackgroundColor))
                    .cornerRadius(10)
                }
            }
            .padding(.horizontal)
        }
    }
}
