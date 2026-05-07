import SwiftUI

/// Correo corporativo del dominio (envío vía API del Marketing Hub).
struct CorporateEmailView: View {
    @State private var toField: String = ""
    @State private var subject: String = ""
    @State private var bodyText: String = ""
    @State private var sending = false
    @State private var alertTitle: String = ""
    @State private var alertMessage: String = ""
    @State private var showAlert = false

    var body: some View {
        Form {
            Section {
                TextField("Para (correos separados por coma)", text: $toField)
                    .textContentType(.emailAddress)
                TextField("Asunto", text: $subject)
            } header: {
                Text("Destino")
            }

            Section {
                TextEditor(text: $bodyText)
                    .frame(minHeight: 220)
            } header: {
                Text("Mensaje")
            }

            Section {
                Button {
                    Task { await send() }
                } label: {
                    if sending {
                        ProgressView().controlSize(.small)
                    } else {
                        Label("Enviar correo", systemImage: "paperplane.fill")
                    }
                }
                .disabled(sending || toField.trimmingCharacters(in: .whitespaces).isEmpty || subject.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Correo")
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }

    private func send() async {
        let parts = toField.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        guard !parts.isEmpty else {
            alertTitle = "Faltan destinatarios"
            alertMessage = "Indica al menos un correo."
            showAlert = true
            return
        }
        sending = true
        defer { sending = false }
        do {
            try await EmailAPIClient.send(
                to: parts,
                subject: subject,
                text: bodyText,
                source: "crm"
            )
            alertTitle = "Enviado"
            alertMessage = "El correo se ha enviado."
            showAlert = true
            bodyText = ""
        } catch {
            alertTitle = "Error"
            alertMessage = error.localizedDescription
            showAlert = true
        }
    }
}
