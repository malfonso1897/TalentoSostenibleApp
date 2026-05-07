import SwiftUI
import CoreData

struct CampaignListView: View {
    @Environment(\.managedObjectContext) private var context
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \CDCampaign.createdAt, ascending: false)],
        animation: .default
    ) private var campaigns: FetchedResults<CDCampaign>

    @State private var showingForm = false
    @State private var selectedCampaign: CDCampaign?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Campa\u{00f1}as")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Spacer()
                Button("Nueva campa\u{00f1}a") {
                    selectedCampaign = nil
                    showingForm = true
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
            .padding()

            Table(campaigns) {
                TableColumn("Nombre") { c in
                    Text(c.name ?? "").fontWeight(.medium)
                }
                TableColumn("Tipo") { c in
                    Text(c.campaignType ?? "-")
                }
                TableColumn("Estado") { c in
                    StatusBadge(text: c.status ?? "draft", color: campaignColor(c.status ?? "draft"))
                }
                TableColumn("Presupuesto") { c in
                    Text(String(format: "%.0f EUR", c.budget))
                }
                TableColumn("Inicio") { c in
                    if let d = c.startDate { Text(d, style: .date) } else { Text("-") }
                }
                TableColumn("Fin") { c in
                    if let d = c.endDate { Text(d, style: .date) } else { Text("-") }
                }
                TableColumn("Acciones") { c in
                    HStack(spacing: 8) {
                        Button("Editar") {
                            selectedCampaign = c
                            showingForm = true
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        Button("Eliminar") {
                            context.delete(c)
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
            CampaignFormView(campaign: selectedCampaign)
        }
    }

    func campaignColor(_ s: String) -> Color {
        switch s {
        case "draft": return .gray
        case "active": return .green
        case "paused": return .orange
        case "completed": return .blue
        default: return .gray
        }
    }
}

struct CampaignFormView: View {
    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss

    let campaign: CDCampaign?

    @State private var name = ""
    @State private var campaignType = "email"
    @State private var status = "draft"
    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var budget: Double = 0
    @State private var notes = ""

    let typeOptions = ["email", "social", "evento", "telefono", "otra"]
    let statusOptions = ["draft", "active", "paused", "completed"]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(campaign != nil ? "Editar campa\u{00f1}a" : "Nueva campa\u{00f1}a")
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
                    Picker("Tipo", selection: $campaignType) {
                        ForEach(typeOptions, id: \.self) { Text($0) }
                    }
                    Picker("Estado", selection: $status) {
                        ForEach(statusOptions, id: \.self) { Text($0) }
                    }
                    TextField("Presupuesto (EUR)", value: $budget, format: .number)
                }
                Section("Fechas") {
                    DatePicker("Inicio", selection: $startDate, displayedComponents: .date)
                    DatePicker("Fin", selection: $endDate, displayedComponents: .date)
                }
                Section("Notas") {
                    TextEditor(text: $notes)
                        .frame(height: 80)
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 500, height: 500)
        .onAppear {
            guard let c = campaign else { return }
            name = c.name ?? ""
            campaignType = c.campaignType ?? "email"
            status = c.status ?? "draft"
            startDate = c.startDate ?? Date()
            endDate = c.endDate ?? Date()
            budget = c.budget
            notes = c.notes ?? ""
        }
    }

    private func save() {
        let c = campaign ?? CDCampaign(context: context)
        if campaign == nil {
            c.id = UUID()
            c.createdAt = Date()
        }
        c.name = name
        c.campaignType = campaignType
        c.status = status
        c.startDate = startDate
        c.endDate = endDate
        c.budget = budget
        c.notes = notes
        c.updatedAt = Date()
        PersistenceController.shared.save()
        dismiss()
    }
}
