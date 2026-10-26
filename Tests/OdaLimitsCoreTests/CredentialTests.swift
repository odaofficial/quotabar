import XCTest
@testable import OdaLimitsCore

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
    func testCursorJWTIdentityAndExpiry() throws {
        let payload = Data(#"{"sub":"auth|12345","exp":9999999999}"#.utf8).base64EncodedString().replacingOccurrences(of: "=", with: "")
        let jwt = "e30.\(payload).sig"
        let result = try CredentialParser.cursor(jwt, now: .now)
        XCTAssertEqual(result.userID, "12345")
        XCTAssertEqual(result.token, jwt)
    }
    func testGrokRejectsAmbiguousAccounts() throws {
        let json = Data(#"{"https://auth.x.ai::a":{"bearer":"a","expires_at":9999999999,"user_id":"1"},"https://auth.x.ai::b":{"bearer":"b","expires_at":9999999999,"user_id":"2"}}"#.utf8)
        XCTAssertThrowsError(try CredentialParser.grok(json, now: .now)) { error in
            guard case ProviderError.ambiguousAccount = error else { return XCTFail("Wrong error") }
        }
    }
}
