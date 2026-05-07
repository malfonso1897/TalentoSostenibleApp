import SwiftUI
import CoreData

struct AnalyticsView: View {
    @FetchRequest(sortDescriptors: []) private var contacts: FetchedResults<CDContact>
    @FetchRequest(sortDescriptors: []) private var companies: FetchedResults<CDCompany>
    @FetchRequest(sortDescriptors: []) private var leads: FetchedResults<CDLead>
    @FetchRequest(sortDescriptors: []) private var opportunities: FetchedResults<CDOpportunity>
    @FetchRequest(sortDescriptors: []) private var activities: FetchedResults<CDActivity>
    @FetchRequest(sortDescriptors: []) private var tickets: FetchedResults<CDTicket>
    @FetchRequest(sortDescriptors: []) private var campaigns: FetchedResults<CDCampaign>

    var wonOpps: [CDOpportunity] {
        opportunities.filter { $0.stage == "closed_won" }
    }
    var lostOpps: [CDOpportunity] {
        opportunities.filter { $0.stage == "closed_lost" }
    }
    var openOpps: [CDOpportunity] {
        opportunities.filter { $0.stage != "closed_won" && $0.stage != "closed_lost" }
    }
    var totalWonValue: Double {
        wonOpps.reduce(0) { $0 + $1.amount }
    }
    var totalPipelineValue: Double {
        openOpps.reduce(0) { $0 + $1.amount }
    }
    var completedActivities: Int {
        activities.filter { $0.isCompleted }.count
    }
    var pendingActivities: Int {
        activities.filter { !$0.isCompleted }.count
    }
    var convertedLeads: Int {
        leads.filter { $0.isConverted }.count
    }
    var conversionRate: Double {
        guard !leads.isEmpty else { return 0 }
        return Double(convertedLeads) / Double(leads.count) * 100
    }
    var winRate: Double {
        let closed = wonOpps.count + lostOpps.count
        guard closed > 0 else { return 0 }
        return Double(wonOpps.count) / Double(closed) * 100
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Analitica")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                // Resumen general
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    KPICard(title: "Total contactos", value: "\(contacts.count)", subtitle: "\(companies.count) empresas", color: .blue)
                    KPICard(title: "Total leads", value: "\(leads.count)", subtitle: "\(convertedLeads) convertidos", color: .orange)
                    KPICard(title: "Oportunidades", value: "\(opportunities.count)", subtitle: "\(wonOpps.count) ganadas", color: .green)
                    KPICard(title: "Tickets", value: "\(tickets.count)", subtitle: "\(tickets.filter { $0.status == "open" }.count) abiertos", color: .red)
                }

                // Ventas
                GroupBox("Ventas") {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        StatCard(title: "Valor ganado", value: String(format: "%.0f EUR", totalWonValue))
                        StatCard(title: "Pipeline activo", value: String(format: "%.0f EUR", totalPipelineValue))
                        StatCard(title: "Tasa de cierre", value: String(format: "%.1f%%", winRate))
                    }
                }

                // Leads
                GroupBox("Leads") {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        StatCard(title: "Total leads", value: "\(leads.count)")
                        StatCard(title: "Convertidos", value: "\(convertedLeads)")
                        StatCard(title: "Tasa conversion", value: String(format: "%.1f%%", conversionRate))
                    }
                }

                // Actividades
                GroupBox("Actividades") {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        StatCard(title: "Total", value: "\(activities.count)")
                        StatCard(title: "Completadas", value: "\(completedActivities)")
                        StatCard(title: "Pendientes", value: "\(pendingActivities)")
                    }
                }

                // Campa\u{00f1}as
                GroupBox("Campa\u{00f1}as") {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        StatCard(title: "Total", value: "\(campaigns.count)")
                        StatCard(title: "Activas", value: "\(campaigns.filter { $0.status == "active" }.count)")
                        StatCard(title: "Presupuesto total", value: String(format: "%.0f EUR", campaigns.reduce(0) { $0 + $1.budget }))
                    }
                }

                // Oportunidades por etapa
                GroupBox("Oportunidades por etapa") {
                    let stages = ["prospecting", "qualification", "proposal", "negotiation", "closed_won", "closed_lost"]
                    let labels = ["Prospeccion", "Cualificacion", "Propuesta", "Negociacion", "Ganada", "Perdida"]
                    ForEach(0..<stages.count, id: \.self) { i in
                        let count = opportunities.filter { $0.stage == stages[i] }.count
                        let value = opportunities.filter { $0.stage == stages[i] }.reduce(0.0) { $0 + $1.amount }
                        HStack {
                            Text(labels[i])
                                .frame(width: 120, alignment: .leading)
                            ProgressView(value: opportunities.isEmpty ? 0 : Double(count) / Double(opportunities.count))
                                .tint(stageColor(stages[i]))
                            Text("\(count)")
                                .frame(width: 30)
                            Text(String(format: "%.0f EUR", value))
                                .frame(width: 100, alignment: .trailing)
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                }
            }
            .padding()
        }
    }

    func stageColor(_ s: String) -> Color {
        switch s {
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

struct StatCard: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }
}
