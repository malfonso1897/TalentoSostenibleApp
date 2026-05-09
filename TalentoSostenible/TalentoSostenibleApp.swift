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
    @Environment(\.scenePhase) private var scenePhase
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
        .onChange(of: scenePhase) { newPhase in
            switch newPhase {
            case .active:
                Task {
                    await appLock.authenticateIfNeeded()
                }
            case .inactive, .background:
                appLock.lock()
            @unknown default:
                appLock.lock()
            }
        }
    }
}

private struct AppLockScreen: View {
    @EnvironmentObject private var appLock: AppLockViewModel
    @AppStorage("communication.corporateEmail") private var corporateEmail = "alfonsomarcos@talentosostenibleconsulting.es"

    private var currentDateText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateStyle = .full
        return formatter.string(from: Date())
    }

    private var accessEmail: String {
        let trimmed = corporateEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "alfonsomarcos@talentosostenibleconsulting.es" : trimmed
    }

    var body: some View {
        ZStack {
            lockBackground
            .ignoresSafeArea()

            HStack(spacing: 36) {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 14) {
                        Image(nsImage: NSApplication.shared.applicationIconImage)
                            .resizable()
                            .frame(width: 64, height: 64)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .shadow(color: Color.black.opacity(0.12), radius: 16, x: 0, y: 10)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Talento Sostenible")
                                .font(.system(size: 30, weight: .bold, design: .rounded))
                            Text("CRM, finanzas y operacion empresarial")
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Entrada segura")
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Tu espacio de trabajo se protege con Touch ID cada vez que abres la app o vuelves a ella.")
                            .font(.title3)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    HStack(spacing: 14) {
                        accessInfoCard(title: "Cuenta activa", value: accessEmail, systemImage: "envelope.badge")
                        accessInfoCard(title: "Hoy", value: currentDateText.capitalized, systemImage: "calendar")
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Label("Desbloqueo obligatorio con huella", systemImage: "checkmark.shield")
                        Label("Rebloqueo automatico al salir de la app", systemImage: "lock.rotation")
                        Label("Acceso local y protegido en este Mac", systemImage: "desktopcomputer")
                    }
                    .font(.headline)
                    .foregroundColor(Color.primary.opacity(0.86))
                }
                .frame(maxWidth: 520, alignment: .leading)

                VStack(spacing: 22) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.85))
                            .frame(width: 124, height: 124)
                        Circle()
                            .stroke(Color.white.opacity(0.65), lineWidth: 1)
                            .frame(width: 142, height: 142)
                        Image(systemName: appLock.iconName)
                            .font(.system(size: 54, weight: .medium))
                            .foregroundStyle(Color(red: 0.08, green: 0.36, blue: 0.32))
                    }

                    VStack(spacing: 8) {
                        Text("Acceso protegido")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                        Text(appLock.subtitle)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 360)
                    }

                    if let errorMessage = appLock.errorMessage {
                        Text(errorMessage)
                            .font(.callout)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 360)
                    }

                    Button(appLock.primaryButtonTitle) {
                        Task {
                            await appLock.authenticate(forceRetry: true)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(appLock.isAuthenticating)

                    if appLock.isAuthenticating {
                        ProgressView("Verificando acceso...")
                            .progressViewStyle(.linear)
                            .frame(width: 240)
                    }

                    Text("Proteccion local sobre el dispositivo actual")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(width: 420)
                .padding(34)
                .background(Color.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 32, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .stroke(Color.white.opacity(0.7), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.10), radius: 26, x: 0, y: 18)
            }
            .padding(44)
        }
    }

    private var lockBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.93, green: 0.96, blue: 0.98),
                    Color(red: 0.86, green: 0.92, blue: 0.91),
                    Color.white
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color(red: 0.16, green: 0.55, blue: 0.45).opacity(0.14))
                .frame(width: 460, height: 460)
                .offset(x: -360, y: -240)

            Circle()
                .fill(Color(red: 0.10, green: 0.34, blue: 0.55).opacity(0.10))
                .frame(width: 360, height: 360)
                .offset(x: 420, y: -200)

            RoundedRectangle(cornerRadius: 80, style: .continuous)
                .fill(Color.white.opacity(0.34))
                .frame(width: 540, height: 540)
                .rotationEffect(.degrees(18))
                .offset(x: 360, y: 260)
        }
    }

    private func accessInfoCard(title: String, value: String, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemImage)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color.white.opacity(0.60), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.7), lineWidth: 1)
        )
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
            return "Talento Sostenible requiere Touch ID en este Mac para poder abrirse."
        }
    }

    var primaryButtonTitle: String {
        switch biometryKind {
        case .touchID:
            return "Desbloquear con Touch ID"
        case .none:
            return "Touch ID no disponible"
        }
    }

    func authenticateIfNeeded() async {
        guard !hasAttemptedAuthentication else { return }
        hasAttemptedAuthentication = true
        await authenticate(forceRetry: false)
    }

    func lock() {
        isUnlocked = false
        isAuthenticating = false
        hasAttemptedAuthentication = false
    }

    func authenticate(forceRetry: Bool) async {
        guard !isUnlocked, !isAuthenticating else { return }

        let context = LAContext()
        context.localizedCancelTitle = "Cancelar"
        context.localizedFallbackTitle = ""

        var error: NSError?
        let canEvaluateBiometrics = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)

        guard canEvaluateBiometrics, biometryKind == .touchID else {
            errorMessage = touchIDUnavailableMessage(error)
            return
        }

        isAuthenticating = true
        errorMessage = nil

        let policy: LAPolicy = .deviceOwnerAuthenticationWithBiometrics
        let reason = "Usa Touch ID para abrir Talento Sostenible."

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
            return "La autenticacion con Touch ID se cancelo."
        case .biometryLockout:
            return "Touch ID esta bloqueado temporalmente en este Mac."
        case .biometryNotAvailable:
            return "Touch ID no esta disponible en este Mac."
        case .biometryNotEnrolled:
            return "No hay huellas configuradas en Touch ID para este Mac."
        case .passcodeNotSet:
            return "El Mac necesita una contrasena configurada para habilitar Touch ID."
        default:
            return "No se pudo completar la autenticacion."
        }
    }

    private func touchIDUnavailableMessage(_ error: NSError?) -> String {
        if let error {
            return humanReadableMessage(for: error)
        }
        return "Touch ID es obligatorio para abrir esta app y no esta disponible ahora mismo."
    }
}

private enum AppBiometryKind {
    case none
    case touchID
}
