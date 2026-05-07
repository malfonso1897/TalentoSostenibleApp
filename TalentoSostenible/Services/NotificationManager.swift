import Foundation
import UserNotifications
import CoreData

class NotificationManager: ObservableObject {
    static let shared = NotificationManager()

    @Published var authorized = false

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async {
                self.authorized = granted
            }
        }
    }

    // Programa notificacion para una actividad pendiente
    func scheduleActivityReminder(_ activity: CDActivity) {
        guard let dueDate = activity.dueDate, let id = activity.id else { return }

        let content = UNMutableNotificationContent()
        content.title = "Actividad pendiente"
        content.body = activity.subject ?? "Tienes una actividad pendiente"
        content.sound = .default
        content.categoryIdentifier = "ACTIVITY_REMINDER"

        // Notificar 15 minutos antes
        let triggerDate = dueDate.addingTimeInterval(-15 * 60)
        guard triggerDate > Date() else { return }

        let components = Foundation.Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: triggerDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: "activity-\(id.uuidString)", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    // Notificacion de seguimiento: contacto sin interaccion en X dias
    func scheduleFollowUpReminder(contactName: String, contactId: UUID, daysSinceContact: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Seguimiento necesario"
        content.body = "\(contactName) - Sin contacto en \(daysSinceContact) dias"
        content.sound = .default
        content.categoryIdentifier = "FOLLOWUP_REMINDER"

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "followup-\(contactId.uuidString)", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    // Notificacion de oportunidad proxima a cerrar
    func scheduleOpportunityReminder(name: String, oppId: UUID, closeDate: Date) {
        let content = UNMutableNotificationContent()
        content.title = "Oportunidad por cerrar"
        content.body = "\(name) - Fecha de cierre proxima"
        content.sound = .default
        content.categoryIdentifier = "OPPORTUNITY_REMINDER"

        let triggerDate = closeDate.addingTimeInterval(-24 * 60 * 60)
        guard triggerDate > Date() else { return }

        let components = Foundation.Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: triggerDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: "opp-\(oppId.uuidString)", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    func sendWorkflowNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = "WORKFLOW_NOTIFICATION"

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "workflow-\(UUID().uuidString)", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    // Limpia todas las notificaciones
    func clearAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
