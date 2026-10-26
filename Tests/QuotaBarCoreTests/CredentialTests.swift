import XCTest
@testable import QuotaBarCore

final class CredentialTests: XCTestCase {
    func testCodexCredentialSelection() throws {
        let json = Data(#"{"tokens":{"access_token":"synthetic","account_id":"acct"}}"#.utf8)
        let result = try CredentialParser.codex(json)
        XCTAssertEqual(result.token, "synthetic")
        XCTAssertEqual(result.accountID, "acct")
    }
    func testClaudeCredentialSelectionAndExpiry() throws {
        let json = Data(#"{"claudeAiOauth":{"accessToken":"synthetic","expiresAt":9999999999999,"subscriptionType":"pro"}}"#.utf8)
        XCTAssertEqual(try CredentialParser.claude(json, now: .now).token, "synthetic")
        let expired = Data(#"{"claudeAiOauth":{"accessToken":"synthetic","expiresAt":1}}"#.utf8)
        XCTAssertThrowsError(try CredentialParser.claude(expired, now: .now))
    }
    func testClaudePlanUsesConsistentCredentialTier() throws {
        let max20 = Data(#"{"claudeAiOauth":{"accessToken":"synthetic","subscriptionType":"max","rateLimitTier":"default_claude_max_20x"}}"#.utf8)
        XCTAssertEqual(try CredentialParser.claude(max20, now: .now).planLabel, "Max (20x)")
        let max5 = Data(#"{"claudeAiOauth":{"accessToken":"synthetic","subscriptionType":"max","rateLimitTier":"default_claude_max_5x"}}"#.utf8)
        XCTAssertEqual(try CredentialParser.claude(max5, now: .now).planLabel, "Max (5x)")
        let inconsistent = Data(#"{"claudeAiOauth":{"accessToken":"synthetic","subscriptionType":"pro","rateLimitTier":"default_claude_max_20x"}}"#.utf8)
        XCTAssertEqual(try CredentialParser.claude(inconsistent, now: .now).planLabel, "Pro")
        let unknown = Data(#"{"claudeAiOauth":{"accessToken":"synthetic","subscriptionType":"enterprise","rateLimitTier":"unknown"}}"#.utf8)
        XCTAssertNil(try CredentialParser.claude(unknown, now: .now).planLabel)
    }
    func testCursorJWTIdentityAndExpiry() throws {
        let payload = Data(#"{"sub":"auth|12345","exp":9999999999}"#.utf8).base64EncodedString().replacingOccurrences(of: "=", with: "")
        let jwt = "e30.\(payload).sig"
        let result = try CredentialParser.cursor(jwt, now: .now)
        XCTAssertEqual(result.userID, "12345")
        XCTAssertEqual(result.token, jwt)
    }
    func testClaudeIdentityUsesFullToken() {
        let first = ProviderCredential(token: "sk-ant-oat01-one")
        let second = ProviderCredential(token: "sk-ant-oat01-two")
        XCTAssertNotEqual(first.identity, second.identity)
        XCTAssertFalse(first.identity.contains("sk-ant"))
    }
    func testGrokFractionalISOExpiryIsEnforced() throws {
        let json = Data(#"{"https://auth.x.ai::a":{"key":"synthetic","expires_at":"2026-01-10T11:23:05.098865Z","user_id":"one"}}"#.utf8)
        XCTAssertEqual(try CredentialParser.grok(json, now: Date(timeIntervalSince1970: 1_700_000_000)).userID, "one")
        XCTAssertThrowsError(try CredentialParser.grok(json, now: Date(timeIntervalSince1970: 1_800_000_000)))
    }
    func testGrokRejectsAmbiguousAccounts() throws {
        let json = Data(#"{"https://auth.x.ai::a":{"key":"a","expires_at":9999999999,"user_id":"1"},"https://auth.x.ai::b":{"key":"b","expires_at":9999999999,"user_id":"2"}}"#.utf8)
        XCTAssertThrowsError(try CredentialParser.grok(json, now: .now)) { error in
            guard case ProviderError.ambiguousAccount = error else { return XCTFail("Wrong error") }
        }
    }
}
