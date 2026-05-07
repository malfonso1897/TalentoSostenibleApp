import Foundation
import CoreData

// Motor inteligente del CRM: analiza datos y genera alertas/sugerencias
class CRMIntelligence: ObservableObject {

    @Published var alerts: [CRMAlert] = []

    struct CRMAlert: Identifiable {
        let id = UUID()
        let type: AlertType
        let title: String
        let detail: String
        let priority: Priority
        let date: Date

        enum AlertType {
            case followUp        // Contacto sin seguimiento
            case overdueActivity // Actividad vencida
            case upcomingClose   // Oportunidad proxima al cierre
            case hotLead         // Lead con puntuacion alta sin contactar
            case ticketOverdue   // Ticket abierto mucho tiempo
            case noActivity      // Contacto sin actividades programadas
            case staleOpportunity // Oportunidad estancada
        }

        enum Priority: Int, Comparable {
            case critical = 0
            case high = 1
            case medium = 2
            case low = 3

            static func < (lhs: Priority, rhs: Priority) -> Bool {
                lhs.rawValue < rhs.rawValue
            }

            var label: String {
                switch self {
                case .critical: return "Critica"
                case .high: return "Alta"
                case .medium: return "Media"
                case .low: return "Baja"
                }
            }
        }
    }

    func analyze(context: NSManagedObjectContext) {
        var newAlerts: [CRMAlert] = []
        let now = Date()
        let cal = Foundation.Calendar.current

        // 1. Actividades vencidas (fecha pasada, no completadas)
        let activityRequest: NSFetchRequest<CDActivity> = CDActivity.fetchRequest()
        activityRequest.predicate = NSPredicate(format: "isCompleted == NO AND dueDate < %@", now as NSDate)
        if let overdue = try? context.fetch(activityRequest) {
            for a in overdue {
                let days = cal.dateComponents([.day], from: a.dueDate ?? now, to: now).day ?? 0
                newAlerts.append(CRMAlert(
                    type: .overdueActivity,
                    title: "Actividad vencida: \(a.subject ?? "")",
                    detail: "Vencida hace \(days) dia\(days == 1 ? "" : "s")",
                    priority: days > 3 ? .critical : .high,
                    date: a.dueDate ?? now
                ))
            }
        }

        // 2. Contactos sin actividad reciente (mas de 30 dias)
        let contactRequest: NSFetchRequest<CDContact> = CDContact.fetchRequest()
        contactRequest.predicate = NSPredicate(format: "status == %@", "active")
        if let contacts = try? context.fetch(contactRequest) {
            for contact in contacts {
                let lastActivity = (contact.activities as? Set<CDActivity>)?
                    .compactMap { $0.dueDate }
                    .max()

                let referenceDate = lastActivity ?? contact.createdAt ?? now
                let daysSince = cal.dateComponents([.day], from: referenceDate, to: now).day ?? 0

                if daysSince > 30 {
                    let name = "\(contact.firstName ?? "") \(contact.lastName ?? "")"
                    newAlerts.append(CRMAlert(
                        type: .followUp,
                        title: "Seguimiento: \(name)",
                        detail: "Sin contacto en \(daysSince) dias",
                        priority: daysSince > 60 ? .high : .medium,
                        date: referenceDate
                    ))
                }
            }
        }

        // 3. Oportunidades proximas al cierre (menos de 7 dias)
        let oppRequest: NSFetchRequest<CDOpportunity> = CDOpportunity.fetchRequest()
        oppRequest.predicate = NSPredicate(
            format: "stage != %@ AND stage != %@ AND expectedCloseDate != nil",
            "closed_won", "closed_lost"
        )
        if let opportunities = try? context.fetch(oppRequest) {
            for opp in opportunities {
                guard let closeDate = opp.expectedCloseDate else { continue }
                let daysUntil = cal.dateComponents([.day], from: now, to: closeDate).day ?? 0

                if daysUntil < 0 {
                    newAlerts.append(CRMAlert(
                        type: .upcomingClose,
                        title: "Oportunidad vencida: \(opp.name ?? "")",
                        detail: "Fecha de cierre fue hace \(abs(daysUntil)) dias - \(String(format: "%.0f EUR", opp.amount))",
                        priority: .critical,
                        date: closeDate
                    ))
                } else if daysUntil <= 7 {
                    newAlerts.append(CRMAlert(
                        type: .upcomingClose,
                        title: "Oportunidad por cerrar: \(opp.name ?? "")",
                        detail: "Cierra en \(daysUntil) dia\(daysUntil == 1 ? "" : "s") - \(String(format: "%.0f EUR", opp.amount))",
                        priority: daysUntil <= 2 ? .high : .medium,
                        date: closeDate
                    ))
                }

                // Oportunidad estancada (no actualizada en 14+ dias)
                if let updated = opp.updatedAt {
                    let daysSinceUpdate = cal.dateComponents([.day], from: updated, to: now).day ?? 0
                    if daysSinceUpdate > 14 {
                        newAlerts.append(CRMAlert(
                            type: .staleOpportunity,
                            title: "Oportunidad estancada: \(opp.name ?? "")",
                            detail: "Sin movimiento en \(daysSinceUpdate) dias - Etapa: \(opp.stage ?? "")",
                            priority: .medium,
                            date: updated
                        ))
                    }
                }
            }
        }

        // 4. Leads calientes sin contactar (score > 70 y estado "new")
        let leadRequest: NSFetchRequest<CDLead> = CDLead.fetchRequest()
        leadRequest.predicate = NSPredicate(format: "score > 70 AND status == %@ AND isConverted == NO", "new")
        if let hotLeads = try? context.fetch(leadRequest) {
            for lead in hotLeads {
                let name = "\(lead.firstName ?? "") \(lead.lastName ?? "")"
                let daysSince = cal.dateComponents([.day], from: lead.createdAt ?? now, to: now).day ?? 0
                newAlerts.append(CRMAlert(
                    type: .hotLead,
                    title: "Lead caliente: \(name)",
                    detail: "Score \(lead.score) - Sin contactar en \(daysSince) dias",
                    priority: daysSince > 3 ? .critical : .high,
                    date: lead.createdAt ?? now
                ))
            }
        }

        // 5. Tickets abiertos mucho tiempo (mas de 5 dias)
        let ticketRequest: NSFetchRequest<CDTicket> = CDTicket.fetchRequest()
        ticketRequest.predicate = NSPredicate(format: "status == %@ OR status == %@", "open", "in_progress")
        if let tickets = try? context.fetch(ticketRequest) {
            for ticket in tickets {
                let daysSince = cal.dateComponents([.day], from: ticket.createdAt ?? now, to: now).day ?? 0
                if daysSince > 5 {
                    newAlerts.append(CRMAlert(
                        type: .ticketOverdue,
                        title: "Ticket pendiente: \(ticket.subject ?? "")",
                        detail: "Abierto hace \(daysSince) dias - Prioridad: \(ticket.priority ?? "medium")",
                        priority: (ticket.priority == "urgent" || ticket.priority == "high") ? .high : .medium,
                        date: ticket.createdAt ?? now
                    ))
                }
            }
        }

        // Ordenar por prioridad
        DispatchQueue.main.async {
            self.alerts = newAlerts.sorted { $0.priority < $1.priority }
        }
    }

    // Cuantas acciones necesitan atencion hoy
    func todayActionCount(context: NSManagedObjectContext) -> Int {
        let now = Date()
        let cal = Foundation.Calendar.current
        let startOfDay = cal.startOfDay(for: now)
        guard let endOfDay = cal.date(byAdding: .day, value: 1, to: startOfDay) else { return 0 }

        let request: NSFetchRequest<CDActivity> = CDActivity.fetchRequest()
        request.predicate = NSPredicate(
            format: "isCompleted == NO AND dueDate >= %@ AND dueDate < %@",
            startOfDay as NSDate, endOfDay as NSDate
        )
        return (try? context.count(for: request)) ?? 0
    }
}
