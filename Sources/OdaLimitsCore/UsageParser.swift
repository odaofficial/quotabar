import Foundation

public enum UsageParser {
    public static func parse(_ provider: Provider, data: Data, fetchedAt: Date) throws -> UsageSnapshot {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw ProviderError.invalidResponse }
        switch provider {
        case .codex: return codex(json, fetchedAt)
        case .claude: return claude(json, fetchedAt)
        case .cursor: return cursor(json, fetchedAt)
        case .grok: return grok(json, fetchedAt)
        }
    }
    private static func dict(_ value: Any?) -> [String: Any]? { value as? [String: Any] }
    private static func string(_ value: Any?) -> String? { (value as? String).flatMap { $0.isEmpty ? nil : $0 } }
    private static func number(_ value: Any?) -> Double? {
        if let s = value as? String, let n = Double(s), n.isFinite { return n }
        guard let n = value as? NSNumber, CFGetTypeID(n) != CFBooleanGetTypeID() else { return nil }
        return n.doubleValue.isFinite ? n.doubleValue : nil
    }
    private static func percent(_ value: Any?) -> Double? {
        guard let n = number(value), (0...100).contains(n) else { return nil }
        return n
    }
    private static func iso(_ value: Any?) -> Date? {
        guard let s = string(value) else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: s) ?? ISO8601DateFormatter().date(from: s)
    }
    private static func epoch(_ value: Any?) -> Date? { number(value).map(Date.init(timeIntervalSince1970:)) }
    private static func money(_ value: Any?) -> String? {
        guard let cents = number(value) else { return nil }
        return String(format: "$%.2f", cents / 100)
    }
    private static func codex(_ json: [String: Any], _ fetched: Date) -> UsageSnapshot {
        var windows: [UsageWindow] = []
        func append(_ rate: [String: Any], prefix: String = "") {
            for (key, fallback) in [("primary_window", "5-hour"), ("secondary_window", "Weekly")] {
                guard let window = dict(rate[key]) else { continue }
                let seconds = number(window["limit_window_seconds"])
                let label: String = seconds.map { $0 >= 86400 ? "\(Int($0 / 86400))-day" : "\(Int($0 / 3600))-hour" } ?? fallback
                let reset = epoch(window["reset_at"]) ?? number(window["reset_after_seconds"]).map { fetched.addingTimeInterval($0) }
                windows.append(.init(title: prefix + label, usedPercent: percent(window["used_percent"]), resetsAt: reset))
            }
        }
        if let rate = dict(json["rate_limit"]) { append(rate) }
        if let review = dict(json["code_review_rate_limit"]) { append(review, prefix: "Code review · ") }
        for extra in json["additional_rate_limits"] as? [[String: Any]] ?? [] {
            guard let rate = dict(extra["rate_limit"]) else { continue }
            let label = string(extra["limit_name"]) ?? string(extra["metered_feature"]) ?? "Additional"
            append(rate, prefix: label + " · ")
        }
        var extras: [UsageExtra] = []
        if let credits = dict(json["credits"]) {
            if let balance = money(credits["balance"]), credits["has_credits"] as? Bool == true { extras.append(.init("Credits", balance)) }
        }
        if let resets = dict(json["rate_limit_reset_credits"]) {
            if let count = number(resets["available_count"]) { extras.append(.init("Free resets", "\(Int(count))")) }
            if let count = number(resets["applicable_available_count"]) { extras.append(.init("Applicable now", "\(Int(count))")) }
        }
        return .init(provider: .codex, plan: string(json["plan_type"]), windows: windows, extras: extras, fetchedAt: fetched)
    }
    private static func claude(_ json: [String: Any], _ fetched: Date) -> UsageSnapshot {
        let keys = [("five_hour", "5-hour"), ("seven_day", "Weekly"), ("seven_day_sonnet", "Sonnet weekly"), ("seven_day_opus", "Opus weekly")]
        var windows: [UsageWindow] = keys.compactMap { key, label in
            guard let value = dict(json[key]) else { return nil }
            return .init(title: label, usedPercent: percent(value["utilization"]), resetsAt: iso(value["resets_at"]))
        }
        if let limits = json["limits"] as? [String: Any] {
            for key in limits.keys.sorted() where !keys.contains(where: { $0.0 == key }) {
                if let value = dict(limits[key]) {
                    windows.append(.init(title: key.replacingOccurrences(of: "_", with: " ").capitalized, usedPercent: percent(value["utilization"]), resetsAt: iso(value["resets_at"])))
                }
            }
        }
        var extras: [UsageExtra] = []
        if let usage = dict(json["extra_usage"]), usage["is_enabled"] as? Bool == true {
            if let used = money(usage["used_credits"]) { extras.append(.init("Extra used", used)) }
            if let limit = money(usage["monthly_limit"]) { extras.append(.init("Extra limit", limit)) }
        }
        return .init(provider: .claude, plan: string(json["subscription_type"]), windows: windows, extras: extras, fetchedAt: fetched)
    }
    private static func cursor(_ json: [String: Any], _ fetched: Date) -> UsageSnapshot {
        let individual = dict(json["individualUsage"]) ?? [:]
        let plan = dict(individual["plan"]) ?? dict(individual["overall"])
        let reset = iso(json["billingCycleEnd"])
        var windows: [UsageWindow] = []
        var extras: [UsageExtra] = []
        if let plan {
            windows.append(.init(title: "Plan cycle", usedPercent: percent(plan["totalPercentUsed"]), resetsAt: reset))
            if let used = money(plan["used"]), let limit = money(plan["limit"]) { extras.append(.init("Plan used", "\(used) of \(limit)")) }
        }
        if let onDemand = dict(individual["onDemand"]), onDemand["enabled"] as? Bool == true {
            let used = number(onDemand["used"]), limit = number(onDemand["limit"])
            let pct = (used != nil && limit != nil && limit! > 0) ? percent(used! / limit! * 100) : nil
            windows.append(.init(title: "On-demand", usedPercent: pct, resetsAt: reset))
            if let amount = money(onDemand["used"]) { extras.append(.init("On-demand used", amount)) }
        }
        if let team = dict(json["teamUsage"]), let pooled = dict(team["pooled"]) {
            windows.append(.init(title: "Team pool", usedPercent: percent(pooled["totalPercentUsed"]), resetsAt: reset))
        }
        return .init(provider: .cursor, plan: string(json["membershipType"]), windows: windows, extras: extras, fetchedAt: fetched)
    }
    private static func grok(_ json: [String: Any], _ fetched: Date) -> UsageSnapshot {
        let config = dict(json["config"]) ?? [:]
        let period = dict(config["currentPeriod"]) ?? [:]
        let type = string(period["type"])?.capitalized ?? "Current period"
        let reset = iso(period["end"]) ?? iso(json["billingPeriodEnd"])
        let window = UsageWindow(title: type, usedPercent: percent(config["creditUsagePercent"]), resetsAt: reset)
        var extras: [UsageExtra] = []
        if let balance = money(dict(config["prepaidBalance"])?["val"]) { extras.append(.init("Prepaid balance", balance)) }
        if let used = money(dict(config["onDemandUsed"])?["val"]) { extras.append(.init("On-demand used", used)) }
        if let cap = money(dict(config["onDemandCap"])?["val"]) { extras.append(.init("On-demand cap", cap)) }
        return .init(provider: .grok, plan: string(json["subscriptionTier"]), windows: [window], extras: extras, fetchedAt: fetched)
    }
}
