import SwiftUI
import CoreData

enum WorkflowAutomationEngine {
    static func executeActiveWorkflows(
        triggerType: String,
        context: NSManagedObjectContext,
        lead: CDLead? = nil,
        opportunity: CDOpportunity? = nil,
        ticket: CDTicket? = nil,
        details: [String: String] = [:]
    ) {
        let request: NSFetchRequest<CDWorkflow> = CDWorkflow.fetchRequest()
        request.predicate = NSPredicate(format: "isActive == YES AND triggerType == %@", triggerType)

        guard let workflows = try? context.fetch(request), !workflows.isEmpty else { return }

        for workflow in workflows {
            execute(
                workflow: workflow,
                triggerType: triggerType,
                context: context,
                lead: lead,
                opportunity: opportunity,
                ticket: ticket,
                details: details
            )
        }

        PersistenceController.shared.save()
    }

    private static func execute(
        workflow: CDWorkflow,
        triggerType: String,
        context: NSManagedObjectContext,
        lead: CDLead?,
        opportunity: CDOpportunity?,
        ticket: CDTicket?,
        details: [String: String]
    ) {
        switch workflow.actionType {
        case "notification":
            NotificationManager.shared.sendWorkflowNotification(
                title: workflow.name ?? "Workflow ejecutado",
                body: summaryText(triggerType: triggerType, workflow: workflow, lead: lead, opportunity: opportunity, ticket: ticket, details: details)
            )
        case "email":
            createTask(
                subject: "Email pendiente: \(workflow.name ?? "Workflow")",
                notes: summaryText(triggerType: triggerType, workflow: workflow, lead: lead, opportunity: opportunity, ticket: ticket, details: details),
                context: context,
                lead: lead,
                opportunity: opportunity,
                ticket: ticket,
                dueInHours: 2
            )
        case "crear_tarea":
            createTask(
                subject: workflow.name ?? "Tarea automatica",
                notes: summaryText(triggerType: triggerType, workflow: workflow, lead: lead, opportunity: opportunity, ticket: ticket, details: details),
                context: context,
                lead: lead,
                opportunity: opportunity,
                ticket: ticket,
                dueInHours: 24
            )
        case "cambiar_estado":
            applyStatusChange(from: workflow, lead: lead, opportunity: opportunity, ticket: ticket)
        case "asignar":
            applyAssignment(from: workflow, lead: lead, opportunity: opportunity, ticket: ticket, context: context)
        default:
            break
        }

        workflow.executionCount += 1
        workflow.lastExecuted = Date()
        workflow.updatedAt = Date()
    }

    private static func createTask(
        subject: String,
        notes: String,
        context: NSManagedObjectContext,
        lead: CDLead?,
        opportunity: CDOpportunity?,
        ticket: CDTicket?,
        dueInHours: Int
    ) {
        let activity = CDActivity(context: context)
        activity.id = UUID()
        activity.subject = subject
        activity.activityType = "task"
        activity.workflowStatus = "todo"
        activity.priority = "medium"
        activity.isCompleted = false
        activity.notes = notes
        activity.createdAt = Date()
        activity.updatedAt = Date()
        activity.dueDate = Calendar.current.date(byAdding: .hour, value: dueInHours, to: Date())

        if let opportunity {
            activity.opportunity = opportunity
            activity.contact = opportunity.contact
            activity.company = opportunity.company
        } else if let ticket {
            activity.contact = ticket.contact
            activity.company = ticket.contact?.company
        } else if let lead {
            activity.notes = [notes, lead.companyName].compactMap { value in
                guard let value, !value.isEmpty else { return nil }
                return value == notes ? value : "Empresa lead: \(value)"
            }.joined(separator: "\n")
        }

        NotificationManager.shared.scheduleActivityReminder(activity)
    }

    private static func applyStatusChange(from workflow: CDWorkflow, lead: CDLead?, opportunity: CDOpportunity?, ticket: CDTicket?) {
        let target = configuredValue(prefix: "status:", in: workflow.notes)

        if let lead {
            lead.status = target ?? "contacted"
            lead.updatedAt = Date()
            return
        }

        if let opportunity {
            opportunity.stage = target ?? nextStage(from: opportunity.stage ?? "prospecting")
            opportunity.updatedAt = Date()
            return
        }

        if let ticket {
            ticket.status = target ?? "in_progress"
            ticket.updatedAt = Date()
        }
    }

    private static func applyAssignment(from workflow: CDWorkflow, lead: CDLead?, opportunity: CDOpportunity?, ticket: CDTicket?, context: NSManagedObjectContext) {
        let assignee = configuredValue(prefix: "assignee:", in: workflow.notes) ?? "Equipo"

        if let opportunity {
            let activity = CDActivity(context: context)
            activity.id = UUID()
            activity.subject = "Seguimiento asignado: \(opportunity.name ?? workflow.name ?? "Oportunidad")"
            activity.activityType = "task"
            activity.assignee = assignee
            activity.workflowStatus = "todo"
            activity.priority = "high"
            activity.isCompleted = false
            activity.contact = opportunity.contact
            activity.company = opportunity.company
            activity.opportunity = opportunity
            activity.createdAt = Date()
            activity.updatedAt = Date()
            activity.dueDate = Calendar.current.date(byAdding: .hour, value: 8, to: Date())
            NotificationManager.shared.scheduleActivityReminder(activity)
            return
        }

        if let ticket {
            ticket.assignee = assignee
            ticket.updatedAt = Date()
            return
        }

        if let lead {
            let activity = CDActivity(context: context)
            activity.id = UUID()
            activity.subject = "Gestionar lead: \(lead.firstName ?? "") \(lead.lastName ?? "")"
            activity.activityType = "task"
            activity.assignee = assignee
            activity.workflowStatus = "todo"
            activity.priority = "high"
            activity.isCompleted = false
            activity.notes = summaryText(triggerType: "nuevo_lead", workflow: workflow, lead: lead, opportunity: nil, ticket: nil, details: [:])
            activity.createdAt = Date()
            activity.updatedAt = Date()
            activity.dueDate = Calendar.current.date(byAdding: .hour, value: 8, to: Date())
            NotificationManager.shared.scheduleActivityReminder(activity)
        }
    }

    private static func summaryText(
        triggerType: String,
        workflow: CDWorkflow,
        lead: CDLead?,
        opportunity: CDOpportunity?,
        ticket: CDTicket?,
        details: [String: String]
    ) -> String {
        var lines: [String] = ["Workflow: \(workflow.name ?? "Sin nombre")", "Disparador: \(triggerLabel(triggerType))"]

        if let lead {
            lines.append("Lead: \(lead.firstName ?? "") \(lead.lastName ?? "")".trimmingCharacters(in: .whitespaces))
        }
        if let opportunity {
            lines.append("Oportunidad: \(opportunity.name ?? "")")
        }
        if let ticket {
            lines.append("Ticket: \(ticket.number ?? "-") - \(ticket.subject ?? "")")
        }

        for key in details.keys.sorted() {
            if let value = details[key], !value.isEmpty {
                lines.append("\(key): \(value)")
            }
        }

        if let note = workflow.notes, !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lines.append("Configuracion: \(note)")
        }

        return lines.joined(separator: "\n")
    }

    private static func configuredValue(prefix: String, in notes: String?) -> String? {
        guard let notes else { return nil }
        let line = notes
            .components(separatedBy: .newlines)
            .first { $0.lowercased().hasPrefix(prefix) }
        return line?
            .dropFirst(prefix.count)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func nextStage(from current: String) -> String {
        switch current {
        case "prospecting": return "qualification"
        case "qualification": return "proposal"
        case "proposal": return "negotiation"
        default: return current
        }
    }

    private static func triggerLabel(_ trigger: String) -> String {
        switch trigger {
        case "manual": return "Manual"
        case "nuevo_lead": return "Nuevo lead"
        case "cambio_etapa": return "Cambio de etapa"
        case "ticket_creado": return "Ticket creado"
        case "fecha_programada": return "Fecha programada"
        default: return trigger
        }
    }
}

struct WorkflowListView: View {
    @Environment(\.managedObjectContext) private var context
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \CDWorkflow.createdAt, ascending: false)],
        animation: .default
    ) private var workflows: FetchedResults<CDWorkflow>

    @State private var showingForm = false
    @State private var selectedWorkflow: CDWorkflow?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Automatizacion")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Spacer()
                Button("Nuevo workflow") {
                    selectedWorkflow = nil
                    showingForm = true
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
            .padding()

            Table(workflows) {
                TableColumn("Nombre") { w in
                    Text(w.name ?? "").fontWeight(.medium)
                }
                TableColumn("Disparador") { w in
                    Text(w.triggerType ?? "-")
                }
                TableColumn("Accion") { w in
                    Text(w.actionType ?? "-")
                }
                TableColumn("Estado") { w in
                    if w.isActive {
                        StatusBadge(text: "Activo", color: .green)
                    } else {
                        StatusBadge(text: "Inactivo", color: .gray)
                    }
                }
                TableColumn("Ejecuciones") { w in
                    Text("\(w.executionCount)")
                }
                TableColumn("Acciones") { w in
                    HStack(spacing: 6) {
                        if w.triggerType == "manual" {
                            Button("Ejecutar") {
                                WorkflowAutomationEngine.executeActiveWorkflows(
                                    triggerType: "manual",
                                    context: context
                                )
                            }
                            .buttonStyle(.bordered)
                            .tint(.blue)
                            .controlSize(.small)
                        }
                        Button(w.isActive ? "Desactivar" : "Activar") {
                            w.isActive.toggle()
                            w.updatedAt = Date()
                            PersistenceController.shared.save()
                        }
                        .buttonStyle(.bordered)
                        .tint(w.isActive ? .orange : .green)
                        .controlSize(.small)
                        Button("Editar") {
                            selectedWorkflow = w
                            showingForm = true
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        Button("Eliminar") {
                            context.delete(w)
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
            WorkflowFormView(workflow: selectedWorkflow)
        }
    }
}

struct WorkflowFormView: View {
    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss

    let workflow: CDWorkflow?

    @State private var name = ""
    @State private var triggerType = "manual"
    @State private var actionType = "notification"
    @State private var isActive = true
    @State private var notes = ""

    let triggerOptions = ["manual", "nuevo_lead", "cambio_etapa", "ticket_creado", "fecha_programada"]
    let actionOptions = ["notification", "email", "crear_tarea", "cambiar_estado", "asignar"]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(workflow != nil ? "Editar workflow" : "Nuevo workflow")
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
                    Picker("Disparador", selection: $triggerType) {
                        ForEach(triggerOptions, id: \.self) { Text($0) }
                    }
                    Picker("Accion", selection: $actionType) {
                        ForEach(actionOptions, id: \.self) { Text($0) }
                    }
                    Toggle("Activo", isOn: $isActive)
                }
                Section("Comportamiento") {
                    Text(workflowBehaviorHelp)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("Configuracion opcional", text: $notes, axis: .vertical)
                        .lineLimit(3...5)
                    Text(configurationHelp)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Section("Notas") {
                    TextEditor(text: $notes)
                        .frame(height: 80)
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 450, height: 400)
        .onAppear {
            guard let w = workflow else { return }
            name = w.name ?? ""
            triggerType = w.triggerType ?? "manual"
            actionType = w.actionType ?? "notification"
            isActive = w.isActive
            notes = w.notes ?? ""
        }
    }

    private var workflowBehaviorHelp: String {
        switch actionType {
        case "notification":
            return "Envia un aviso local inmediato cuando se dispare el workflow."
        case "email":
            return "Genera una actividad de tipo email para dar seguimiento."
        case "crear_tarea":
            return "Crea una tarea automatica vinculada al registro que dispara el workflow."
        case "cambiar_estado":
            return "Actualiza el estado del lead, ticket o la etapa de la oportunidad."
        case "asignar":
            return "Asigna el ticket o crea una tarea asignada para seguimiento."
        default:
            return "Configura el comportamiento del workflow."
        }
    }

    private var configurationHelp: String {
        switch actionType {
        case "cambiar_estado":
            return "Puedes indicar un valor explicito con status:valor."
        case "asignar":
            return "Puedes indicar responsable con assignee:Nombre."
        default:
            return "La configuracion es opcional y se guarda junto al workflow."
        }
    }

    private func save() {
        let w = workflow ?? CDWorkflow(context: context)
        if workflow == nil {
            w.id = UUID()
            w.createdAt = Date()
            w.executionCount = 0
        }
        w.name = name
        w.triggerType = triggerType
        w.actionType = actionType
        w.isActive = isActive
        w.notes = notes
        w.updatedAt = Date()
        PersistenceController.shared.save()
        dismiss()
    }
}
