import Foundation

/// Llama al Marketing Hub (`npm run dev`) o a tu dominio en producción: `POST /api/email/send`
enum EmailAPIClient {
    static var baseURL: String {
        let v = ProcessInfo.processInfo.environment["MARKETING_HUB_URL"] ?? "http://localhost:3000"
        return v.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    static var apiSecret: String {
        ProcessInfo.processInfo.environment["EMAIL_API_SECRET"] ?? ""
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
                userInfo: [NSLocalizedDescriptionKey: "Configura en Xcode → Scheme → Run → Arguments → Environment Variables: MARKETING_HUB_URL (ej. http://localhost:3000) y EMAIL_API_SECRET (mismo valor que en .env.local del hub)."]
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
