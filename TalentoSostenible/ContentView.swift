import SwiftUI

enum SidebarItem: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case comunicacion = "Comunicacion"
    case facturacion = "Finanzas"
    case crmHome = "CRM"
    case agendaHome = "Agenda"
    case portalCliente = "Portal del cliente"
    case tareas = "Tareas"
    case contactos = "Contactos"
    case empresas = "Empresas"
    case leads = "Leads"
    case oportunidades = "Oportunidades"
    case pipeline = "Pipeline"
    case actividades = "Actividades"
    case calendario = "Calendario"
    case campanas = "Campañas"
    case tickets = "Tickets"
    case automatizacion = "Automatizacion"
    case analitica = "Analitica"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dashboard: return "rectangle.grid.2x2"
        case .comunicacion: return "envelope"
        case .facturacion: return "creditcard"
        case .crmHome: return "person.3.sequence.fill"
        case .agendaHome: return "calendar.badge.clock"
        case .portalCliente: return "rectangle.on.rectangle.angled"
        case .tareas: return "checklist"
        case .contactos: return "person.2"
        case .empresas: return "building.2"
        case .leads: return "person.badge.plus"
        case .oportunidades: return "target"
        case .pipeline: return "chart.bar"
        case .actividades: return "bolt.horizontal"
        case .calendario: return "calendar"
        case .campanas: return "megaphone.fill"
        case .tickets: return "lifepreserver"
        case .automatizacion: return "gearshape.2"
        case .analitica: return "chart.xyaxis.line"
        }
    }
}

private struct SidebarGroup: Identifiable {
    let root: SidebarItem
    let children: [SidebarItem]

    var id: SidebarItem { root }
}

private struct HubAction: Identifiable {
    let title: String
    let subtitle: String
    let icon: String
    let item: SidebarItem
    let accent: Color

    var id: SidebarItem { item }
}

struct ContentView: View {
    @State private var selectedItem: SidebarItem? = .dashboard
    @State private var expandedGroups: Set<SidebarItem> = [.crmHome, .agendaHome, .portalCliente]

    private let sidebarGroups: [SidebarGroup] = [
        SidebarGroup(root: .crmHome, children: [.contactos, .empresas, .leads, .oportunidades, .pipeline, .actividades, .campanas, .automatizacion, .analitica]),
        SidebarGroup(root: .agendaHome, children: [.calendario, .tareas]),
        SidebarGroup(root: .portalCliente, children: [.tickets])
    ]

    var body: some View {
        NavigationSplitView {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    sidebarSectionTitle("General")
                    sidebarLeafRow(.dashboard)
                    sidebarLeafRow(.comunicacion)
                    sidebarLeafRow(.facturacion)

                    sidebarSectionTitle("Areas")
                    ForEach(sidebarGroups) { group in
                        sidebarGroupRow(group)
                    }
                }
                .padding(12)
            }
            .background(.regularMaterial)
            .navigationTitle("TALENTO SOSTENIBLE")
            .frame(minWidth: 220)
        } detail: {
            switch selectedItem {
            case .dashboard:
                DashboardView { item in
                    if sidebarGroups.contains(where: { $0.root == item }) {
                        expandedGroups.insert(item)
                    }
                    selectedItem = item
                }
            case .comunicacion:
                CommunicationCenterView()
            case .facturacion:
                FinanceCenterView()
            case .crmHome:
                CRMHubView { item in
                    selectedItem = item
                }
            case .agendaHome:
                AgendaHubView { item in
                    selectedItem = item
                }
            case .portalCliente:
                PortalHubView { item in
                    selectedItem = item
                }
            case .tareas:
                TaskBoardView()
            case .contactos:
                ContactListView()
            case .empresas:
                CompanyListView()
            case .leads:
                LeadListView()
            case .oportunidades:
                OpportunityListView()
            case .pipeline:
                PipelineView()
            case .actividades:
                ActivityListView()
            case .calendario:
                CalendarView()
            case .campanas:
                CampaignListView()
            case .tickets:
                TicketListView()
            case .automatizacion:
                WorkflowListView()
            case .analitica:
                AnalyticsView()
            case .none:
                Text("Selecciona una seccion")
                    .foregroundColor(.secondary)
            }
        }
    }

    private func sidebarSectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(.secondary)
            .padding(.horizontal, 10)
            .padding(.top, 6)
    }

    private func sidebarLeafRow(_ item: SidebarItem, depth: CGFloat = 0) -> some View {
        Button {
            selectedItem = item
        } label: {
            HStack(spacing: 10) {
                Image(systemName: item.icon)
                    .frame(width: 16)
                Text(item.rawValue)
                    .font(.system(size: 13, weight: selectedItem == item ? .semibold : .regular))
                Spacer(minLength: 0)
            }
            .foregroundColor(selectedItem == item ? .white : .primary)
            .padding(.vertical, 8)
            .padding(.leading, 10 + depth)
            .padding(.trailing, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(selectedItem == item ? Color.accentColor : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    private func sidebarGroupRow(_ group: SidebarGroup) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Button {
                    selectedItem = group.root
                    expandedGroups.insert(group.root)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: group.root.icon)
                            .frame(width: 16)
                        Text(group.root.rawValue)
                            .font(.system(size: 13, weight: selectedItem == group.root ? .semibold : .regular))
                        Spacer(minLength: 0)
                    }
                    .foregroundColor(selectedItem == group.root ? .white : .primary)
                    .padding(.vertical, 8)
                    .padding(.leading, 10)
                    .padding(.trailing, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(selectedItem == group.root ? Color.accentColor : Color.clear)
                    )
                }
                .buttonStyle(.plain)

                Button {
                    toggleGroup(group.root)
                } label: {
                    Image(systemName: expandedGroups.contains(group.root) ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.plain)
            }

            if expandedGroups.contains(group.root) {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(group.children) { item in
                        sidebarLeafRow(item, depth: 18)
                    }
                }
            }
        }
    }

    private func toggleGroup(_ item: SidebarItem) {
        if expandedGroups.contains(item) {
            expandedGroups.remove(item)
        } else {
            expandedGroups.insert(item)
        }
    }
}

private struct CRMHubView: View {
    @FetchRequest(sortDescriptors: []) private var contacts: FetchedResults<CDContact>
    @FetchRequest(sortDescriptors: []) private var companies: FetchedResults<CDCompany>
    @FetchRequest(sortDescriptors: []) private var leads: FetchedResults<CDLead>
    @FetchRequest(sortDescriptors: []) private var opportunities: FetchedResults<CDOpportunity>

    let onSelect: (SidebarItem) -> Void

    private var openOpportunities: [CDOpportunity] {
        opportunities.filter { $0.stage != "closed_won" && $0.stage != "closed_lost" }
    }

    private var pipelineValue: Double {
        openOpportunities.reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        SectionHubContainer(
            title: "CRM",
            subtitle: "Relacion comercial, seguimiento y automatizacion.",
            accent: Color(red: 0.16, green: 0.46, blue: 0.93),
            metrics: [
                HubMetric(title: "Contactos", value: "\(contacts.count)", tone: .blue),
                HubMetric(title: "Empresas", value: "\(companies.count)", tone: .indigo),
                HubMetric(title: "Leads", value: "\(leads.count)", tone: .orange),
                HubMetric(title: "Pipeline", value: currency(pipelineValue), tone: .green)
            ],
            actions: [
                HubAction(title: "Contactos", subtitle: "Base relacional y fichas", icon: "person.2.fill", item: .contactos, accent: .blue),
                HubAction(title: "Empresas", subtitle: "Clientes, proveedores y cuentas", icon: "building.2.fill", item: .empresas, accent: .indigo),
                HubAction(title: "Leads", subtitle: "Captacion y cualificacion", icon: "person.badge.plus", item: .leads, accent: .orange),
                HubAction(title: "Oportunidades", subtitle: "Pipeline comercial activo", icon: "target", item: .oportunidades, accent: .green),
                HubAction(title: "Pipeline", subtitle: "Vista de embudo y etapas", icon: "chart.bar.fill", item: .pipeline, accent: .teal),
                HubAction(title: "Actividades", subtitle: "Seguimiento y acciones CRM", icon: "bolt.horizontal.fill", item: .actividades, accent: .purple),
                HubAction(title: "Campañas", subtitle: "Marketing y captacion", icon: "megaphone.fill", item: .campanas, accent: .pink),
                HubAction(title: "Automatizacion", subtitle: "Workflows y reglas", icon: "gearshape.2.fill", item: .automatizacion, accent: .cyan),
                HubAction(title: "Analitica", subtitle: "Metricas y rendimiento", icon: "chart.xyaxis.line", item: .analitica, accent: .mint)
            ],
            onSelect: onSelect
        )
    }
}

private struct AgendaHubView: View {
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \CDActivity.dueDate, ascending: true)],
        predicate: NSPredicate(format: "activityType == %@ AND isCompleted == NO", "task")
    ) private var pendingTasks: FetchedResults<CDActivity>
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \CDActivity.dueDate, ascending: true)],
        predicate: NSPredicate(format: "activityType != %@ AND isCompleted == NO", "task")
    ) private var scheduledActivities: FetchedResults<CDActivity>

    let onSelect: (SidebarItem) -> Void

    private var dueToday: Int {
        let calendar = Calendar.current
        return pendingTasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return calendar.isDateInToday(dueDate)
        }.count
    }

    var body: some View {
        SectionHubContainer(
            title: "Agenda",
            subtitle: "Organiza calendario, tareas y proximas acciones.",
            accent: Color(red: 0.95, green: 0.56, blue: 0.16),
            metrics: [
                HubMetric(title: "Tareas pendientes", value: "\(pendingTasks.count)", tone: .yellow),
                HubMetric(title: "Vencen hoy", value: "\(dueToday)", tone: .orange),
                HubMetric(title: "Actividades", value: "\(scheduledActivities.count)", tone: .blue)
            ],
            actions: [
                HubAction(title: "Calendario", subtitle: "Citas, vencimientos y planificacion", icon: "calendar", item: .calendario, accent: .orange),
                HubAction(title: "Tareas", subtitle: "Tablero de ejecucion interna", icon: "checklist", item: .tareas, accent: .yellow),
                HubAction(title: "Actividades", subtitle: "Seguimiento comercial y operativo", icon: "bolt.horizontal.fill", item: .actividades, accent: .blue)
            ],
            onSelect: onSelect
        )
    }
}

private struct PortalHubView: View {
    @FetchRequest(sortDescriptors: []) private var tickets: FetchedResults<CDTicket>

    let onSelect: (SidebarItem) -> Void

    private var openTickets: Int {
        tickets.filter { ["open", "in_progress"].contains($0.status ?? "") }.count
    }

    private var overdueTickets: Int {
        tickets.filter {
            guard let deadline = $0.slaDeadline else { return false }
            return !["resolved", "closed"].contains($0.status ?? "") && deadline < Date()
        }.count
    }

    var body: some View {
        SectionHubContainer(
            title: "Portal del cliente",
            subtitle: "Incidencias, solicitudes y trazabilidad de servicio.",
            accent: Color(red: 0.40, green: 0.26, blue: 0.78),
            metrics: [
                HubMetric(title: "Tickets activos", value: "\(openTickets)", tone: .purple),
                HubMetric(title: "SLA vencidos", value: "\(overdueTickets)", tone: .red),
                HubMetric(title: "Total tickets", value: "\(tickets.count)", tone: .indigo)
            ],
            actions: [
                HubAction(title: "Tickets", subtitle: "Soporte, SLA y seguimiento", icon: "lifepreserver.fill", item: .tickets, accent: .purple),
                HubAction(title: "Comunicacion", subtitle: "Correo y respuesta al cliente", icon: "envelope.fill", item: .comunicacion, accent: .blue),
                HubAction(title: "Finanzas", subtitle: "Facturas y estado economico", icon: "creditcard.fill", item: .facturacion, accent: .green)
            ],
            onSelect: onSelect
        )
    }
}

private struct HubMetric: Identifiable {
    let title: String
    let value: String
    let tone: Color

    var id: String { title }
}

private struct SectionHubContainer: View {
    let title: String
    let subtitle: String
    let accent: Color
    let metrics: [HubMetric]
    let actions: [HubAction]
    let onSelect: (SidebarItem) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(title)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text(subtitle)
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.82))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(28)
                .background(
                    LinearGradient(
                        colors: [accent.opacity(0.95), accent.opacity(0.72), Color.black.opacity(0.45)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 28, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                )

                if !metrics.isEmpty {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: min(metrics.count, 4)), spacing: 14) {
                        ForEach(metrics) { metric in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(metric.title)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(metric.value)
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(metric.tone)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(Color.white.opacity(0.35), lineWidth: 1)
                            )
                        }
                    }
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ForEach(actions) { action in
                        Button {
                            onSelect(action.item)
                        } label: {
                            VStack(alignment: .leading, spacing: 14) {
                                HStack {
                                    Image(systemName: action.icon)
                                        .font(.system(size: 22, weight: .semibold))
                                        .foregroundColor(action.accent)
                                        .padding(12)
                                        .background(action.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    Spacer()
                                    Image(systemName: "arrow.up.right")
                                        .foregroundColor(.secondary)
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(action.title)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    Text(action.subtitle)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.leading)
                                }
                            }
                            .frame(maxWidth: .infinity, minHeight: 150, alignment: .leading)
                            .padding(18)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .stroke(Color.white.opacity(0.45), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding()
        }
    }
}

private func currency(_ value: Double) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.currencyCode = "EUR"
    formatter.locale = Locale(identifier: "es_ES")
    return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f EUR", value)
}

private struct SectionHubView: View {
    let title: String
    let subtitle: String
    let accent: Color
    let actions: [HubAction]
    let onSelect: (SidebarItem) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(title)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text(subtitle)
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.82))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(28)
                .background(
                    LinearGradient(
                        colors: [accent.opacity(0.95), accent.opacity(0.72), Color.black.opacity(0.45)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 28, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                )

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ForEach(actions) { action in
                        Button {
                            onSelect(action.item)
                        } label: {
                            VStack(alignment: .leading, spacing: 14) {
                                HStack {
                                    Image(systemName: action.icon)
                                        .font(.system(size: 22, weight: .semibold))
                                        .foregroundColor(action.accent)
                                        .padding(12)
                                        .background(action.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    Spacer()
                                    Image(systemName: "arrow.up.right")
                                        .foregroundColor(.secondary)
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(action.title)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    Text(action.subtitle)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.leading)
                                }
                            }
                            .frame(maxWidth: .infinity, minHeight: 150, alignment: .leading)
                            .padding(18)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .stroke(Color.white.opacity(0.45), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding()
        }
    }
}
