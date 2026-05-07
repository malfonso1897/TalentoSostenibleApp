import SwiftUI
import LocalAuthentication

@main
struct TalentoSostenibleApp: App {
    let persistence = PersistenceController.shared
    @StateObject private var notificationManager = NotificationManager.shared
    @StateObject private var appLock = AppLockViewModel()

    var body: some Scene {
        WindowGroup {
            AppLockView {
                ContentView()
                    .environment(\.managedObjectContext, persistence.container.viewContext)
                    .onAppear {
                        notificationManager.requestPermission()
                        scheduleAllReminders()
                    }
            }
            .environmentObject(appLock)
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

private struct AppLockView<Content: View>: View {
    @EnvironmentObject private var appLock: AppLockViewModel
    @ViewBuilder let content: Content

    var body: some View {
        Group {
            if appLock.isUnlocked {
                content
            } else {
                AppLockScreen()
            }
        }
        .task {
            await appLock.authenticateIfNeeded()
        }
    }
}

private struct AppLockScreen: View {
    @EnvironmentObject private var appLock: AppLockViewModel

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.92, green: 0.96, blue: 0.99), Color.white],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 22) {
                Image(systemName: appLock.iconName)
                    .font(.system(size: 52, weight: .medium))
                    .foregroundStyle(.primary)

                VStack(spacing: 8) {
                    Text("Acceso protegido")
                        .font(.system(size: 28, weight: .bold))
                    Text(appLock.subtitle)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 420)
                }

                if let errorMessage = appLock.errorMessage {
                    Text(errorMessage)
                        .font(.callout)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 420)
                }

                HStack(spacing: 12) {
                    Button(appLock.primaryButtonTitle) {
                        Task {
                            await appLock.authenticate(forceRetry: true)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(appLock.isAuthenticating)

                    if appLock.canFallbackToPassword {
                        Button("Usar contrasena del Mac") {
                            Task {
                                await appLock.authenticateWithPasswordFallback()
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(appLock.isAuthenticating)
                    }
                }

                if appLock.isAuthenticating {
                    ProgressView("Verificando acceso...")
                        .progressViewStyle(.linear)
                        .frame(width: 220)
                }
            }
            .padding(36)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .shadow(color: Color.black.opacity(0.08), radius: 24, x: 0, y: 16)
            .padding(32)
        }
    }
}

@MainActor
private final class AppLockViewModel: ObservableObject {
    @Published var isUnlocked = false
    @Published var isAuthenticating = false
    @Published var errorMessage: String?

    private var hasAttemptedAuthentication = false

    var iconName: String {
        switch biometryKind {
        case .touchID:
            return "touchid"
        case .none:
            return "lock.shield"
        }
    }

    var subtitle: String {
        switch biometryKind {
        case .touchID:
            return "Abre Talento Sostenible con tu huella usando Touch ID."
        case .none:
            return "Abre Talento Sostenible usando la autenticacion segura del Mac."
        }
    }

    var primaryButtonTitle: String {
        switch biometryKind {
        case .touchID:
            return "Desbloquear con Touch ID"
        case .none:
            return "Desbloquear"
        }
    }

    var canFallbackToPassword: Bool {
        biometryKind == .touchID
    }

    func authenticateIfNeeded() async {
        guard !hasAttemptedAuthentication else { return }
        hasAttemptedAuthentication = true
        await authenticate(forceRetry: false)
    }

    func authenticate(forceRetry: Bool) async {
        guard !isUnlocked, !isAuthenticating else { return }

        let context = LAContext()
        context.localizedCancelTitle = "Cancelar"
        context.localizedFallbackTitle = "Usar contrasena"

        var error: NSError?
        let canEvaluateBiometrics = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        let canEvaluateOwnerAuth = context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)

        guard canEvaluateBiometrics || canEvaluateOwnerAuth else {
            errorMessage = "Este Mac no permite autenticacion segura en este momento."
            return
        }

        isAuthenticating = true
        errorMessage = nil

        let policy: LAPolicy = canEvaluateBiometrics ? .deviceOwnerAuthenticationWithBiometrics : .deviceOwnerAuthentication
        let reason = canEvaluateBiometrics
            ? "Usa Touch ID para abrir Talento Sostenible."
            : "Autenticate para abrir Talento Sostenible."

        do {
            let success = try await context.evaluatePolicy(policy, localizedReason: reason)
            if success {
                isUnlocked = true
                errorMessage = nil
            }
        } catch {
            if forceRetry || !isCancellation(error) {
                errorMessage = humanReadableMessage(for: error)
            }
        }

        isAuthenticating = false
    }

    func authenticateWithPasswordFallback() async {
        guard !isUnlocked, !isAuthenticating else { return }

        let context = LAContext()
        context.localizedCancelTitle = "Cancelar"

        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            errorMessage = "No se pudo usar la contrasena del Mac para desbloquear la app."
            return
        }

        isAuthenticating = true
        errorMessage = nil

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: "Autenticate para abrir Talento Sostenible."
            )
            if success {
                isUnlocked = true
            }
        } catch {
            errorMessage = humanReadableMessage(for: error)
        }

        isAuthenticating = false
    }

    private var biometryKind: AppBiometryKind {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .none
        }

        switch context.biometryType {
        case .touchID:
            return .touchID
        default:
            return .none
        }
    }

    private func isCancellation(_ error: Error) -> Bool {
        guard let laError = error as? LAError else { return false }
        return laError.code == .userCancel || laError.code == .appCancel || laError.code == .systemCancel
    }

    private func humanReadableMessage(for error: Error) -> String {
        guard let laError = error as? LAError else {
            return "No se pudo validar el acceso. Intentalo de nuevo."
        }

        switch laError.code {
        case .authenticationFailed:
            return "La autenticacion no fue valida. Intentalo de nuevo."
        case .userCancel:
            return "La autenticacion se cancelo."
        case .biometryLockout:
            return "Touch ID esta bloqueado temporalmente. Usa la contrasena del Mac."
        case .biometryNotAvailable:
            return "Touch ID no esta disponible en este Mac."
        case .biometryNotEnrolled:
            return "No hay huellas configuradas en Touch ID para este Mac."
        case .passcodeNotSet:
            return "El Mac necesita una contrasena configurada para usar autenticacion segura."
        default:
            return "No se pudo completar la autenticacion."
        }
    }
}

private enum AppBiometryKind {
    case none
    case touchID
}
