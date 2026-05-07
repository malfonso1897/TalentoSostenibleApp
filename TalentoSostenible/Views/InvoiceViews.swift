import SwiftUI
import CoreData
import AppKit

struct InvoiceIssuerProfile {
    var name: String
    var taxId: String
    var address: String
    var postalCode: String
    var city: String
    var province: String
    var country: String
    var email: String
    var phone: String
    var iban: String
    var bankHolder: String
    var bankName: String
    var paymentTerms: String

    var hasRequiredData: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !taxId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    static let empty = InvoiceIssuerProfile(
        name: "",
        taxId: "",
        address: "",
        postalCode: "",
        city: "",
        province: "",
        country: "Espana",
        email: "",
        phone: "",
        iban: "",
        bankHolder: "",
        bankName: "",
        paymentTerms: "Transferencia bancaria"
    )
}

struct InvoiceItemDraft: Identifiable {
    let id: UUID
    var concept: String
    var quantity: Double
    var unitPrice: Double
    var taxRate: Double

    init(id: UUID = UUID(), concept: String = "", quantity: Double = 1, unitPrice: Double = 0, taxRate: Double = 21) {
        self.id = id
        self.concept = concept
        self.quantity = quantity
        self.unitPrice = unitPrice
        self.taxRate = taxRate
    }

    var baseAmount: Double {
        quantity * unitPrice
    }

    var taxAmount: Double {
        baseAmount * taxRate / 100
    }

    var totalAmount: Double {
        baseAmount + taxAmount
    }
}

struct InvoicePreviewData {
    struct ClientData {
        var name: String
        var taxId: String
        var address: String
        var cityLine: String
        var email: String
        var phone: String
    }

    let number: String
    let issueDate: Date
    let dueDate: Date?
    let status: String
    let notes: String
    let withholdingRate: Double
    let issuer: InvoiceIssuerProfile
    let client: ClientData
    let items: [InvoiceItemDraft]

    var subtotal: Double {
        items.reduce(0) { $0 + $1.baseAmount }
    }

    var taxAmount: Double {
        items.reduce(0) { $0 + $1.taxAmount }
    }

    var withholdingAmount: Double {
        subtotal * withholdingRate / 100
    }

    var total: Double {
        subtotal + taxAmount - withholdingAmount
    }
}

private enum FinanceSection: String, CaseIterable, Identifiable {
    case resumen = "Resumen"
    case facturacion = "Facturacion"
    case gastos = "Gastos"

    var id: String { rawValue }
}

struct FinanceCenterView: View {
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \CDInvoice.issueDate, ascending: false)],
        animation: .default
    ) private var invoices: FetchedResults<CDInvoice>
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \CDExpense.expenseDate, ascending: false)],
        animation: .default
    ) private var expenses: FetchedResults<CDExpense>

    @State private var selectedSection: FinanceSection = .resumen

    private var issuedInvoices: [CDInvoice] {
        invoices.filter { ($0.status ?? "") != "cancelled" }
    }

    private var billedTotal: Double {
        issuedInvoices.reduce(0) { $0 + $1.total }
    }

    private var paidTotal: Double {
        invoices.filter { ($0.status ?? "") == "paid" }.reduce(0) { $0 + $1.total }
    }

    private var expenseTotal: Double {
        expenses.reduce(0) { $0 + $1.amount }
    }

    private var deductibleExpenseTotal: Double {
        expenses.filter(\.isDeductible).reduce(0) { $0 + $1.amount }
    }

    private var netEstimate: Double {
        billedTotal - expenseTotal
    }

    var body: some View {
        VStack(spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Finanzas")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text("Controla facturacion, gastos y el pulso economico del negocio desde un solo sitio.")
                        .foregroundColor(.secondary)
                }
                Spacer()
                Picker("Seccion", selection: $selectedSection) {
                    ForEach(FinanceSection.allCases) { section in
                        Text(section.rawValue).tag(section)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 360)
            }
            .padding(.horizontal)
            .padding(.top)

            HStack(spacing: 12) {
                financeMetricCard(title: "Facturado", value: currency(billedTotal), accent: .blue)
                financeMetricCard(title: "Cobrado", value: currency(paidTotal), accent: .green)
                financeMetricCard(title: "Gastos", value: currency(expenseTotal), accent: .orange)
                financeMetricCard(title: "Neto estimado", value: currency(netEstimate), accent: netEstimate >= 0 ? .mint : .red)
            }
            .padding(.horizontal)

            Group {
                switch selectedSection {
                case .resumen:
                    FinanceOverviewView(
                        invoiceCount: invoices.count,
                        expenseCount: expenses.count,
                        billedTotal: billedTotal,
                        paidTotal: paidTotal,
                        expenseTotal: expenseTotal,
                        deductibleExpenseTotal: deductibleExpenseTotal,
                        netEstimate: netEstimate
                    )
                case .facturacion:
                    InvoiceListView()
                case .gastos:
                    ExpenseListView()
                }
            }
        }
    }

    private func financeMetricCard(title: String, value: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.headline)
            Rectangle()
                .fill(accent)
                .frame(width: 40, height: 3)
                .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct FinanceOverviewView: View {
    let invoiceCount: Int
    let expenseCount: Int
    let billedTotal: Double
    let paidTotal: Double
    let expenseTotal: Double
    let deductibleExpenseTotal: Double
    let netEstimate: Double

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                GroupBox("Resumen financiero") {
                    Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 14) {
                        GridRow {
                            financeInfoCell(title: "Facturas emitidas", value: "\(invoiceCount)")
                            financeInfoCell(title: "Gastos registrados", value: "\(expenseCount)")
                        }
                        GridRow {
                            financeInfoCell(title: "Facturado total", value: currency(billedTotal))
                            financeInfoCell(title: "Cobrado total", value: currency(paidTotal))
                        }
                        GridRow {
                            financeInfoCell(title: "Gasto deducible", value: currency(deductibleExpenseTotal))
                            financeInfoCell(title: "Resultado estimado", value: currency(netEstimate))
                        }
                    }
                }

                GroupBox("Cobertura del negocio") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Finanzas agrupa la parte de facturacion y tambien el seguimiento de gastos operativos para tener una lectura mas real del negocio.")
                        Text("Desde aqui puedes emitir facturas, registrar pagos esperados, cargar gastos y revisar un margen estimado sin salir del CRM.")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox("Indicadores rapidos") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Margen estimado actual: \(currency(netEstimate))")
                            .fontWeight(.semibold)
                        Text("Gasto total registrado: \(currency(expenseTotal))")
                        Text("Pendiente de cobro aproximado: \(currency(max(billedTotal - paidTotal, 0)))")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding()
        }
    }

    private func financeInfoCell(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct ExpenseListView: View {
    @Environment(\.managedObjectContext) private var context
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \CDExpense.expenseDate, ascending: false)],
        animation: .default
    ) private var expenses: FetchedResults<CDExpense>

    @State private var searchText = ""
    @State private var showingForm = false
    @State private var selectedExpense: CDExpense?

    private var filteredExpenses: [CDExpense] {
        if searchText.isEmpty { return Array(expenses) }
        return expenses.filter {
            ($0.concept ?? "").localizedCaseInsensitiveContains(searchText) ||
            ($0.category ?? "").localizedCaseInsensitiveContains(searchText) ||
            ($0.supplier ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Gastos")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Spacer()
                TextField("Buscar gasto...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 220)
                Button("Nuevo gasto") {
                    selectedExpense = nil
                    showingForm = true
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            }
            .padding()

            if filteredExpenses.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "receipt")
                        .font(.system(size: 34))
                        .foregroundColor(.secondary)
                    Text("Sin gastos")
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text("Registra alquiler, herramientas, desplazamientos, marketing y cualquier coste del negocio.")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Table(filteredExpenses) {
                    TableColumn("Fecha") { expense in
                        Text(expense.expenseDate ?? Date(), style: .date)
                    }
                    TableColumn("Concepto") { expense in
                        Text(expense.concept ?? "")
                            .fontWeight(.medium)
                    }
                    TableColumn("Categoria") { expense in
                        Text(expense.category ?? "-")
                    }
                    TableColumn("Proveedor") { expense in
                        Text(expense.supplier ?? "-")
                    }
                    TableColumn("Pago") { expense in
                        Text(expensePaymentMethodLabel(expense.paymentMethod ?? "transfer"))
                    }
                    TableColumn("Importe") { expense in
                        Text(currency(expense.amount))
                            .fontWeight(.semibold)
                    }
                    TableColumn("Fiscal") { expense in
                        StatusBadge(text: expense.isDeductible ? "Deducible" : "No deducible", color: expense.isDeductible ? .green : .gray)
                    }
                    TableColumn("Acciones") { expense in
                        HStack(spacing: 6) {
                            Button("Editar") {
                                selectedExpense = expense
                                showingForm = true
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            Button("Eliminar") {
                                context.delete(expense)
                                PersistenceController.shared.save()
                            }
                            .buttonStyle(.bordered)
                            .tint(.red)
                            .controlSize(.small)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingForm) {
            ExpenseFormView(expense: selectedExpense)
        }
    }
}

struct ExpenseFormView: View {
    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss

    let expense: CDExpense?

    @State private var concept = ""
    @State private var category = "servicios"
    @State private var supplier = ""
    @State private var amount: Double = 0
    @State private var expenseDate = Date()
    @State private var paymentMethod = "transfer"
    @State private var isDeductible = true
    @State private var notes = ""

    let categories = ["alquiler", "servicios", "software", "marketing", "viajes", "material", "otros"]
    let paymentMethods = ["transfer", "card", "cash", "direct_debit"]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(expense != nil ? "Editar gasto" : "Nuevo gasto")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Button("Cancelar") { dismiss() }
                    .buttonStyle(.bordered)
                Button("Guardar") { save() }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .disabled(concept.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || amount <= 0)
            }
            .padding()

            Form {
                Section("Datos") {
                    TextField("Concepto", text: $concept)
                    Picker("Categoria", selection: $category) {
                        ForEach(categories, id: \.self) { Text($0.capitalized) }
                    }
                    TextField("Proveedor", text: $supplier)
                    TextField("Importe", value: $amount, format: .number)
                    DatePicker("Fecha", selection: $expenseDate, displayedComponents: .date)
                    Picker("Metodo de pago", selection: $paymentMethod) {
                        ForEach(paymentMethods, id: \.self) { Text(expensePaymentMethodLabel($0)).tag($0) }
                    }
                    Toggle("Gasto deducible", isOn: $isDeductible)
                }
                Section("Notas") {
                    TextEditor(text: $notes)
                        .frame(height: 120)
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 520, height: 560)
        .onAppear {
            guard let expense else { return }
            concept = expense.concept ?? ""
            category = expense.category ?? "servicios"
            supplier = expense.supplier ?? ""
            amount = expense.amount
            expenseDate = expense.expenseDate ?? Date()
            paymentMethod = expense.paymentMethod ?? "transfer"
            isDeductible = expense.isDeductible
            notes = expense.notes ?? ""
        }
    }

    private func save() {
        let target = expense ?? CDExpense(context: context)
        if expense == nil {
            target.id = UUID()
            target.createdAt = Date()
        }
        target.concept = concept
        target.category = category
        target.supplier = supplier.isEmpty ? nil : supplier
        target.amount = amount
        target.expenseDate = expenseDate
        target.paymentMethod = paymentMethod
        target.isDeductible = isDeductible
        target.notes = notes
        target.updatedAt = Date()
        PersistenceController.shared.save()
        dismiss()
    }
}

struct InvoiceListView: View {
    @Environment(\.managedObjectContext) private var context
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \CDInvoice.issueDate, ascending: false)],
        animation: .default
    ) private var invoices: FetchedResults<CDInvoice>

    @State private var searchText = ""
    @State private var showingForm = false
    @State private var showingPreview = false
    @State private var showingIssuerSettings = false
    @State private var selectedInvoice: CDInvoice?

    var filteredInvoices: [CDInvoice] {
        if searchText.isEmpty { return Array(invoices) }
        return invoices.filter {
            ($0.number ?? "").localizedCaseInsensitiveContains(searchText) ||
            invoiceClientName($0).localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Facturacion")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    if !issuerProfile().hasRequiredData {
                        Text("Configura emisor, NIF/CIF y direccion para emitir facturas validas en Espana.")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                Spacer()
                TextField("Buscar factura...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 220)
                Button("Datos emisor") {
                    showingIssuerSettings = true
                }
                .buttonStyle(.bordered)
                Button("Nueva factura") {
                    selectedInvoice = nil
                    showingForm = true
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
            .padding()

            if filteredInvoices.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 34))
                        .foregroundColor(.secondary)
                    Text("Sin facturas")
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text("Crea una factura con numeracion, cliente, lineas e IVA.")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Table(filteredInvoices) {
                    TableColumn("Numero") { invoice in
                        Text(invoice.number ?? "")
                            .fontWeight(.medium)
                    }
                    TableColumn("Fecha") { invoice in
                        if let date = invoice.issueDate {
                            Text(date, style: .date)
                        } else {
                            Text("-")
                        }
                    }
                    TableColumn("Cliente") { invoice in
                        Text(invoiceClientName(invoice))
                    }
                    TableColumn("Base") { invoice in
                        Text(currency(invoice.subtotal))
                    }
                    TableColumn("IVA") { invoice in
                        Text(currency(invoice.taxAmount))
                    }
                    TableColumn("Total") { invoice in
                        Text(currency(invoice.total))
                            .fontWeight(.semibold)
                    }
                    TableColumn("Estado") { invoice in
                        StatusBadge(text: invoiceStatusLabel(invoice.status ?? "draft"), color: invoiceStatusColor(invoice.status ?? "draft"))
                    }
                    TableColumn("Acciones") { invoice in
                        HStack(spacing: 6) {
                            Button("Ver") {
                                selectedInvoice = invoice
                                showingPreview = true
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            Button("Editar") {
                                selectedInvoice = invoice
                                showingForm = true
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            Button("Eliminar") {
                                context.delete(invoice)
                                PersistenceController.shared.save()
                            }
                            .buttonStyle(.bordered)
                            .tint(.red)
                            .controlSize(.small)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingForm) {
            InvoiceFormView(invoice: selectedInvoice)
        }
        .sheet(isPresented: $showingPreview) {
            if let invoice = selectedInvoice {
                InvoicePreviewView(previewData: .from(invoice: invoice))
            }
        }
        .sheet(isPresented: $showingIssuerSettings) {
            InvoiceIssuerSettingsView()
        }
    }

    private func invoiceClientName(_ invoice: CDInvoice) -> String {
        if let companyName = invoice.company?.name, !companyName.isEmpty {
            return companyName
        }
        let firstName = invoice.contact?.firstName ?? ""
        let lastName = invoice.contact?.lastName ?? ""
        let fullName = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
        return fullName.isEmpty ? "Sin cliente" : fullName
    }
}

struct InvoiceFormView: View {
    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \CDCompany.name, ascending: true)]) private var companies: FetchedResults<CDCompany>
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \CDContact.lastName, ascending: true)]) private var contacts: FetchedResults<CDContact>
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \CDInvoice.createdAt, ascending: true)]) private var existingInvoices: FetchedResults<CDInvoice>

    let invoice: CDInvoice?

    @State private var number = ""
    @State private var issueDate = Date()
    @State private var dueDate = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
    @State private var hasDueDate = true
    @State private var status = "draft"
    @State private var notes = ""
    @State private var selectedCompany: CDCompany?
    @State private var selectedContact: CDContact?
    @State private var items: [InvoiceItemDraft] = [InvoiceItemDraft()]
    @State private var showPreview = true
    @State private var exportError = ""
    @State private var showingExportError = false
    @AppStorage("invoice.withholdingRate") private var withholdingRate = 15.0

    let statusOptions = ["draft", "issued", "paid", "overdue", "cancelled"]

    var previewData: InvoicePreviewData {
        InvoicePreviewData(
            number: number,
            issueDate: issueDate,
            dueDate: hasDueDate ? dueDate : nil,
            status: status,
            notes: notes,
            withholdingRate: withholdingRate,
            issuer: issuerProfile(),
            client: clientData(),
            items: sanitizedItems()
        )
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                HStack {
                    Text(invoice == nil ? "Nueva factura" : "Editar factura")
                        .font(.title2)
                        .fontWeight(.bold)
                    Spacer()
                    Toggle("Vista previa", isOn: $showPreview)
                        .toggleStyle(.switch)
                    Button("Exportar PDF") {
                        do {
                            try exportCurrentPreview()
                        } catch {
                            exportError = error.localizedDescription
                            showingExportError = true
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(sanitizedItems().isEmpty)
                    Button("Cancelar") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    Button("Guardar") {
                        save()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .disabled(number.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || sanitizedItems().isEmpty)
                }
                .padding()

                invoiceWorkspace(for: geometry.size.width)
            }
        }
        .frame(minWidth: 940, idealWidth: 1220, maxWidth: .infinity, minHeight: 760, idealHeight: 760)
        .onAppear {
            loadData()
        }
        .alert("No se pudo exportar", isPresented: $showingExportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportError)
        }
    }

    @ViewBuilder
    private func invoiceWorkspace(for availableWidth: CGFloat) -> some View {
        let splitLayout = showPreview && availableWidth >= 1180

        if splitLayout {
            HSplitView {
                formPanel
                    .frame(minWidth: 560)

                previewPanel
                    .frame(minWidth: 520)
            }
        } else if showPreview {
            VStack(spacing: 0) {
                formPanel
                Divider()
                previewPanel
                    .frame(minHeight: 300, maxHeight: availableWidth < 1080 ? 340 : 420)
            }
        } else {
            formPanel
        }
    }

    private var formPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                GroupBox("Datos legales") {
                    Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 12) {
                        GridRow {
                            TextField("Numero", text: $number)
                            Picker("Estado", selection: $status) {
                                ForEach(statusOptions, id: \.self) { option in
                                    Text(invoiceStatusLabel(option)).tag(option)
                                }
                            }
                        }
                        GridRow {
                            DatePicker("Fecha emision", selection: $issueDate, displayedComponents: .date)
                            Toggle("Vencimiento", isOn: $hasDueDate)
                        }
                        if hasDueDate {
                            GridRow {
                                DatePicker("Fecha vencimiento", selection: $dueDate, displayedComponents: .date)
                                Color.clear
                            }
                        }
                    }
                }

                GroupBox("Cliente") {
                    VStack(alignment: .leading, spacing: 12) {
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
                }

                GroupBox("Lineas de factura") {
                    VStack(spacing: 10) {
                        ForEach($items) { $item in
                            HStack(alignment: .top, spacing: 8) {
                                TextField("Concepto o servicio", text: $item.concept)
                                    .frame(minWidth: 240)
                                TextField("Cant.", value: $item.quantity, format: .number)
                                    .frame(width: 70)
                                TextField("Precio", value: $item.unitPrice, format: .number)
                                    .frame(width: 90)
                                TextField("IVA %", value: $item.taxRate, format: .number)
                                    .frame(width: 70)
                                Text(currency(item.totalAmount))
                                    .frame(width: 110, alignment: .trailing)
                                Button {
                                    removeItem(id: item.id)
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.borderless)
                                .disabled(items.count == 1)
                            }
                        }

                        HStack {
                            Button("Agregar linea") {
                                items.append(InvoiceItemDraft())
                            }
                            .buttonStyle(.bordered)
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Base imponible: \(currency(previewData.subtotal))")
                                Text("IVA: \(currency(previewData.taxAmount))")
                                Text("IRPF (\(formatNumber(previewData.withholdingRate))%): -\(currency(previewData.withholdingAmount))")
                                Text("Total: \(currency(previewData.total))")
                                    .fontWeight(.bold)
                            }
                        }
                    }
                }

                GroupBox("Notas") {
                    TextEditor(text: $notes)
                        .frame(height: 120)
                }
            }
            .padding()
        }
    }

    private var previewPanel: some View {
        ScrollView {
            InvoiceDocumentView(previewData: previewData, includeFrame: true)
                .padding()
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func loadData() {
        if let invoice {
            number = invoice.number ?? ""
            issueDate = invoice.issueDate ?? Date()
            if let savedDueDate = invoice.dueDate {
                dueDate = savedDueDate
                hasDueDate = true
            } else {
                hasDueDate = false
            }
            status = invoice.status ?? "draft"
            notes = invoice.notes ?? ""
            selectedCompany = invoice.company
            selectedContact = invoice.contact
            let savedItems = ((invoice.items as? Set<CDInvoiceItem>) ?? [])
                .sorted { $0.position < $1.position }
                .map {
                    InvoiceItemDraft(
                        concept: $0.concept ?? "",
                        quantity: $0.quantity,
                        unitPrice: $0.unitPrice,
                        taxRate: $0.taxRate
                    )
                }
            items = savedItems.isEmpty ? [InvoiceItemDraft()] : savedItems
        } else {
            number = nextInvoiceNumber()
        }
    }

    private func nextInvoiceNumber() -> String {
        let year = Calendar.current.component(.year, from: Date())
        let prefix = "TS-\(year)-"
        let sequence = existingInvoices
            .compactMap { $0.number }
            .filter { $0.hasPrefix(prefix) }
            .compactMap { Int($0.replacingOccurrences(of: prefix, with: "")) }
            .max() ?? 0
        return prefix + String(format: "%03d", sequence + 1)
    }

    private func removeItem(id: UUID) {
        items.removeAll { $0.id == id }
        if items.isEmpty {
            items = [InvoiceItemDraft()]
        }
    }

    private func sanitizedItems() -> [InvoiceItemDraft] {
        items.filter {
            !$0.concept.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.quantity > 0
        }
    }

    private func clientData() -> InvoicePreviewData.ClientData {
        let companyName = selectedCompany?.name ?? ""
        let contactName = "\(selectedContact?.firstName ?? "") \(selectedContact?.lastName ?? "")".trimmingCharacters(in: .whitespaces)
        let name = companyName.isEmpty ? (contactName.isEmpty ? "Cliente pendiente" : contactName) : companyName
        let taxId = selectedCompany?.taxId ?? selectedContact?.taxId ?? ""
        let address = selectedCompany?.address ?? selectedContact?.address ?? ""
        let city = [selectedCompany?.postalCode, selectedCompany?.city, selectedCompany?.province, selectedCompany?.country, selectedContact?.postalCode, selectedContact?.city, selectedContact?.province, selectedContact?.country]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return InvoicePreviewData.ClientData(
            name: name,
            taxId: taxId,
            address: address,
            cityLine: city,
            email: selectedCompany?.email ?? selectedContact?.email ?? "",
            phone: selectedCompany?.phone ?? selectedContact?.phone ?? ""
        )
    }

    private func save() {
        let target = invoice ?? CDInvoice(context: context)
        if invoice == nil {
            target.id = UUID()
            target.createdAt = Date()
        }
        let cleanItems = sanitizedItems()
        target.number = number
        target.issueDate = issueDate
        target.dueDate = hasDueDate ? dueDate : nil
        target.status = status
        target.notes = notes
        target.company = selectedCompany
        target.contact = selectedContact
        target.subtotal = previewData.subtotal
        target.taxAmount = previewData.taxAmount
        target.total = previewData.total
        target.updatedAt = Date()

        let issuer = issuerProfile()
        target.issuerName = issuer.name
        target.issuerTaxId = issuer.taxId
        target.issuerAddress = issuer.address
        target.issuerPostalCode = issuer.postalCode
        target.issuerCity = issuer.city
        target.issuerProvince = issuer.province
        target.issuerCountry = issuer.country
        target.issuerEmail = issuer.email
        target.issuerPhone = issuer.phone
        target.issuerIban = issuer.iban

        if let existingItems = target.items as? Set<CDInvoiceItem> {
            for item in existingItems {
                context.delete(item)
            }
        }

        for (index, item) in cleanItems.enumerated() {
            let newItem = CDInvoiceItem(context: context)
            newItem.id = UUID()
            newItem.position = Int32(index)
            newItem.concept = item.concept
            newItem.quantity = item.quantity
            newItem.unitPrice = item.unitPrice
            newItem.taxRate = item.taxRate
            newItem.lineTotal = item.totalAmount
            newItem.invoice = target
        }

        PersistenceController.shared.save()
        dismiss()
    }

    private func exportCurrentPreview() throws {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = "\(number.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "factura" : number).pdf"
        panel.canCreateDirectories = true
        if panel.runModal() != .OK || panel.url == nil {
            return
        }
        let data = try InvoicePDFExporter.export(previewData: previewData)
        try data.write(to: panel.url!)
    }
}

struct InvoicePreviewView: View {
    let previewData: InvoicePreviewData
    @State private var exportError = ""
    @State private var showingError = false
    @State private var showingSendSheet = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Vista final")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Button("Enviar factura") {
                    showingSendSheet = true
                }
                .buttonStyle(.bordered)
                Button("Exportar PDF") {
                    do {
                        try exportPDF()
                    } catch {
                        exportError = error.localizedDescription
                        showingError = true
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()

            ScrollView {
                InvoiceDocumentView(previewData: previewData, includeFrame: true)
                    .padding()
            }
        }
        .frame(width: 960, height: 760)
        .sheet(isPresented: $showingSendSheet) {
            InvoiceEmailSheet(previewData: previewData)
        }
        .alert("No se pudo exportar", isPresented: $showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportError)
        }
    }

    private func exportPDF() throws {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = "\(previewData.number.isEmpty ? "factura" : previewData.number).pdf"
        panel.canCreateDirectories = true
        if panel.runModal() != .OK || panel.url == nil {
            return
        }
        let data = try InvoicePDFExporter.export(previewData: previewData)
        try data.write(to: panel.url!)
    }
}

private struct InvoiceEmailSheet: View {
    let previewData: InvoicePreviewData

    @Environment(\.dismiss) private var dismiss
    @AppStorage("communication.corporateEmail") private var corporateEmail = CommunicationViewModel.defaultCorporateEmail
    @AppStorage("communication.signature") private var corporateSignature = CommunicationViewModel.defaultSignature
    @State private var recipient = ""
    @State private var subject = ""
    @State private var bodyText = ""
    @State private var sending = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showingAlert = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Enviar factura")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Button("Cancelar") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                Button {
                    Task { await sendInvoice() }
                } label: {
                    if sending {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("Enviar")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(sending || recipient.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()

            Form {
                Section("Destinatario") {
                    TextField("Correo del cliente", text: $recipient)
                }

                Section("Mensaje") {
                    TextField("Asunto", text: $subject)
                    TextEditor(text: $bodyText)
                        .frame(height: 220)
                }

                Section("Adjunto") {
                    Text("Se enviara el PDF de la factura \(previewData.number.isEmpty ? "sin numero" : previewData.number).")
                        .foregroundColor(.secondary)
                    if !corporateEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("Cuenta corporativa configurada: \(corporateEmail)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 640, height: 560)
        .alert(alertTitle, isPresented: $showingAlert) {
            Button("OK", role: .cancel) {
                if alertTitle == "Factura enviada" {
                    dismiss()
                }
            }
        } message: {
            Text(alertMessage)
        }
        .onAppear {
            if recipient.isEmpty {
                recipient = previewData.client.email
            }
            if subject.isEmpty {
                subject = "Factura \(previewData.number.isEmpty ? "adjunta" : previewData.number)"
            }
            if bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                bodyText = defaultBody()
            }
        }
    }

    private func defaultBody() -> String {
        let greetingName = previewData.client.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let greeting = greetingName.isEmpty ? "Hola," : "Hola \(greetingName),"
        let signature = corporateSignature.trimmingCharacters(in: .whitespacesAndNewlines)
        return [
            greeting,
            "",
            "Te adjunto la factura \(previewData.number.isEmpty ? "correspondiente" : previewData.number).",
            "",
            signature
        ]
        .filter { !$0.isEmpty }
        .joined(separator: "\n")
    }

    private func sendInvoice() async {
        sending = true
        defer { sending = false }

        do {
            let pdfData = try InvoicePDFExporter.export(previewData: previewData)
            try await EmailAPIClient.send(
                to: [recipient.trimmingCharacters(in: .whitespacesAndNewlines)],
                subject: subject,
                text: bodyText,
                source: "invoice",
                attachmentBase64: pdfData.base64EncodedString(),
                attachmentName: "\(previewData.number.isEmpty ? "factura" : previewData.number).pdf"
            )
            alertTitle = "Factura enviada"
            alertMessage = "La factura se ha enviado correctamente por correo."
            showingAlert = true
        } catch {
            alertTitle = "No se pudo enviar"
            alertMessage = error.localizedDescription
            showingAlert = true
        }
    }
}

struct InvoiceIssuerSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("invoice.issuer.name") private var name = "TALENTO SOSTENIBLE\nMarcos Daniel Alfonso"
    @AppStorage("invoice.issuer.taxId") private var taxId = "Y9718788Z"
    @AppStorage("invoice.issuer.address") private var address = "Embajadores 85 1D portal B"
    @AppStorage("invoice.issuer.postalCode") private var postalCode = "28012"
    @AppStorage("invoice.issuer.city") private var city = "Madrid"
    @AppStorage("invoice.issuer.province") private var province = "Comunidad de Madrid"
    @AppStorage("invoice.issuer.country") private var country = "Espana"
    @AppStorage("invoice.issuer.email") private var email = "alfonsomarcos@talentosostenibleconsulting.es"
    @AppStorage("invoice.issuer.phone") private var phone = "637754638"
    @AppStorage("invoice.issuer.iban") private var iban = ""
    @AppStorage("invoice.issuer.bankHolder") private var bankHolder = "TALENTO SOSTENIBLE, Marcos Daniel Alfonso"
    @AppStorage("invoice.issuer.bankName") private var bankName = ""
    @AppStorage("invoice.issuer.paymentTerms") private var paymentTerms = "Transferencia bancaria"
    @AppStorage("invoice.withholdingRate") private var withholdingRate = 15.0

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Datos del emisor")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Button("Cerrar") { dismiss() }
                    .buttonStyle(.borderedProminent)
            }
            .padding()

            Form {
                Section("Obligatorio en Espana") {
                    TextField("Nombre o razon social", text: $name)
                    TextField("NIF / CIF", text: $taxId)
                    TextField("Direccion fiscal", text: $address)
                    TextField("Codigo postal", text: $postalCode)
                    TextField("Ciudad", text: $city)
                    TextField("Provincia", text: $province)
                    TextField("Pais", text: $country)
                }
                Section("Contacto") {
                    TextField("Email", text: $email)
                    TextField("Telefono", text: $phone)
                }
                Section("Cobros") {
                    TextField("IBAN", text: $iban)
                    TextField("Titular de la cuenta", text: $bankHolder)
                    TextField("Entidad bancaria", text: $bankName)
                    TextField("Condiciones de pago", text: $paymentTerms)
                }
                Section("Fiscalidad por defecto") {
                    TextField("IRPF %", value: $withholdingRate, format: .number)
                    Text("Se aplicara por defecto sobre la base imponible de la factura. Para profesionales en Espana suele ser 15%.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 560, height: 620)
    }
}

struct InvoiceDocumentView: View {
    let previewData: InvoicePreviewData
    let includeFrame: Bool

    private let brandGreen = Color(red: 0.19, green: 0.46, blue: 0.27)

    private var tableRowCount: Int {
        max(previewData.items.count, 6)
    }

    private var brandName: String {
        let cleaned = previewData.issuer.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "Talento Sostenible" : cleaned
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 28) {
                headerSection

                Rectangle()
                    .fill(brandGreen.opacity(0.35))
                    .frame(height: 1)

                HStack(alignment: .top, spacing: 24) {
                    partySection(
                        title: "EMISOR",
                        icon: "person.crop.circle",
                        name: brandName,
                        taxId: previewData.issuer.taxId,
                        address: previewData.issuer.address,
                        cityLine: composeIssuerCityLine(previewData.issuer),
                        email: previewData.issuer.email,
                        phone: previewData.issuer.phone
                    )

                    partySection(
                        title: "CLIENTE",
                        icon: "person.crop.circle.badge.checkmark",
                        name: previewData.client.name,
                        taxId: previewData.client.taxId,
                        address: previewData.client.address,
                        cityLine: previewData.client.cityLine,
                        email: previewData.client.email,
                        phone: previewData.client.phone
                    )
                }

                Rectangle()
                    .fill(Color.black.opacity(0.12))
                    .frame(height: 1)

                itemsSection

                HStack(alignment: .bottom) {
                    Spacer()
                    totalsSection
                        .frame(width: 320)
                }

                HStack(alignment: .top, spacing: 28) {
                    bottomInfoSection(
                        title: "CONDICIONES DE PAGO",
                        icon: "creditcard",
                        lines: paymentConditionsLines()
                    )

                    Rectangle()
                        .fill(Color.black.opacity(0.12))
                        .frame(width: 1, height: 72)

                    bottomInfoSection(
                        title: "OBSERVACIONES",
                        icon: "doc.text",
                        lines: observationLines()
                    )
                }
            }
            .padding(.horizontal, 40)
            .padding(.top, 38)
            .padding(.bottom, 28)

            footerBand
        }
        .frame(width: 820, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: includeFrame ? 14 : 0))
        .shadow(color: includeFrame ? .black.opacity(0.08) : .clear, radius: 16, y: 6)
    }

    private var headerSection: some View {
        HStack(alignment: .top) {
            HStack(alignment: .center, spacing: 16) {
                if let logoImage = appLogoImage() {
                    Image(nsImage: logoImage)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 84, height: 84)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 4) {
                    ForEach(brandName.components(separatedBy: "\n"), id: \.self) { line in
                        if !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(line)
                                .font(line == brandName.components(separatedBy: "\n").first ? .system(size: 28, weight: .bold) : .system(size: 22, weight: .semibold))
                                .foregroundColor(brandGreen)
                        }
                    }
                    Text("CONSULTORIA PARA UN FUTURO MEJOR")
                        .font(.system(size: 10, weight: .medium))
                        .tracking(0.8)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
            VStack(alignment: .trailing, spacing: 10) {
                Text("FACTURA")
                    .font(.system(size: 30, weight: .heavy))
                    .foregroundColor(brandGreen)

                invoiceMetaLine(title: "Nº de factura:", value: previewData.number)
                invoiceMetaLine(title: "Fecha de emision:", value: shortDate(previewData.issueDate))
                invoiceMetaLine(title: "Fecha de vencimiento:", value: previewData.dueDate.map(shortDate) ?? "No indicada")
                invoiceMetaLine(title: "Estado:", value: invoiceStatusLabel(previewData.status))
            }
        }
    }

    private var itemsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 0) {
                invoiceTableHeader(title: "Concepto", width: 110, alignment: .leading)
                invoiceTableHeader(title: "Descripcion", width: 300, alignment: .leading)
                invoiceTableHeader(title: "Cantidad", width: 105, alignment: .trailing)
                invoiceTableHeader(title: "Precio unitario", width: 110, alignment: .trailing)
                invoiceTableHeader(title: "Subtotal", width: 115, alignment: .trailing)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 12)
            .background(Color.black.opacity(0.04))

            ForEach(0..<tableRowCount, id: \.self) { index in
                let item = previewData.items.indices.contains(index) ? previewData.items[index] : nil
                HStack(spacing: 0) {
                    Text(item == nil ? "" : conceptCode(for: index))
                        .frame(width: 110, alignment: .leading)
                    Text(item?.concept ?? "")
                        .frame(width: 300, alignment: .leading)
                    Text(item.map { number($0.quantity) } ?? "")
                        .frame(width: 105, alignment: .trailing)
                    Text(item.map { currency($0.unitPrice) } ?? "")
                        .frame(width: 110, alignment: .trailing)
                    Text(item.map { currency($0.baseAmount) } ?? "")
                        .frame(width: 115, alignment: .trailing)
                }
                .frame(height: 34)
                .padding(.horizontal, 12)
                .background(Color.white)

                Rectangle()
                    .fill(Color.black.opacity(0.08))
                    .frame(height: 1)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.black.opacity(0.12), lineWidth: 1)
        )
    }

    private var totalsSection: some View {
        VStack(spacing: 0) {
            totalRow(title: "Base imponible", value: currency(previewData.subtotal), emphasize: false)
            totalRow(title: "IVA (\(taxSummaryLabel()))", value: currency(previewData.taxAmount), emphasize: false)
            totalRow(title: "IRPF (\(formatNumber(previewData.withholdingRate))%)", value: "-\(currency(previewData.withholdingAmount))", emphasize: false)
            totalRow(title: "TOTAL FACTURA", value: currency(previewData.total), emphasize: true)
        }
        .background(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.black.opacity(0.12), lineWidth: 1)
        )
    }

    private var footerBand: some View {
        HStack(spacing: 14) {
            if let logoImage = appLogoImage() {
                Image(nsImage: logoImage)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 34, height: 34)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(brandName.replacingOccurrences(of: "\n", with: " "))
                    .font(.caption)
                    .fontWeight(.semibold)
                Text(footerSummary())
                    .font(.caption2)
            }
            .foregroundColor(.white)

            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(brandGreen)
    }

    private func invoiceMetaLine(title: String, value: String) -> some View {
        HStack(spacing: 16) {
            Text(title)
                .font(.body)
                .foregroundColor(.secondary)
            Text(value)
                .font(.body)
                .fontWeight(.medium)
        }
    }

    private func partySection(title: String, icon: String, name: String, taxId: String, address: String, cityLine: String, email: String, phone: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundColor(brandGreen)

            Text(name.isEmpty ? "Pendiente" : name)
                .font(.title3)
                .fontWeight(.semibold)

            if !taxId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("NIF: \(taxId)")
            }
            if !address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(address)
            }
            if !cityLine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(cityLine)
            }
            if !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(email)
            }
            if !phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(phone)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func invoiceTableHeader(title: String, width: CGFloat, alignment: Alignment) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .fontWeight(.semibold)
            .foregroundColor(brandGreen)
            .frame(width: width, alignment: alignment)
    }

    private func totalRow(title: String, value: String, emphasize: Bool) -> some View {
        HStack {
            Text(title)
                .foregroundColor(emphasize ? brandGreen : .primary)
            Text(value)
                .fontWeight(emphasize ? .bold : .regular)
        }
        .font(emphasize ? .title3 : .body)
        .padding(.horizontal, 18)
        .padding(.vertical, emphasize ? 12 : 10)
        .frame(maxWidth: .infinity)
        .background(emphasize ? brandGreen.opacity(0.10) : Color.white)
    }

    private func composeIssuerCityLine(_ issuer: InvoiceIssuerProfile) -> String {
        [issuer.postalCode, issuer.city, issuer.province, issuer.country]
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: " ")
    }

    private func conceptCode(for index: Int) -> String {
        String(format: "%03d", index + 1)
    }

    private func taxSummaryLabel() -> String {
        let uniqueRates = Array(Set(previewData.items.map { number($0.taxRate) })).sorted()
        return uniqueRates.isEmpty ? "21%" : uniqueRates.joined(separator: ", ") + "%"
    }

    private func paymentConditionsLines() -> [String] {
        var lines: [String] = []
        let configuredTerms = previewData.issuer.paymentTerms.trimmingCharacters(in: .whitespacesAndNewlines)
        if !configuredTerms.isEmpty {
            lines.append(configuredTerms)
        } else if let dueDate = previewData.dueDate {
            let days = max(Calendar.current.dateComponents([.day], from: previewData.issueDate, to: dueDate).day ?? 0, 0)
            lines.append("Transferencia bancaria a \(days) dias fecha factura.")
        } else {
            lines.append("Transferencia bancaria segun acuerdo comercial.")
        }
        let holder = previewData.issuer.bankHolder.trimmingCharacters(in: .whitespacesAndNewlines)
        lines.append("Titular: \(holder.isEmpty ? brandName.replacingOccurrences(of: "\n", with: " ") : holder)")
        if !previewData.issuer.bankName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lines.append("Entidad: \(previewData.issuer.bankName)")
        }
        if !previewData.issuer.iban.isEmpty {
            lines.append("IBAN: \(previewData.issuer.iban)")
        }
        return lines
    }

    private func observationLines() -> [String] {
        let cleanedNotes = previewData.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanedNotes.isEmpty {
            return ["Agradecemos su confianza."]
        }
        return cleanedNotes.components(separatedBy: .newlines)
    }

    private func bottomInfoSection(title: String, icon: String, lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundColor(brandGreen)
            ForEach(lines, id: \.self) { line in
                Text(line)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func footerSummary() -> String {
        [
            previewData.issuer.taxId.isEmpty ? nil : "NIF: \(previewData.issuer.taxId)",
            previewData.issuer.address.isEmpty ? nil : previewData.issuer.address,
            composeIssuerCityLine(previewData.issuer).isEmpty ? nil : composeIssuerCityLine(previewData.issuer),
            previewData.issuer.email.isEmpty ? nil : previewData.issuer.email,
            previewData.issuer.phone.isEmpty ? nil : previewData.issuer.phone,
            issuerWebsite()
        ]
        .compactMap { $0 }
        .joined(separator: "   |   ")
    }

    private func issuerWebsite() -> String? {
        guard let emailDomain = previewData.issuer.email.split(separator: "@").last else { return nil }
        return "www.\(emailDomain)"
    }

    private func appLogoImage() -> NSImage? {
        guard let image = NSApplication.shared.applicationIconImage else {
            return nil
        }
        return image.size.width > 0 ? image : nil
    }
}

enum InvoicePDFExporter {
    static func export(previewData: InvoicePreviewData) throws -> Data {
        let view = InvoiceDocumentView(previewData: previewData, includeFrame: false)
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = NSRect(x: 0, y: 0, width: 820, height: 1200)
        hostingView.layoutSubtreeIfNeeded()
        let fittingHeight = max(hostingView.fittingSize.height, 1160)
        hostingView.frame = NSRect(x: 0, y: 0, width: 820, height: fittingHeight)
        hostingView.layoutSubtreeIfNeeded()
        guard let data = hostingView.dataWithPDF(inside: hostingView.bounds) as Data? else {
            throw NSError(domain: "InvoicePDFExporter", code: 1, userInfo: [NSLocalizedDescriptionKey: "No se pudo generar el PDF."])
        }
        return data
    }
}

extension InvoicePreviewData {
    static func from(invoice: CDInvoice) -> InvoicePreviewData {
        let items = ((invoice.items as? Set<CDInvoiceItem>) ?? [])
            .sorted { $0.position < $1.position }
            .map {
                InvoiceItemDraft(
                    concept: $0.concept ?? "",
                    quantity: $0.quantity,
                    unitPrice: $0.unitPrice,
                    taxRate: $0.taxRate
                )
            }

        let clientName: String = {
            if let companyName = invoice.company?.name, !companyName.isEmpty { return companyName }
            let contactName = "\(invoice.contact?.firstName ?? "") \(invoice.contact?.lastName ?? "")".trimmingCharacters(in: .whitespaces)
            return contactName.isEmpty ? "Cliente" : contactName
        }()

        let issuer = InvoiceIssuerProfile(
            name: invoice.issuerName ?? issuerProfile().name,
            taxId: invoice.issuerTaxId ?? issuerProfile().taxId,
            address: invoice.issuerAddress ?? issuerProfile().address,
            postalCode: invoice.issuerPostalCode ?? issuerProfile().postalCode,
            city: invoice.issuerCity ?? issuerProfile().city,
            province: invoice.issuerProvince ?? issuerProfile().province,
            country: invoice.issuerCountry ?? issuerProfile().country,
            email: invoice.issuerEmail ?? issuerProfile().email,
            phone: invoice.issuerPhone ?? issuerProfile().phone,
            iban: invoice.issuerIban ?? issuerProfile().iban,
            bankHolder: issuerProfile().bankHolder,
            bankName: issuerProfile().bankName,
            paymentTerms: issuerProfile().paymentTerms
        )

        return InvoicePreviewData(
            number: invoice.number ?? "",
            issueDate: invoice.issueDate ?? Date(),
            dueDate: invoice.dueDate,
            status: invoice.status ?? "draft",
            notes: invoice.notes ?? "",
            withholdingRate: defaultInvoiceWithholdingRate(),
            issuer: issuer,
            client: .init(
                name: clientName,
                taxId: invoice.company?.taxId ?? invoice.contact?.taxId ?? "",
                address: invoice.company?.address ?? invoice.contact?.address ?? "",
                cityLine: [invoice.company?.postalCode, invoice.company?.city, invoice.company?.province, invoice.company?.country, invoice.contact?.postalCode, invoice.contact?.city, invoice.contact?.province, invoice.contact?.country]
                    .compactMap { $0 }
                    .filter { !$0.isEmpty }
                    .joined(separator: " "),
                email: invoice.company?.email ?? invoice.contact?.email ?? "",
                phone: invoice.company?.phone ?? invoice.contact?.phone ?? ""
            ),
            items: items
        )
    }
}

private func invoiceStatusLabel(_ status: String) -> String {
    switch status {
    case "draft": return "Borrador"
    case "issued": return "Emitida"
    case "paid": return "Pagada"
    case "overdue": return "Vencida"
    case "cancelled": return "Anulada"
    default: return status
    }
}

private func invoiceStatusColor(_ status: String) -> Color {
    switch status {
    case "draft": return .gray
    case "issued": return .blue
    case "paid": return .green
    case "overdue": return .red
    case "cancelled": return .orange
    default: return .gray
    }
}

private func expensePaymentMethodLabel(_ method: String) -> String {
    switch method {
    case "transfer": return "Transferencia"
    case "card": return "Tarjeta"
    case "cash": return "Efectivo"
    case "direct_debit": return "Domiciliacion"
    default: return method
    }
}

private func issuerProfile() -> InvoiceIssuerProfile {
    let defaults = UserDefaults.standard
    return InvoiceIssuerProfile(
        name: defaults.string(forKey: "invoice.issuer.name") ?? "TALENTO SOSTENIBLE\nMarcos Daniel Alfonso",
        taxId: defaults.string(forKey: "invoice.issuer.taxId") ?? "Y9718788Z",
        address: defaults.string(forKey: "invoice.issuer.address") ?? "Embajadores 85 1D portal B",
        postalCode: defaults.string(forKey: "invoice.issuer.postalCode") ?? "28012",
        city: defaults.string(forKey: "invoice.issuer.city") ?? "Madrid",
        province: defaults.string(forKey: "invoice.issuer.province") ?? "Comunidad de Madrid",
        country: defaults.string(forKey: "invoice.issuer.country") ?? "Espana",
        email: defaults.string(forKey: "invoice.issuer.email") ?? "",
        phone: defaults.string(forKey: "invoice.issuer.phone") ?? "",
        iban: defaults.string(forKey: "invoice.issuer.iban") ?? "",
        bankHolder: defaults.string(forKey: "invoice.issuer.bankHolder") ?? "TALENTO SOSTENIBLE, Marcos Daniel Alfonso",
        bankName: defaults.string(forKey: "invoice.issuer.bankName") ?? "",
        paymentTerms: defaults.string(forKey: "invoice.issuer.paymentTerms") ?? "Transferencia bancaria"
    )
}

private func defaultInvoiceWithholdingRate() -> Double {
    let defaults = UserDefaults.standard
    let configuredRate = defaults.object(forKey: "invoice.withholdingRate") as? Double
    return configuredRate ?? 15.0
}

private func formatNumber(_ value: Double) -> String {
    number(value)
}

private func currency(_ value: Double) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.currencyCode = "EUR"
    formatter.locale = Locale(identifier: "es_ES")
    return formatter.string(from: NSNumber(value: value)) ?? "€0,00"
}

private func shortDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "es_ES")
    formatter.dateStyle = .medium
    return formatter.string(from: date)
}

private func number(_ value: Double) -> String {
    let formatter = NumberFormatter()
    formatter.locale = Locale(identifier: "es_ES")
    formatter.maximumFractionDigits = 2
    formatter.minimumFractionDigits = value.truncatingRemainder(dividingBy: 1) == 0 ? 0 : 2
    return formatter.string(from: NSNumber(value: value)) ?? "0"
}