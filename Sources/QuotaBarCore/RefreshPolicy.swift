import Foundation

public enum RefreshPolicy {
    public static func accountChanged(previous: String?, current: String) -> Bool {
        guard let previous else { return false }
        return previous != current
    }
    public static func canAttempt(now: Date, manual: Bool, retryAt: Date?) -> Bool {
        guard let retryAt else { return true }
        return now >= retryAt
    }
}
