import Foundation

public enum Provider: String, CaseIterable, Sendable, Identifiable {
    case codex, claude, cursor, grok
    public var id: String { rawValue }
    public var displayName: String { rawValue.capitalized }
    public var dashboardURL: URL {
        switch self {
        case .codex: URL(string: "https://chatgpt.com/#settings/usage")!
        case .claude: URL(string: "https://claude.ai/settings/usage")!
        case .cursor: URL(string: "https://cursor.com/dashboard")!
        case .grok: URL(string: "https://grok.com/")!
        }
    }
    public var loginHelp: String {
        switch self {
        case .codex: "Run codex login in Terminal."
        case .claude: "Run claude auth login in Terminal, or allow Keychain access below."
        case .cursor: "Sign in to the Cursor app."
        case .grok: "Sign in through Grok CLI."
        }
    }
}

public struct UsageWindow: Sendable, Equatable {
    public let title: String
    public let usedPercent: Double?
    public let resetsAt: Date?
    public init(title: String, usedPercent: Double?, resetsAt: Date?) {
        self.title = title; self.usedPercent = usedPercent; self.resetsAt = resetsAt
    }
    public var remainingPercent: Double? { usedPercent.map { 100 - $0 } }
}
public struct UsageExtra: Sendable, Equatable {
    public let title: String
    public let value: String
    public init(_ title: String, _ value: String) { self.title = title; self.value = value }
}
public struct UsageSnapshot: Sendable {
    public let provider: Provider
    public let plan: String?
    public let windows: [UsageWindow]
    public let extras: [UsageExtra]
    public let fetchedAt: Date
    public init(provider: Provider, plan: String?, windows: [UsageWindow], extras: [UsageExtra], fetchedAt: Date) {
        self.provider = provider; self.plan = plan; self.windows = windows; self.extras = extras; self.fetchedAt = fetchedAt
    }
}
public enum ProviderError: Error, LocalizedError, Sendable {
    case disconnected(String)
    case expired
    case http(Int, retryAfter: Date?)
    case invalidResponse
    case network
    case ambiguousAccount
    case keychainPermission
    public var errorDescription: String? {
        switch self {
        case .disconnected(let instruction): instruction
        case .expired, .http(401, _), .http(403, _): "Session expired. Sign in through the provider app, then refresh."
        case .http(429, _): "Rate limited. Try Refresh again later."
        case .http: "Provider is temporarily unavailable."
        case .invalidResponse: "Provider returned an unrecognized usage response."
        case .network: "Could not reach the provider."
        case .ambiguousAccount: "Multiple Grok accounts found. Keep one signed-in account."
        case .keychainPermission: "Keychain access needs your approval. Use Connect to allow access."
        }
    }
    public var retryAfter: Date? {
        if case .http(_, let date) = self { return date }
        return nil
    }
}

public enum DisplayText {
    public static func reset(_ date: Date?, now: Date = .now) -> String {
        guard let date else { return "Reset unknown" }
        guard date > now else { return "Awaiting refresh" }
        let minutes = Int(ceil(date.timeIntervalSince(now) / 60))
        if minutes < 60 { return "Resets in \(minutes)m" }
        let hours = minutes / 60
        if hours < 24 { return "Resets in \(hours)h \(minutes % 60)m" }
        return "Resets in \(hours / 24)d \(hours % 24)h"
    }
    private static func formattedPercent(_ value: Double?) -> String {
        guard let value, value.isFinite, (0...100).contains(value) else { return "Unknown" }
        if value > 0 && value < 0.001 { return "<0.001%" }
        if value < 100 && value > 99.999 { return ">99.999%" }
        let fixed = String(format: "%.3f", value)
        return fixed.replacingOccurrences(of: "0+$", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\.$", with: "", options: .regularExpression) + "%"
    }
    public static func used(_ usedPercent: Double?) -> String { formattedPercent(usedPercent) }
    public static func remaining(_ usedPercent: Double?) -> String {
        formattedPercent(usedPercent.map { 100 - $0 })
    }
    public static func percent(_ usedPercent: Double?) -> String { remaining(usedPercent) }
}
