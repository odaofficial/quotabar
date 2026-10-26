import XCTest
@testable import OdaLimitsCore

final class ParserTests: XCTestCase {
    func testCodexPreservesEveryBucketAndUnknownPercent() throws {
        let data = Data(#"{"plan_type":"plus","rate_limit":{"primary_window":{"used_percent":42.5,"limit_window_seconds":18000,"reset_at":2000000000},"secondary_window":{"limit_window_seconds":604800}},"additional_rate_limits":[{"limit_name":"Spark","rate_limit":{"primary_window":{"used_percent":2}}}]}"#.utf8)
        let result = try UsageParser.parse(.codex, data: data, fetchedAt: .now)
        XCTAssertEqual(result.windows.count, 3)
        XCTAssertEqual(result.windows[0].usedPercent, 42.5)
        XCTAssertNil(result.windows[1].usedPercent)
        XCTAssertEqual(result.windows[2].title, "Spark · 5-hour")
    }
    func testClaudeDoesNotInventMissingWindows() throws {
        let data = Data(#"{"five_hour":{"utilization":12.5,"resets_at":"2026-10-27T12:00:00Z"},"seven_day":null,"extra_usage":{"is_enabled":true,"used_credits":275,"monthly_limit":1000}}"#.utf8)
        let result = try UsageParser.parse(.claude, data: data, fetchedAt: .now)
        XCTAssertEqual(result.windows.count, 1)
        XCTAssertEqual(result.windows[0].usedPercent, 12.5)
        XCTAssertEqual(result.extras.count, 2)
    }
    func testCursorPercentIsAlreadyPercentageAndCentsAreMoney() throws {
        let data = Data(#"{"membershipType":"pro","billingCycleEnd":"2026-11-01T00:00:00Z","individualUsage":{"plan":{"used":125,"limit":2000,"totalPercentUsed":6.25},"onDemand":{"enabled":true,"used":40,"limit":500}}}"#.utf8)
        let result = try UsageParser.parse(.cursor, data: data, fetchedAt: .now)
        XCTAssertEqual(result.windows.first?.usedPercent, 6.25)
        XCTAssertEqual(result.extras.first?.value, "$1.25 of $20.00")
    }
    func testGrokMissingPercentRemainsUnknown() throws {
        let data = Data(#"{"config":{"currentPeriod":{"type":"weekly","end":"2026-11-01T00:00:00Z"},"prepaidBalance":{"val":1234}}}"#.utf8)
        let result = try UsageParser.parse(.grok, data: data, fetchedAt: .now)
        XCTAssertNil(result.windows.first?.usedPercent)
        XCTAssertEqual(result.extras.first?.value, "$12.34")
    }
    func testInvalidPercentIsUnknown() throws {
        let result = try UsageParser.parse(.grok, data: Data(#"{"config":{"creditUsagePercent":150,"currentPeriod":{"end":"2026-11-01T00:00:00Z"}}}"#.utf8), fetchedAt: .now)
        XCTAssertNil(result.windows.first?.usedPercent)
    }
    func testAuthErrorDoesNotExposeResponseBody() {
        let error = ProviderError.http(401, retryAfter: nil)
        XCTAssertFalse(error.localizedDescription.contains("secret"))
        XCTAssertEqual(error.localizedDescription, "Session expired. Sign in through the provider app, then refresh.")
    }
}

final class DisplayTests: XCTestCase {
    func testPastResetRemainsAwaitingRefresh() {
        XCTAssertEqual(DisplayText.reset(Date(timeIntervalSince1970: 10), now: Date(timeIntervalSince1970: 20)), "Awaiting refresh")
    }
    func testMissingPercentRemainsUnknown() {
        XCTAssertEqual(DisplayText.percent(nil), "Unknown")
    }
    func testGrokLegacyResetUnderConfig() throws {
        let json = Data(#"{"config":{"billingPeriodEnd":"2026-11-01T00:00:00Z","currentPeriod":{"type":"USAGE_PERIOD_TYPE_MONTHLY"}}}"#.utf8)
        let result = try UsageParser.parse(.grok, data: json, fetchedAt: .now)
        XCTAssertEqual(result.windows.first?.title, "Monthly")
        XCTAssertNotNil(result.windows.first?.resetsAt)
    }
    func testCodexCreditsAreCreditUnits() throws {
        let json = Data(#"{"credits":{"has_credits":true,"balance":"12.5"}}"#.utf8)
        let result = try UsageParser.parse(.codex, data: json, fetchedAt: .now)
        XCTAssertEqual(result.extras.first?.value, "12.5 credits")
    }
    func testCodexCodeReviewAndResetExtras() throws {
        let json = Data(#"{"code_review_rate_limit":{"primary_window":{"used_percent":2,"limit_window_seconds":604800}},"rate_limit_reset_credits":{"available_count":2,"applicable_available_count":0}}"#.utf8)
        let result = try UsageParser.parse(.codex, data: json, fetchedAt: .now)
        XCTAssertEqual(result.windows.first?.title, "Code review · 7-day")
        XCTAssertEqual(result.extras.map(\.value), ["2", "0"])
    }
}

final class EnvelopeTests: XCTestCase {
    func testEmptySuccessEnvelopeIsRejectedForEveryProvider() {
        for provider in Provider.allCases {
            XCTAssertThrowsError(try UsageParser.parse(provider, data: Data("{}".utf8), fetchedAt: .now), provider.rawValue)
        }
    }
    func testResetWithoutPercentIsMeaningfulButStillUnknown() throws {
        let result = try UsageParser.parse(.grok, data: Data(#"{"config":{"currentPeriod":{"end":"2026-11-01T00:00:00Z"}}}"#.utf8), fetchedAt: .now)
        XCTAssertNil(result.windows.first?.usedPercent)
        XCTAssertNotNil(result.windows.first?.resetsAt)
    }
}

final class AdditionalContractTests: XCTestCase {
    func testGrokPlanFromConfig() throws {
        let json = Data(#"{"config":{"subscriptionTier":"supergrok","creditUsagePercent":25}}"#.utf8)
        let result = try UsageParser.parse(.grok, data: json, fetchedAt: .now)
        XCTAssertEqual(result.plan, "supergrok")
    }
    func testCursorTeamOnDemandPool() throws {
        let json = Data(#"{"teamUsage":{"onDemand":{"used":100,"limit":1000}},"billingCycleEnd":"2026-11-01T00:00:00Z"}"#.utf8)
        let result = try UsageParser.parse(.cursor, data: json, fetchedAt: .now)
        XCTAssertEqual(result.windows.first?.title, "Team on-demand")
        XCTAssertEqual(result.windows.first?.usedPercent, 10)
    }
    func testDisabledCursorTeamOnDemandIsHidden() throws {
        let json = Data(#"{"individualUsage":{"plan":{"totalPercentUsed":15}},"teamUsage":{"onDemand":{"enabled":false,"used":100,"limit":1000}}}"#.utf8)
        let result = try UsageParser.parse(.cursor, data: json, fetchedAt: .now)
        XCTAssertEqual(result.windows.map(\.title), ["Plan cycle"])
    }
    func testAccountChangeResetsPriorCooldownState() {
        XCTAssertTrue(RefreshPolicy.accountChanged(previous: "A", current: "B"))
        XCTAssertFalse(RefreshPolicy.accountChanged(previous: "A", current: "A"))
    }
    func testRateLimitCooldownAppliesToManualRefresh() {
        let limit = Date(timeIntervalSince1970: 1000)
        XCTAssertFalse(RefreshPolicy.canAttempt(now: Date(timeIntervalSince1970: 900), manual: true, retryAt: limit))
        XCTAssertTrue(RefreshPolicy.canAttempt(now: Date(timeIntervalSince1970: 1001), manual: true, retryAt: limit))
    }
}

final class RetryAfterTests: XCTestCase {
    func testHTTPDateRetryAfter() {
        let now = Date(timeIntervalSince1970: 1_783_000_000)
        let date = RetryAfterParser.parse("Sun, 31 May 2026 14:46:40 GMT", now: now)
        XCTAssertNotNil(date)
    }
    func testSecondsRetryAfterIsCapped() {
        let now = Date(timeIntervalSince1970: 100)
        XCTAssertEqual(RetryAfterParser.parse("99999", now: now), Date(timeIntervalSince1970: 3700))
    }
    func testHTTPDateRetryAfterIsCappedToOneHour() {
        let now = Date(timeIntervalSince1970: 100)
        XCTAssertEqual(RetryAfterParser.parse("Thu, 01 Jan 2099 00:00:00 GMT", now: now), Date(timeIntervalSince1970: 3700))
        XCTAssertEqual(RetryAfterParser.parse("Thu, 01 Jan 1970 00:00:00 GMT", now: now), now)
    }
}
