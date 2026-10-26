import Foundation

private final class FixedOriginRedirectGuard: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        guard let original = task.originalRequest?.url, let destination = request.url,
              original.scheme == "https", destination.scheme == "https", original.host == destination.host,
              original.port == destination.port else { completionHandler(nil); return }
        completionHandler(request)
    }
}

public enum ProviderClient {
    public static func fetch(_ provider: Provider, allowKeychainPrompt: Bool = false) async throws -> (UsageSnapshot, String) {
        let credential = try await Task.detached(priority: .utility) {
            try CredentialReader.load(provider, allowKeychainPrompt: allowKeychainPrompt)
        }.value
        return try await fetch(provider, credential: credential)
    }
    public static func fetch(_ provider: Provider, credential: ProviderCredential) async throws -> (UsageSnapshot, String) {
        let primary: URL
        switch provider {
        case .codex: primary = URL(string: "https://chatgpt.com/backend-api/wham/usage")!
        case .claude: primary = URL(string: "https://api.anthropic.com/api/oauth/usage?cedar_ember=1")!
        case .cursor: primary = URL(string: "https://cursor.com/api/usage-summary")!
        case .grok: primary = URL(string: "https://cli-chat-proxy.grok.com/v1/billing?format=credits")!
        }
        do {
            let data: Data
            do { data = try await request(primary, provider: provider, credential: credential) }
            catch ProviderError.http(let code, _) where provider == .claude && (code == 400 || code == 403) {
                data = try await request(URL(string: "https://api.anthropic.com/api/oauth/usage")!, provider: provider, credential: credential)
            }
            let snapshot = try UsageParser.parse(provider, data: data, fetchedAt: .now)
            return (snapshot, credential.identity)
        } catch let error as ProviderError { throw error }
        catch { throw ProviderError.network }
    }
    private static func request(_ url: URL, provider: Provider, credential: ProviderCredential) async throws -> Data {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 20
        config.httpCookieAcceptPolicy = .never
        config.httpShouldSetCookies = false
        let session = URLSession(configuration: config, delegate: FixedOriginRedirectGuard(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        switch provider {
        case .codex:
            request.setValue("Bearer \(credential.token)", forHTTPHeaderField: "Authorization")
            if let account = credential.accountID { request.setValue(account, forHTTPHeaderField: "ChatGPT-Account-Id") }
        case .claude:
            request.setValue("Bearer \(credential.token)", forHTTPHeaderField: "Authorization")
            request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("claude-code/2.0.0", forHTTPHeaderField: "User-Agent")
        case .cursor:
            guard let userID = credential.userID else { throw ProviderError.invalidResponse }
            let cookie = "WorkosCursorSessionToken=\(userID)%3A%3A\(credential.token)"
            request.setValue(cookie, forHTTPHeaderField: "Cookie")
        case .grok:
            request.setValue("Bearer \(credential.token)", forHTTPHeaderField: "Authorization")
            request.setValue("xai-grok-cli", forHTTPHeaderField: "X-XAI-Token-Auth")
            if let userID = credential.userID { request.setValue(userID, forHTTPHeaderField: "x-userid") }
            request.setValue("1.0.0", forHTTPHeaderField: "x-grok-client-version")
        }
        let (bytes, response) = try await session.bytes(for: request)
        guard let http = response as? HTTPURLResponse, http.url?.host == url.host else { throw ProviderError.invalidResponse }
        if http.statusCode != 200 {
            let retry = http.value(forHTTPHeaderField: "Retry-After").flatMap { RetryAfterParser.parse($0) }
            throw ProviderError.http(http.statusCode, retryAfter: retry)
        }
        if let length = http.expectedContentLength as Int64?, length > 524_288 { throw ProviderError.invalidResponse }
        var data = Data()
        data.reserveCapacity(8_192)
        for try await byte in bytes {
            if data.count >= 524_288 { throw ProviderError.invalidResponse }
            data.append(byte)
        }
        guard data.first == 123 || data.first == 91 else { throw ProviderError.invalidResponse }
        return data
    }
}
