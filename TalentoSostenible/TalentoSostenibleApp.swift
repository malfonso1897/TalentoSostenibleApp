import SwiftUI

@main
struct TalentoSostenibleApp: App {
    let persistence = PersistenceController.shared
    @StateObject private var notificationManager = NotificationManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistence.container.viewContext)
                .onAppear {
                    notificationManager.requestPermission()
                    scheduleAllReminders()
                }
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1200, height: 800)
    }

    // Programa recordatorios para todas las actividades pendientes
    private func scheduleAllReminders() {
        let context = persistence.container.viewContext
        let request: NSFetchRequest<CDActivity> = CDActivity.fetchRequest()
        request.predicate = NSPredicate(format: "isCompleted == NO AND dueDate > %@", Date() as NSDate)
        if let activities = try? context.fetch(request) {
            for activity in activities {
                notificationManager.scheduleActivityReminder(activity)
            }
        }

        // Notificar oportunidades proximas a cerrar
        let oppRequest: NSFetchRequest<CDOpportunity> = CDOpportunity.fetchRequest()
        oppRequest.predicate = NSPredicate(
            format: "stage != %@ AND stage != %@ AND expectedCloseDate != nil",
            "closed_won", "closed_lost"
        )
        if let opportunities = try? context.fetch(oppRequest) {
            for opp in opportunities {
                if let closeDate = opp.expectedCloseDate, let id = opp.id {
                    notificationManager.scheduleOpportunityReminder(
                        name: opp.name ?? "",
                        oppId: id,
                        closeDate: closeDate
                    )
                }
            }
        }
    }
}
