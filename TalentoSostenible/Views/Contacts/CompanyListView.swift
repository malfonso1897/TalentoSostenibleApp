import SwiftUI
import CoreData

struct CompanyListView: View {
    @Environment(\.managedObjectContext) private var context
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \CDCompany.name, ascending: true)],
        animation: .default
    ) private var companies: FetchedResults<CDCompany>

    @State private var searchText = ""
    @State private var showingForm = false
    @State private var selectedCompany: CDCompany?

    var filteredCompanies: [CDCompany] {
        if searchText.isEmpty { return Array(companies) }
        return companies.filter {
            ($0.name ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Empresas")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Spacer()
                TextField("Buscar...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 200)
                Button("Nueva empresa") {
                    selectedCompany = nil
                    showingForm = true
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
            .padding()

            Table(filteredCompanies) {
                TableColumn("Nombre") { company in
                    Text(company.name ?? "")
                        .fontWeight(.medium)
                }
                TableColumn("Industria") { company in
                    Text(company.industry ?? "-")
                }
                TableColumn("Telefono") { company in
                    Text(company.phone ?? "-")
                }
                TableColumn("Ciudad") { company in
                    Text(company.city ?? "-")
                }
                TableColumn("Contactos") { company in
                    Text("\((company.contacts as? Set<CDContact>)?.count ?? 0)")
                }
                TableColumn("Acciones") { company in
                    HStack(spacing: 8) {
                        CallActionsMenu(
                            primaryPhone: company.phone,
                            secondaryPhone: nil,
                            email: company.email
                        ) { action in
                            CallIntegrationHelper.perform(
                                action: action,
                                primaryPhone: company.phone,
                                secondaryPhone: nil,
                                email: company.email,
                                context: context,
                                subject: company.name ?? "Empresa sin nombre",
                                company: company,
                                notes: company.email
                            )
                        }

                        Button("Editar") {
                            selectedCompany = company
                            showingForm = true
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        Button("Eliminar") {
                            context.delete(company)
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
            CompanyFormView(company: selectedCompany)
        }
    }
}

struct CompanyFormView: View {
    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss

    let company: CDCompany?

    @State private var name = ""
    @State private var taxId = ""
    @State private var industry = ""
    @State private var website = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var postalCode = ""
    @State private var city = ""
    @State private var province = ""
    @State private var country = ""
    @State private var address = ""
    @State private var notes = ""
    @State private var employeeCount: Int32 = 0
    @State private var annualRevenue: Double = 0

    var isEditing: Bool { company != nil }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(isEditing ? "Editar empresa" : "Nueva empresa")
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
                Section("Datos de la empresa") {
                    TextField("Nombre", text: $name)
                    TextField("NIF / CIF", text: $taxId)
                    TextField("Industria", text: $industry)
                    TextField("Sitio web", text: $website)
                    TextField("Telefono", text: $phone)
                    TextField("Email", text: $email)
                }
                Section("Ubicacion") {
                    TextField("Direccion", text: $address)
                    TextField("Codigo postal", text: $postalCode)
                    TextField("Ciudad", text: $city)
                    TextField("Provincia", text: $province)
                    TextField("Pais", text: $country)
                }
                Section("Datos adicionales") {
                    TextField("Empleados", value: $employeeCount, format: .number)
                    TextField("Facturacion anual", value: $annualRevenue, format: .currency(code: "EUR"))
                }
                Section("Notas") {
                    TextEditor(text: $notes)
                        .frame(height: 80)
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 500, height: 550)
        .onAppear { loadData() }
    }

    private func loadData() {
        guard let c = company else { return }
        name = c.name ?? ""
        taxId = c.taxId ?? ""
        industry = c.industry ?? ""
        website = c.website ?? ""
        phone = c.phone ?? ""
        email = c.email ?? ""
        postalCode = c.postalCode ?? ""
        city = c.city ?? ""
        province = c.province ?? ""
        country = c.country ?? ""
        address = c.address ?? ""
        notes = c.notes ?? ""
        employeeCount = c.employeeCount
        annualRevenue = c.annualRevenue
    }

    private func save() {
        let c = company ?? CDCompany(context: context)
        if company == nil {
            c.id = UUID()
            c.createdAt = Date()
        }
        c.name = name
        c.taxId = taxId
        c.industry = industry
        c.website = website
        c.phone = phone
        c.email = email
        c.postalCode = postalCode
        c.city = city
        c.province = province
        c.country = country
        c.address = address
        c.notes = notes
        c.employeeCount = employeeCount
        c.annualRevenue = annualRevenue
        c.updatedAt = Date()
        PersistenceController.shared.save()
        dismiss()
    }
}
