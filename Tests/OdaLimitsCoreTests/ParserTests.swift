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
        let result = try UsageParser.parse(.grok, data: Data(#"{"config":{"creditUsagePercent":150}}"#.utf8), fetchedAt: .now)
        XCTAssertNil(result.windows.first?.usedPercent)
    }
    func testAuthErrorDoesNotExposeResponseBody() {
        let error = ProviderError.http(401, retryAfter: nil)
        XCTAssertFalse(error.localizedDescription.contains("secret"))
        XCTAssertEqual(error.localizedDescription, "Session expired. Sign in through the provider app, then refresh.")
    }
}
