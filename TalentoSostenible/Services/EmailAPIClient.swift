import Foundation

/// Llama al Marketing Hub (`npm run dev`) o a tu dominio en producción: `POST /api/email/send`
enum EmailAPIClient {
    static let baseURLDefaultsKey = "communication.apiBaseURL"
    static let apiSecretDefaultsKey = "communication.apiSecret"

    static var baseURL: String {
        let configuredValue = UserDefaults.standard.string(forKey: baseURLDefaultsKey)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let v = (configuredValue?.isEmpty == false ? configuredValue : nil) ?? ProcessInfo.processInfo.environment["MARKETING_HUB_URL"] ?? "http://localhost:3000"
        return v.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    static var apiSecret: String {
        let configuredValue = UserDefaults.standard.string(forKey: apiSecretDefaultsKey)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (configuredValue?.isEmpty == false ? configuredValue : nil) ?? ProcessInfo.processInfo.environment["EMAIL_API_SECRET"] ?? ""
    }

    static func send(
        to: [String],
        subject: String,
        text: String,
        source: String,
        attachmentBase64: String? = nil,
        attachmentName: String? = nil
    ) async throws {
        guard !apiSecret.isEmpty else {
            throw NSError(
                domain: "EmailAPI",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Configura el servicio de envio en Comunicacion → Configuracion con la URL del hub y el API secret. En desarrollo tambien puedes usar MARKETING_HUB_URL y EMAIL_API_SECRET en Xcode."]
            )
        }
        guard let url = URL(string: baseURL + "/api/email/send") else {
            throw URLError(.badURL)
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(apiSecret, forHTTPHeaderField: "x-email-api-secret")
        var body: [String: Any] = [
            "to": to,
            "subject": subject,
            "text": text,
            "source": source,
        ]
        if let b64 = attachmentBase64, let name = attachmentName {
            body["attachmentBase64"] = b64
            body["attachmentName"] = name
        }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        if http.statusCode >= 400 {
            let msg = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            throw NSError(domain: "EmailAPI", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: msg])
        }
    }
}
