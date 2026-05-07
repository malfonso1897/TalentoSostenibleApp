import SwiftUI
import CoreData

struct DashboardView: View {
    @Environment(\.managedObjectContext) private var context
    @Environment(\.colorScheme) private var colorScheme
    var onSelectShortcut: (SidebarItem) -> Void = { _ in }

    @FetchRequest(sortDescriptors: []) private var contacts: FetchedResults<CDContact>
    @FetchRequest(sortDescriptors: []) private var companies: FetchedResults<CDCompany>
    @FetchRequest(sortDescriptors: []) private var leads: FetchedResults<CDLead>
    @FetchRequest(sortDescriptors: []) private var opportunities: FetchedResults<CDOpportunity>
    @FetchRequest(sortDescriptors: []) private var tickets: FetchedResults<CDTicket>
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \CDActivity.dueDate, ascending: true)],
        predicate: NSPredicate(format: "isCompleted == NO")
    ) private var pendingActivities: FetchedResults<CDActivity>

    @StateObject private var intelligence = CRMIntelligence()

    var openOpportunities: [CDOpportunity] {
        opportunities.filter { $0.stage != "closed_won" && $0.stage != "closed_lost" }
    }

    var pipelineValue: Double {
        openOpportunities.reduce(0) { $0 + $1.amount }
    }

    var openTickets: Int {
        tickets.filter { $0.status == "open" || $0.status == "in_progress" }.count
    }

    var todayActivities: [CDActivity] {
        let cal = Foundation.Calendar.current
        return pendingActivities.filter { a in
            guard let d = a.dueDate else { return false }
            return cal.isDateInToday(d)
        }
    }

    var overdueActivities: [CDActivity] {
        pendingActivities.filter { a in
            guard let d = a.dueDate else { return false }
            return d < Date()
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                dashboardHero

                quickAccessSection

                // KPIs
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    KPICard(title: "Contactos", value: "\(contacts.count)", subtitle: "\(companies.count) empresas", color: .blue)
                    KPICard(title: "Leads", value: "\(leads.count)", subtitle: "activos", color: .orange)
                    KPICard(title: "Oportunidades", value: "\(openOpportunities.count)", subtitle: String(format: "%.0f EUR pipeline", pipelineValue), color: .green)
                    KPICard(title: "Tickets", value: "\(openTickets)", subtitle: "abiertos", color: .red)
                    KPICard(title: "Hoy", value: "\(todayActivities.count)", subtitle: "\(overdueActivities.count) vencidas", color: .purple)
                }

                // MARK: - Centro de alertas inteligente
                if !intelligence.alerts.isEmpty {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Centro de alertas")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                Spacer()
                                Text("\(intelligence.alerts.filter { $0.priority == .critical }.count) criticas")
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.red.opacity(0.15))
                                    .foregroundColor(.red)
                                    .cornerRadius(8)
                                Text("\(intelligence.alerts.filter { $0.priority == .high }.count) altas")
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.orange.opacity(0.15))
                                    .foregroundColor(.orange)
                                    .cornerRadius(8)
                            }

                            ForEach(intelligence.alerts.prefix(8)) { alert in
                                HStack(spacing: 10) {
                                    // Indicador de prioridad
                                    Circle()
                                        .fill(alertColor(alert.priority))
                                        .frame(width: 10, height: 10)

                                    // Icono segun tipo
                                    Text(alertIcon(alert.type))
                                        .font(.system(size: 14))
                                        .frame(width: 24)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(alert.title)
                                            .fontWeight(.medium)
                                            .lineLimit(1)
                                        Text(alert.detail)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                    Text(alert.priority.label)
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(alertColor(alert.priority).opacity(0.15))
                                        .foregroundColor(alertColor(alert.priority))
                                        .cornerRadius(6)
                                }
                                .padding(.vertical, 4)
                                if alert.id != intelligence.alerts.prefix(8).last?.id {
                                    Divider()
                                }
                            }

                            if intelligence.alerts.count > 8 {
                                Text("+ \(intelligence.alerts.count - 8) alertas mas")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.top, 4)
                            }
                        }
                    }
                }

                // MARK: - Que hacer hoy
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Que hacer hoy")
                            .font(.headline)
                            .fontWeight(.bold)

                        if todayActivities.isEmpty && overdueActivities.isEmpty {
                            Text("No hay tareas para hoy - Buen momento para revisar leads y oportunidades")
                                .foregroundColor(.secondary)
                                .padding(.vertical, 8)
                        } else {
                            // Actividades vencidas primero
                            ForEach(overdueActivities.prefix(5)) { activity in
                                activityRow(activity, isOverdue: true)
                            }
                            // Actividades de hoy
                            ForEach(todayActivities.prefix(5)) { activity in
                                activityRow(activity, isOverdue: false)
                            }
                        }
                    }
                }

                // MARK: - Pipeline y leads lado a lado
                HStack(alignment: .top, spacing: 16) {
                    // Proximas oportunidades
                    GroupBox("Oportunidades activas") {
                        if openOpportunities.isEmpty {
                            Text("No hay oportunidades activas")
                                .foregroundColor(.secondary)
                                .padding()
                        } else {
                            ForEach(openOpportunities.prefix(5)) { opp in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(opp.name ?? "")
                                            .fontWeight(.medium)
                                        HStack(spacing: 8) {
                                            Text(String(format: "%.0f EUR", opp.amount))
                                                .font(.caption)
                                                .foregroundColor(.green)
                                            if let date = opp.expectedCloseDate {
                                                Text(date, style: .date)
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                    }
                                    Spacer()
                                    StatusBadge(text: opp.stage ?? "", color: stageColor(opp.stage ?? ""))
                                }
                                .padding(.vertical, 4)
                                Divider()
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)

                    // Leads recientes
                    GroupBox("Leads recientes") {
                        if leads.isEmpty {
                            Text("No hay leads")
                                .foregroundColor(.secondary)
                                .padding()
                        } else {
                            ForEach(Array(leads.prefix(5))) { lead in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("\(lead.firstName ?? "") \(lead.lastName ?? "")")
                                            .fontWeight(.medium)
                                        HStack(spacing: 8) {
                                            Text(lead.companyName ?? "")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            Text("Score: \(lead.score)")
                                                .font(.caption)
                                                .foregroundColor(lead.score > 70 ? .green : .secondary)
                                        }
                                    }
                                    Spacer()
                                    StatusBadge(text: lead.status ?? "new", color: leadStatusColor(lead.status ?? "new"))
                                }
                                .padding(.vertical, 4)
                                Divider()
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding()
        }
        .background(dashboardBackground)
        .onAppear {
            intelligence.analyze(context: context)
        }
    }

    // MARK: - Helpers

    private var dashboardHero: some View {
        HStack(alignment: .top, spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Dashboard")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text(todayGreeting())
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.82))
                Text("Centro operativo con accesos rapidos a las areas clave del negocio.")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.76))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            if !intelligence.alerts.isEmpty {
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(intelligence.alerts.count)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(alertsMainColor())
                    Text("alertas activas")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.76))
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(alertsMainColor().opacity(0.35), lineWidth: 1)
                )
            }
        }
        .padding(28)
        .background(
            LinearGradient(
                colors: [Color(red: 0.14, green: 0.11, blue: 0.34), Color(red: 0.33, green: 0.20, blue: 0.67), Color(red: 0.08, green: 0.12, blue: 0.28)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 30, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(.ultraThinMaterial)
                .opacity(0.22)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: Color.purple.opacity(0.20), radius: 26, x: 0, y: 16)
    }

    private var quickAccessSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Accesos directos")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ShortcutCard(
                    title: "Finanzas",
                    subtitle: "Facturacion, cobros y gastos",
                    systemImage: "eurosign.circle.fill",
                    accent: Color(red: 0.12, green: 0.62, blue: 0.48)
                ) {
                    onSelectShortcut(.facturacion)
                }

                ShortcutCard(
                    title: "CRM",
                    subtitle: "Contactos, leads y oportunidades",
                    systemImage: "person.3.fill",
                    accent: Color(red: 0.15, green: 0.48, blue: 0.95)
                ) {
                    onSelectShortcut(.crmHome)
                }

                ShortcutCard(
                    title: "Comunicacion",
                    subtitle: "Correo corporativo y seguimiento",
                    systemImage: "bubble.left.and.bubble.right.fill",
                    accent: Color(red: 0.54, green: 0.25, blue: 0.82)
                ) {
                    onSelectShortcut(.comunicacion)
                }

                ShortcutCard(
                    title: "Agenda",
                    subtitle: "Calendario y proximas acciones",
                    systemImage: "calendar.badge.clock",
                    accent: Color(red: 0.94, green: 0.52, blue: 0.18)
                ) {
                    onSelectShortcut(.agendaHome)
                }
            }
        }
    }

    private var dashboardBackground: some View {
        ZStack {
            LinearGradient(
                colors: colorScheme == .dark
                    ? [Color(red: 0.09, green: 0.10, blue: 0.16), Color(red: 0.07, green: 0.08, blue: 0.12)]
                    : [Color(red: 0.97, green: 0.98, blue: 1.0), Color(red: 0.93, green: 0.95, blue: 1.0)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color.purple.opacity(colorScheme == .dark ? 0.22 : 0.18))
                .frame(width: 340, height: 340)
                .blur(radius: 80)
                .offset(x: 240, y: -180)

            Circle()
                .fill(Color.blue.opacity(colorScheme == .dark ? 0.18 : 0.14))
                .frame(width: 320, height: 320)
                .blur(radius: 90)
                .offset(x: -260, y: -120)
        }
        .ignoresSafeArea()
    }

    private func todayGreeting() -> String {
        let hour = Foundation.Calendar.current.component(.hour, from: Date())
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "EEEE d 'de' MMMM"
        let dateStr = formatter.string(from: Date()).capitalized

        if hour < 12 { return "Buenos dias - \(dateStr)" }
        if hour < 20 { return "Buenas tardes - \(dateStr)" }
        return "Buenas noches - \(dateStr)"
    }

    @ViewBuilder
    private func activityRow(_ activity: CDActivity, isOverdue: Bool) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(isOverdue ? Color.red : Color.orange)
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(activity.subject ?? "")
                    .fontWeight(.medium)
                HStack(spacing: 6) {
                    Text(activity.activityType ?? "")
                        .font(.caption)
                    if let d = activity.dueDate {
                        Text(d, style: .relative)
                            .font(.caption)
                            .foregroundColor(isOverdue ? .red : .secondary)
                    }
                    if let c = activity.contact {
                        Text("- \(c.firstName ?? "") \(c.lastName ?? "")")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
                .foregroundColor(.secondary)
            }
            Spacer()
            if isOverdue {
                Text("Vencida")
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.red.opacity(0.15))
                    .foregroundColor(.red)
                    .cornerRadius(6)
            }
            Button("Completar") {
                activity.isCompleted = true
                activity.updatedAt = Date()
                PersistenceController.shared.save()
                intelligence.analyze(context: context)
            }
            .buttonStyle(.bordered)
            .tint(.green)
            .controlSize(.mini)
        }
        .padding(.vertical, 3)
    }

    private func alertColor(_ priority: CRMIntelligence.CRMAlert.Priority) -> Color {
        switch priority {
        case .critical: return .red
        case .high: return .orange
        case .medium: return .yellow
        case .low: return .gray
        }
    }

    private func alertsMainColor() -> Color {
        if intelligence.alerts.contains(where: { $0.priority == .critical }) { return .red }
        if intelligence.alerts.contains(where: { $0.priority == .high }) { return .orange }
        return .yellow
    }

    private func alertIcon(_ type: CRMIntelligence.CRMAlert.AlertType) -> String {
        switch type {
        case .followUp: return "FU"
        case .overdueActivity: return "AV"
        case .upcomingClose: return "OC"
        case .hotLead: return "LC"
        case .ticketOverdue: return "TK"
        case .noActivity: return "SA"
        case .staleOpportunity: return "OE"
        }
    }

    func leadStatusColor(_ status: String) -> Color {
        switch status {
        case "new": return .blue
        case "contacted": return .orange
        case "qualified": return .green
        case "lost": return .red
        default: return .gray
        }
    }

    func stageColor(_ stage: String) -> Color {
        switch stage {
        case "prospecting": return .blue
        case "qualification": return .orange
        case "proposal": return .purple
        case "negotiation": return .green
        default: return .gray
        }
    }
}

struct KPICard: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let value: String
    let subtitle: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(color)
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(cardBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
    }

    private var cardBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.76)
    }

    private var borderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.14) : Color.black.opacity(0.06)
    }
}

struct ShortcutCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let subtitle: String
    let systemImage: String
    let accent: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: systemImage)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(accent)
                        .padding(12)
                        .background(accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .foregroundColor(.secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(colorScheme == .dark ? .white : .primary)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.72) : .secondary)
                        .multilineTextAlignment(.leading)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 140, alignment: .leading)
            .padding(18)
            .background(cardBackground, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            )
            .shadow(color: accent.opacity(0.15), radius: 16, x: 0, y: 8)
        }
        .buttonStyle(.plain)
    }

    private var cardBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.10) : Color.white.opacity(0.82)
    }

    private var borderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.16) : Color.black.opacity(0.07)
    }
}

struct StatusBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .cornerRadius(8)
    }
}
