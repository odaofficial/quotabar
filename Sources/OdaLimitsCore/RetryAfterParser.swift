import Foundation

public enum RetryAfterParser {
    public static func parse(_ value: String, now: Date = .now) -> Date? {
        if let seconds = TimeInterval(value), seconds.isFinite {
            return now.addingTimeInterval(min(max(seconds, 0), 3600))
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss 'GMT'"
        return formatter.date(from: value).map { min(max($0, now), now.addingTimeInterval(3600)) }
    }
}
