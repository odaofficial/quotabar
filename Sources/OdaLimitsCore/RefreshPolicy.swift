import Foundation

public enum RefreshPolicy {
    public static func canAttempt(now: Date, manual: Bool, retryAt: Date?) -> Bool {
        guard let retryAt else { return true }
        return now >= retryAt
    }
}
