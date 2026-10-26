import Foundation
import CryptoKit
import Security
import SQLite3

public struct ProviderCredential: Sendable {
    public let token: String
    public let accountID: String?
    public let userID: String?
    public let planLabel: String?
    public init(token: String, accountID: String? = nil, userID: String? = nil, planLabel: String? = nil) {
        self.token = token; self.accountID = accountID; self.userID = userID; self.planLabel = planLabel
    }
    public var identity: String {
        if let accountID { return accountID }
        if let userID { return userID }
        return SHA256.hash(data: Data(token.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

public enum CredentialParser {
    private static func object(_ data: Data) throws -> [String: Any] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw ProviderError.disconnected("Credential file is unreadable. Sign in through the provider app.") }
        return json
    }
    private static func nonempty(_ value: Any?) -> String? {
        guard let string = value as? String, !string.isEmpty else { return nil }
        return string
    }
    private static func expiry(_ value: Any?) -> Date? {
        if let n = value as? NSNumber { return Date(timeIntervalSince1970: n.doubleValue > 1e11 ? n.doubleValue / 1000 : n.doubleValue) }
        if let s = value as? String {
            if let n = Double(s) { return Date(timeIntervalSince1970: n > 1e11 ? n / 1000 : n) }
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return formatter.date(from: s) ?? ISO8601DateFormatter().date(from: s)
        }
        return nil
    }
    public static func codex(_ data: Data) throws -> ProviderCredential {
        let json = try object(data)
        guard let tokens = json["tokens"] as? [String: Any], let token = nonempty(tokens["access_token"]) else {
            throw ProviderError.disconnected("Run codex login in Terminal, then refresh.")
        }
        return .init(token: token, accountID: nonempty(tokens["account_id"]))
    }
    public static func claude(_ data: Data, now: Date) throws -> ProviderCredential {
        let json = try object(data)
        guard let oauth = json["claudeAiOauth"] as? [String: Any], let token = nonempty(oauth["accessToken"]) else {
            throw ProviderError.disconnected("Run claude auth login in Terminal, then refresh.")
        }
        if let expires = expiry(oauth["expiresAt"]), expires <= now { throw ProviderError.expired }
        let subscription = nonempty(oauth["subscriptionType"])?.lowercased()
        let tier = nonempty(oauth["rateLimitTier"])?.lowercased()
        let plan: String?
        switch subscription {
        case "max":
            switch tier {
            case "default_claude_max_20x": plan = "Max (20x)"
            case "default_claude_max_5x": plan = "Max (5x)"
            default: plan = "Max"
            }
        case "pro": plan = "Pro"
        default: plan = nil
        }
        return .init(token: token, planLabel: plan)
    }
    public static func cursor(_ token: String, now: Date) throws -> ProviderCredential {
        let parts = token.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3 else { throw ProviderError.disconnected("Sign in to the Cursor app, then refresh.") }
        var base64 = String(parts[1]).replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)
        guard let data = Data(base64Encoded: base64), let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let sub = nonempty(json["sub"]), let userID = sub.split(separator: "|", omittingEmptySubsequences: false).last, !userID.isEmpty else {
            throw ProviderError.disconnected("Sign in to the Cursor app, then refresh.")
        }
        if let expires = expiry(json["exp"]), expires <= now { throw ProviderError.expired }
        return .init(token: token, userID: String(userID))
    }
    public static func grok(_ data: Data, now: Date) throws -> ProviderCredential {
        let json = try object(data)
        let entries = json.filter { $0.key.hasPrefix("https://auth.x.ai::") }.compactMap { _, value -> ProviderCredential? in
            guard let entry = value as? [String: Any], let token = nonempty(entry["key"]), let userID = nonempty(entry["user_id"]) else { return nil }
            if let expires = expiry(entry["expires_at"]), expires <= now { return nil }
            return .init(token: token, userID: userID)
        }
        if entries.count > 1 { throw ProviderError.ambiguousAccount }
        guard let entry = entries.first else { throw ProviderError.disconnected("Run grok login in Terminal, then refresh.") }
        return entry
    }
}

public enum CredentialReader {
    private static var home: URL { FileManager.default.homeDirectoryForCurrentUser }
    private static func read(_ path: URL) throws -> Data {
        guard let data = try? Data(contentsOf: path, options: .mappedIfSafe), data.count <= 1_048_576 else {
            throw ProviderError.disconnected("Sign in through the provider app, then refresh.")
        }
        return data
    }
    public static func load(_ provider: Provider, allowKeychainPrompt: Bool = false) throws -> ProviderCredential {
        let environment = ProcessInfo.processInfo.environment
        switch provider {
        case .codex:
            let root = environment["CODEX_HOME"].map { URL(fileURLWithPath: $0, isDirectory: true) } ?? home.appendingPathComponent(".codex", isDirectory: true)
            return try CredentialParser.codex(read(root.appendingPathComponent("auth.json")))
        case .claude:
            let root = environment["CLAUDE_CONFIG_DIR"].map { URL(fileURLWithPath: $0, isDirectory: true) } ?? home.appendingPathComponent(".claude", isDirectory: true)
            if let data = try? Data(contentsOf: root.appendingPathComponent(".credentials.json"), options: .mappedIfSafe), data.count <= 1_048_576 {
                if let credential = try? CredentialParser.claude(data, now: .now) { return credential }
            }
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: "Claude Code-credentials",
                kSecReturnData as String: true,
                kSecMatchLimit as String: kSecMatchLimitOne,
                kSecUseAuthenticationUI as String: allowKeychainPrompt ? kSecUseAuthenticationUIAllow : kSecUseAuthenticationUIFail
            ]
            var result: CFTypeRef?
            let status = SecItemCopyMatching(query as CFDictionary, &result)
            if status == errSecInteractionNotAllowed { throw ProviderError.keychainPermission }
            guard status == errSecSuccess, let data = result as? Data else {
                throw ProviderError.disconnected("Run claude auth login, or choose Connect to allow Keychain access.")
            }
            return try CredentialParser.claude(data, now: .now)
        case .cursor:
            let path = home.appendingPathComponent("Library/Application Support/Cursor/User/globalStorage/state.vscdb").path
            var db: OpaquePointer?
            guard sqlite3_open_v2(path, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX, nil) == SQLITE_OK, let db else {
                if db != nil { sqlite3_close(db) }
                throw ProviderError.disconnected("Sign in to the Cursor app, then refresh.")
            }
            defer { sqlite3_close(db) }
            sqlite3_busy_timeout(db, 1000)
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, "SELECT value FROM ItemTable WHERE key = ? LIMIT 1", -1, &statement, nil) == SQLITE_OK else {
                throw ProviderError.disconnected("Cursor session is unavailable. Sign in to Cursor, then refresh.")
            }
            defer { sqlite3_finalize(statement) }
            sqlite3_bind_text(statement, 1, "cursorAuth/accessToken", -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            guard sqlite3_step(statement) == SQLITE_ROW, let text = sqlite3_column_text(statement, 0) else {
                throw ProviderError.disconnected("Sign in to the Cursor app, then refresh.")
            }
            let raw = String(cString: text)
            let token: String
            if raw.first == "\"", let decoded = try? JSONSerialization.jsonObject(with: Data(raw.utf8)) as? String { token = decoded }
            else { token = raw }
            return try CredentialParser.cursor(token, now: .now)
        case .grok:
            let root = environment["GROK_HOME"].map { URL(fileURLWithPath: $0, isDirectory: true) } ?? home.appendingPathComponent(".grok", isDirectory: true)
            return try CredentialParser.grok(read(root.appendingPathComponent("auth.json")), now: .now)
        }
    }
}
