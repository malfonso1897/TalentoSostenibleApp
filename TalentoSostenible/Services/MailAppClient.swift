import Foundation
import AppKit

struct MailAccountOption: Identifiable, Hashable, Sendable {
    let name: String
    let address: String

    var id: String { name + "|" + address }
    var displayName: String { address.isEmpty ? name : "\(name) (\(address))" }
}

struct MailMessageSummary: Identifiable, Hashable, Sendable {
    let messageID: Int
    let subject: String
    let sender: String
    let receivedAt: String
    let isRead: Bool

    var id: String { String(messageID) }
}

enum MailAppClient {
    static func fetchAccounts() throws -> [MailAccountOption] {
        let output = try run(script: """
        tell application \"Mail\"
            launch
            set fieldSep to ASCII character 31
            set recordSep to ASCII character 30
            set outputText to \"\"
            repeat with acc in every account
                set accName to name of acc as string
                set accAddresses to email addresses of acc
                set primaryAddress to \"\"
                if (count of accAddresses) > 0 then
                    set primaryAddress to item 1 of accAddresses as string
                end if
                set outputText to outputText & accName & fieldSep & primaryAddress & recordSep
            end repeat
            return outputText
        end tell
        """)
        return parseRecords(output).compactMap { fields in
            guard fields.count >= 2 else { return nil }
            return MailAccountOption(name: fields[0], address: fields[1])
        }
    }

    static func fetchMessages(accountName: String, limit: Int = 40) throws -> [MailMessageSummary] {
        let escapedName = escape(accountName)
        let output = try run(script: """
        set maxCount to \(limit)
        tell application \"Mail\"
            launch
            set fieldSep to ASCII character 31
            set recordSep to ASCII character 30
            set outputText to \"\"
            set targetAccount to first account whose name is \"\(escapedName)\"
            set msgList to messages of inbox of targetAccount
            set totalCount to count of msgList
            if totalCount > maxCount then
                set totalCount to maxCount
            end if
            repeat with idx from 1 to totalCount
                set msg to item idx of msgList
                set outputText to outputText & (id of msg as string) & fieldSep & (subject of msg as string) & fieldSep & (sender of msg as string) & fieldSep & ((date received of msg) as string) & fieldSep & ((read status of msg) as string) & recordSep
            end repeat
            return outputText
        end tell
        """)
        return parseRecords(output).compactMap { fields in
            guard fields.count >= 5, let messageID = Int(fields[0]) else { return nil }
            return MailMessageSummary(
                messageID: messageID,
                subject: fields[1].isEmpty ? "(Sin asunto)" : fields[1],
                sender: fields[2],
                receivedAt: fields[3],
                isRead: fields[4].lowercased() == "true"
            )
        }
    }

    static func fetchMessageBody(accountName: String, messageID: Int) throws -> String {
        let escapedName = escape(accountName)
        return try run(script: """
        tell application \"Mail\"
            launch
            set targetAccount to first account whose name is \"\(escapedName)\"
            set targetMessage to first message of inbox of targetAccount whose id is \(messageID)
            return content of targetMessage as string
        end tell
        """)
    }

    static func reply(accountName: String, messageID: Int) throws {
        let escapedName = escape(accountName)
        _ = try run(script: """
        tell application \"Mail\"
            launch
            set targetAccount to first account whose name is \"\(escapedName)\"
            set targetMessage to first message of inbox of targetAccount whose id is \(messageID)
            activate
            reply targetMessage opening window true
        end tell
        """)
    }

    static func compose(accountName: String, to: String, subject: String, body: String) throws {
        let escapedName = escape(accountName)
        let escapedTo = escape(to)
        let escapedSubject = escape(subject)
        let escapedBody = escape(body)
        _ = try run(script: """
        tell application \"Mail\"
            launch
            set targetAccount to first account whose name is \"\(escapedName)\"
            set senderAddress to \"\"
            if (count of (email addresses of targetAccount)) > 0 then
                set senderAddress to item 1 of (email addresses of targetAccount) as string
            end if
            set newMessage to make new outgoing message with properties {visible:true, subject:\"\(escapedSubject)\", content:\"\(escapedBody)\"}
            tell newMessage
                if senderAddress is not \"\" then
                    set sender to senderAddress
                end if
                if \"\(escapedTo)\" is not \"\" then
                    make new to recipient at end of to recipients with properties {address:\"\(escapedTo)\"}
                end if
            end tell
            activate
        end tell
        """)
    }

    private static func run(script: String) throws -> String {
        guard let appleScript = NSAppleScript(source: script) else {
            throw NSError(domain: "MailAppClient", code: 1, userInfo: [NSLocalizedDescriptionKey: "No se pudo preparar el script de Mail."])
        }
        var error: NSDictionary?
        let descriptor = appleScript.executeAndReturnError(&error)
        if let error {
            let message = error[NSAppleScript.errorMessage] as? String ?? "No se pudo ejecutar Mail.app."
            throw NSError(domain: "MailAppClient", code: 2, userInfo: [NSLocalizedDescriptionKey: message])
        }
        return descriptor.stringValue ?? ""
    }

    private static func parseRecords(_ text: String) -> [[String]] {
        text
            .split(separator: Character(UnicodeScalar(30)))
            .map { record in
                record.split(separator: Character(UnicodeScalar(31)), omittingEmptySubsequences: false).map(String.init)
            }
    }

    private static func escape(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
    }
}