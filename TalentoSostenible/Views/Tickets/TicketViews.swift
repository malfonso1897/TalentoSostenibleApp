import SwiftUI
import CoreData

struct TicketListView: View {
    @Environment(\.managedObjectContext) private var context
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \CDTicket.createdAt, ascending: false)],
        animation: .default
    ) private var tickets: FetchedResults<CDTicket>

    @State private var searchText = ""
    @State private var showingForm = false
    @State private var selectedTicket: CDTicket?
    @State private var showingDetail = false

    var filteredTickets: [CDTicket] {
        if searchText.isEmpty { return Array(tickets) }
        return tickets.filter {
            ($0.subject ?? "").localizedCaseInsensitiveContains(searchText) ||
            ($0.number ?? "").localizedCaseInsensitiveContains(searchText) ||
            ($0.assignee ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Tickets")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Spacer()
                TextField("Buscar ticket...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 220)
                Button("Nuevo ticket") {
                    selectedTicket = nil
                    showingForm = true
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
            .padding()

            Table(filteredTickets) {
                TableColumn("Numero") { t in
                    Text(t.number ?? "-")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                TableColumn("Asunto") { t in
                    Text(t.subject ?? "").fontWeight(.medium)
                }
                TableColumn("Responsable") { t in
                    Text(t.assignee ?? "-")
                }
                TableColumn("Contacto") { t in
                    if let c = t.contact {
                        Text("\(c.firstName ?? "") \(c.lastName ?? "")")
                    } else {
                        Text("-")
                    }
                }
                TableColumn("Prioridad") { t in
                    StatusBadge(text: t.priority ?? "medium", color: priorityColor(t.priority ?? "medium"))
                }
                TableColumn("Estado") { t in
                    StatusBadge(text: ticketStatusLabel(t.status ?? "open"), color: ticketStatusColor(t.status ?? "open"))
                }
                TableColumn("SLA") { t in
                    if let deadline = t.slaDeadline {
                        Text(deadline, style: .date)
                            .foregroundColor(isOverdue(ticket: t) ? .red : .primary)
                    } else {
                        Text("-")
                    }
                }
                TableColumn("Fecha") { t in
                    if let d = t.createdAt { Text(d, style: .date) } else { Text("-") }
                }
                TableColumn("Acciones") { t in
                    HStack(spacing: 6) {
                        Button("Ver") {
                            selectedTicket = t
                            showingDetail = true
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        Button("Editar") {
                            selectedTicket = t
                            showingForm = true
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        Button("Eliminar") {
                            context.delete(t)
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
            TicketFormView(ticket: selectedTicket)
        }
        .sheet(isPresented: $showingDetail) {
            if let ticket = selectedTicket {
                TicketDetailView(ticket: ticket)
            }
        }
    }

    private func isOverdue(ticket: CDTicket) -> Bool {
        guard let deadline = ticket.slaDeadline else { return false }
        return !["resolved", "closed"].contains(ticket.status ?? "") && deadline < Date()
    }

    func priorityColor(_ p: String) -> Color {
        switch p {
        case "urgent": return .red
        case "high": return .orange
        case "medium": return .yellow
        case "low": return .gray
        default: return .gray
        }
    }

    func ticketStatusLabel(_ s: String) -> String {
        switch s {
        case "open": return "Abierto"
        case "in_progress": return "En curso"
        case "resolved": return "Resuelto"
        case "closed": return "Cerrado"
        default: return s
        }
    }

    func ticketStatusColor(_ s: String) -> Color {
        switch s {
        case "open": return .blue
        case "in_progress": return .orange
        case "resolved": return .green
        case "closed": return .gray
        default: return .gray
        }
    }
}

struct TicketFormView: View {
    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \CDContact.lastName, ascending: true)]) private var contacts: FetchedResults<CDContact>

    let ticket: CDTicket?

    @State private var subject = ""
    @State private var ticketDescription = ""
    @State private var priority = "medium"
    @State private var status = "open"
    @State private var category = ""
    @State private var assignee = ""
    @State private var slaDeadline = Calendar.current.date(byAdding: .day, value: 2, to: Date()) ?? Date()
    @State private var selectedContact: CDContact?

    let priorityOptions = ["low", "medium", "high", "urgent"]
    let statusOptions = ["open", "in_progress", "resolved", "closed"]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(ticket != nil ? "Editar ticket" : "Nuevo ticket")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Button("Cancelar") { dismiss() }
                    .buttonStyle(.bordered)
                Button("Guardar") { save() }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .disabled(subject.isEmpty)
            }
            .padding()

            Form {
                Section("Datos") {
                    TextField("Asunto", text: $subject)
                    TextField("Categoria", text: $category)
                    TextField("Responsable", text: $assignee)
                    Picker("Prioridad", selection: $priority) {
                        ForEach(priorityOptions, id: \.self) { Text($0) }
                    }
                    Picker("Estado", selection: $status) {
                        ForEach(statusOptions, id: \.self) { Text($0) }
                    }
                    DatePicker("Vencimiento SLA", selection: $slaDeadline, displayedComponents: [.date, .hourAndMinute])
                    Picker("Contacto", selection: $selectedContact) {
                        Text("Ninguno").tag(nil as CDContact?)
                        ForEach(contacts) { c in
                            Text("\(c.firstName ?? "") \(c.lastName ?? "")").tag(c as CDContact?)
                        }
                    }
                }
                Section("Descripcion") {
                    TextEditor(text: $ticketDescription)
                        .frame(height: 120)
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 500, height: 500)
        .onAppear {
            guard let t = ticket else { return }
            subject = t.subject ?? ""
            ticketDescription = t.ticketDescription ?? ""
            priority = t.priority ?? "medium"
            status = t.status ?? "open"
            category = t.category ?? ""
            assignee = t.assignee ?? ""
            slaDeadline = t.slaDeadline ?? slaDeadline
            selectedContact = t.contact
        }
    }

    private func save() {
        let isNewTicket = ticket == nil
        let t = ticket ?? CDTicket(context: context)
        if ticket == nil {
            t.id = UUID()
            t.createdAt = Date()
            t.number = nextTicketNumber()
        }
        t.subject = subject
        t.ticketDescription = ticketDescription
        t.priority = priority
        t.status = status
        t.category = category
        t.assignee = assignee.isEmpty ? nil : assignee
        t.slaDeadline = slaDeadline
        t.contact = selectedContact
        t.updatedAt = Date()
        PersistenceController.shared.save()
        if isNewTicket {
            WorkflowAutomationEngine.executeActiveWorkflows(
                triggerType: "ticket_creado",
                context: context,
                ticket: t
            )
        }
        dismiss()
    }

    private func nextTicketNumber() -> String {
        let request: NSFetchRequest<CDTicket> = CDTicket.fetchRequest()
        let count = (try? context.count(for: request)) ?? 0
        let year = Calendar.current.component(.year, from: Date())
        return String(format: "TCK-%d-%03d", year, count + 1)
    }
}

struct TicketDetailView: View {
    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var ticket: CDTicket
    @State private var newComment = ""

    var comments: [CDTicketComment] {
        let set = ticket.comments as? Set<CDTicketComment> ?? []
        return set.sorted { ($0.createdAt ?? Date()) < ($1.createdAt ?? Date()) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(ticket.subject ?? "Ticket")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text(ticket.number ?? "")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if let contact = ticket.contact {
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
                            subject: ticket.subject ?? contact.firstName ?? "Ticket",
                            contact: contact,
                            company: contact.company,
                            notes: "Ticket: \(ticket.number ?? "-")"
                        )
                    }
                }
                Button("Cerrar") { dismiss() }
                    .buttonStyle(.bordered)
            }
            .padding()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Info
                    GroupBox("Informacion") {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Responsable:")
                                    .foregroundColor(.secondary)
                                Text(ticket.assignee ?? "Sin asignar")
                            }
                            HStack {
                                Text("Prioridad:")
                                    .foregroundColor(.secondary)
                                Text(ticket.priority ?? "-")
                            }
                            HStack {
                                Text("Estado:")
                                    .foregroundColor(.secondary)
                                Text(ticket.status ?? "-")
                            }
                            HStack {
                                Text("SLA:")
                                    .foregroundColor(.secondary)
                                if let deadline = ticket.slaDeadline {
                                    Text(deadline, style: .date)
                                } else {
                                    Text("-")
                                }
                            }
                            if let desc = ticket.ticketDescription, !desc.isEmpty {
                                Text("Descripcion:")
                                    .foregroundColor(.secondary)
                                Text(desc)
                            }
                        }
                        .font(.callout)
                    }

                    // Comentarios
                    GroupBox("Comentarios") {
                        if comments.isEmpty {
                            Text("Sin comentarios")
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(comments) { comment in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(comment.content ?? "")
                                    if let d = comment.createdAt {
                                        Text(d, style: .date)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(nsColor: .controlBackgroundColor))
                                .cornerRadius(6)
                            }
                        }

                        HStack {
                            TextField("Escribir comentario...", text: $newComment)
                                .textFieldStyle(.roundedBorder)
                            Button("Enviar") { addComment() }
                                .buttonStyle(.borderedProminent)
                                .tint(.green)
                                .disabled(newComment.isEmpty)
                        }
                        .padding(.top, 8)
                    }
                }
                .padding()
            }
        }
        .frame(width: 600, height: 500)
    }

    private func addComment() {
        let comment = CDTicketComment(context: context)
        comment.id = UUID()
        comment.content = newComment
        comment.createdAt = Date()
        comment.ticket = ticket
        newComment = ""
        PersistenceController.shared.save()
    }
}
