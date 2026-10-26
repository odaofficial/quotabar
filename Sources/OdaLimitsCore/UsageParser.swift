import Foundation

public enum UsageParser {
    public static func parse(_ provider: Provider, data: Data, fetchedAt: Date) throws -> UsageSnapshot {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw ProviderError.invalidResponse }
        let snapshot: UsageSnapshot
        switch provider {
        case .codex: snapshot = codex(json, fetchedAt)
        case .claude: snapshot = claude(json, fetchedAt)
        case .cursor: snapshot = cursor(json, fetchedAt)
        case .grok: snapshot = grok(json, fetchedAt)
        }
        guard snapshot.windows.contains(where: { $0.usedPercent != nil || $0.resetsAt != nil }) || !snapshot.extras.isEmpty else {
            throw ProviderError.invalidResponse
        }
        return snapshot
    }
    private static func dict(_ value: Any?) -> [String: Any]? { value as? [String: Any] }
    private static func string(_ value: Any?) -> String? { (value as? String).flatMap { $0.isEmpty ? nil : $0 } }
    private static func safeLabel(_ value: Any?) -> String? {
        guard let raw = string(value), raw.count <= 60,
              raw.allSatisfy({ $0.isLetter || $0.isNumber || $0 == " " || $0 == "_" || $0 == "-" }) else { return nil }
        return raw
    }
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
                let label: String = seconds.flatMap { value in
                    guard value >= 3600, value <= 31_536_000 else { return nil }
                    return value >= 86400 ? "\(Int(value / 86400))-day" : "\(Int(value / 3600))-hour"
                } ?? fallback
                let reset = epoch(window["reset_at"]) ?? number(window["reset_after_seconds"]).map { fetched.addingTimeInterval($0) }
                windows.append(.init(title: prefix + label, usedPercent: percent(window["used_percent"]), resetsAt: reset))
            }
        }
        if let rate = dict(json["rate_limit"]) { append(rate) }
        if let review = dict(json["code_review_rate_limit"]) { append(review, prefix: "Code review · ") }
        for extra in json["additional_rate_limits"] as? [[String: Any]] ?? [] {
            guard let rate = dict(extra["rate_limit"]) else { continue }
            let label = safeLabel(extra["limit_name"]) ?? safeLabel(extra["metered_feature"]) ?? "Additional"
            append(rate, prefix: label + " · ")
        }
        var extras: [UsageExtra] = []
        if let credits = dict(json["credits"]) {
            if credits["unlimited"] as? Bool == true { extras.append(.init("Credits", "Unlimited")) }
            else if let balance = number(credits["balance"]), credits["has_credits"] as? Bool == true {
                extras.append(.init("Credits", String(format: "%g credits", balance)))
            }
        }
        if let resets = dict(json["rate_limit_reset_credits"]) {
            if let count = number(resets["available_count"]), (0...1_000_000).contains(count) { extras.append(.init("Free resets", "\(Int(count))")) }
            if let count = number(resets["applicable_available_count"]), (0...1_000_000).contains(count) { extras.append(.init("Applicable now", "\(Int(count))")) }
        }
        return .init(provider: .codex, plan: safeLabel(json["plan_type"]), windows: windows, extras: extras, fetchedAt: fetched)
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
                    let label = safeLabel(key)?.replacingOccurrences(of: "_", with: " ").capitalized ?? "Additional limit"
                    windows.append(.init(title: label, usedPercent: percent(value["utilization"]), resetsAt: iso(value["resets_at"])))
                }
            }
        }
        var extras: [UsageExtra] = []
        if let usage = dict(json["extra_usage"]), usage["is_enabled"] as? Bool == true {
            if let used = money(usage["used_credits"]) { extras.append(.init("Extra used", used)) }
            if let limit = money(usage["monthly_limit"]) { extras.append(.init("Extra limit", limit)) }
        }
        return .init(provider: .claude, plan: safeLabel(json["subscription_type"]), windows: windows, extras: extras, fetchedAt: fetched)
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
        if let team = dict(json["teamUsage"]) {
            if let pooled = dict(team["pooled"]) {
                windows.append(.init(title: "Team pool", usedPercent: percent(pooled["totalPercentUsed"]), resetsAt: reset))
            }
            if let onDemand = dict(team["onDemand"]) {
                windows.append(.init(title: "Team on-demand", usedPercent: percent(onDemand["totalPercentUsed"]), resetsAt: reset))
                if let used = money(onDemand["used"]), let limit = money(onDemand["limit"]) { extras.append(.init("Team on-demand", "\(used) of \(limit)")) }
            }
        }
        return .init(provider: .cursor, plan: safeLabel(json["membershipType"]), windows: windows, extras: extras, fetchedAt: fetched)
    }
    private static func grok(_ json: [String: Any], _ fetched: Date) -> UsageSnapshot {
        let config = dict(json["config"]) ?? [:]
        let period = dict(config["currentPeriod"]) ?? [:]
        let type = safeLabel(period["type"])?.capitalized ?? "Current period"
        let reset = iso(period["end"]) ?? iso(config["billingPeriodEnd"])
        let window = UsageWindow(title: type, usedPercent: percent(config["creditUsagePercent"]), resetsAt: reset)
        var extras: [UsageExtra] = []
        if let balance = money(dict(config["prepaidBalance"])?["val"]) { extras.append(.init("Prepaid balance", balance)) }
        if let used = money(dict(config["onDemandUsed"])?["val"]) { extras.append(.init("On-demand used", used)) }
        if let cap = money(dict(config["onDemandCap"])?["val"]) { extras.append(.init("On-demand cap", cap)) }
        return .init(provider: .grok, plan: safeLabel(config["subscriptionTier"]) ?? safeLabel(json["subscriptionTier"]), windows: [window], extras: extras, fetchedAt: fetched)
    }
}
