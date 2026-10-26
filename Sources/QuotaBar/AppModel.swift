import AppKit
import Foundation
import QuotaBarCore
import ServiceManagement

struct ProviderState {
    var snapshot: UsageSnapshot?
    var error: String?
    var checkedAt: Date?
    var needsKeychainApproval = false
    var identity: String?
    var nextAllowed: Date = .distantPast
    var failures = 0
    var rateLimitedUntil: Date?
}

enum DemoScenario: String {
    case connected, mixed, empty, expanded, initial, failed, keychain
}

@MainActor final class AppModel: ObservableObject {
    @Published private(set) var states: [Provider: ProviderState] = [:]
    @Published private(set) var isRefreshing = false
    @Published private(set) var now = Date()
    @Published private(set) var loginStatus = "Unavailable outside the installed app"
    @Published var showingSettings = false
    @Published var enabled: Set<Provider>
    let isDemo: Bool
    let demoScenario: DemoScenario

    init(demo: Bool, scenario: DemoScenario = .connected) {
        isDemo = demo
        demoScenario = scenario
        enabled = demo ? Set(Provider.allCases) : Set(Provider.allCases.filter { UserDefaults.standard.object(forKey: "enabled.\($0.rawValue)") as? Bool ?? true })
        for provider in Provider.allCases { states[provider] = ProviderState() }
        if demo {
            seedDemo()
            switch scenario {
            case .connected, .expanded: break
            case .empty: enabled = []
            case .initial:
                for provider in Provider.allCases { states[provider] = ProviderState() }
            case .failed:
                for provider in Provider.allCases {
                    states[provider] = ProviderState(error: "Could not reach the provider.", checkedAt: .now)
                }
            case .keychain:
                enabled = [.claude]
                states[.claude] = ProviderState(error: ProviderError.keychainPermission.localizedDescription,
                                                checkedAt: .now, needsKeychainApproval: true)
            case .mixed:
                var codex = states[.codex]!
                codex.error = "Could not reach the provider."
                states[.codex] = codex
                states[.claude] = ProviderState(snapshot: .init(provider: .claude, plan: "Max (20x)", windows: [
                    .init(title: "Session limit", usedPercent: nil, resetsAt: nil),
                    .init(title: "Weekly · all models", usedPercent: 100, resetsAt: Date().addingTimeInterval(3_600 * 24 * 3))
                ], extras: [], fetchedAt: .now), checkedAt: .now)
                states[.cursor] = ProviderState(error: "Sign in to the Cursor app.", checkedAt: .now)
            }
        }
    }
    func start() {
        guard !isDemo else { return }
        configureLoginItem()
    }
    func setPopoverVisible(_ visible: Bool) {
        if visible { now = .now }
    }
    func setEnabled(_ provider: Provider, _ value: Bool) {
        if value { enabled.insert(provider) } else { enabled.remove(provider) }
        if !isDemo { UserDefaults.standard.set(value, forKey: "enabled.\(provider.rawValue)") }
    }
    func refresh(claudePrompt: Bool = false, only target: Provider? = nil) {
        guard !isDemo, !isRefreshing, !enabled.isEmpty else { return }
        now = .now
        isRefreshing = true
        Task { @MainActor in
            for provider in Provider.allCases where enabled.contains(provider) && (target == nil || provider == target) {
                var state = states[provider, default: ProviderState()]
                state.needsKeychainApproval = false
                var credentialLoaded = false
                var validatingIdentity = false
                do {
                    let credential = try await Task.detached(priority: .utility) {
                        try CredentialReader.load(provider, allowKeychainPrompt: claudePrompt && provider == .claude)
                    }.value
                    credentialLoaded = true
                    if RefreshPolicy.accountChanged(previous: state.identity, current: credential.identity) {
                        state.snapshot = nil
                        state.error = nil
                        state.failures = 0
                        state.nextAllowed = .distantPast
                        state.rateLimitedUntil = nil
                    }
                    state.identity = credential.identity
                    states[provider] = state
                    if !RefreshPolicy.canAttempt(now: .now, manual: true, retryAt: state.rateLimitedUntil) {
                        if let retry = state.rateLimitedUntil {
                            state.error = "Rate limited. Try Refresh after \(retry.formatted(date: .abbreviated, time: .shortened))."
                            states[provider] = state
                        }
                        continue
                    }
                    state.checkedAt = .now
                    let (snapshot, _) = try await ProviderClient.fetch(provider, credential: credential)
                    validatingIdentity = true
                    let current = try await Task.detached(priority: .utility) { try CredentialReader.load(provider).identity }.value
                    guard current == credential.identity else {
                        state.snapshot = nil
                        state.identity = current
                        throw ProviderError.disconnected("Session changed. Refresh again.")
                    }
                    state.snapshot = snapshot
                    state.error = nil
                    state.failures = 0
                    state.nextAllowed = .distantPast
                    state.rateLimitedUntil = nil
                } catch let error as ProviderError {
                    if !credentialLoaded || validatingIdentity {
                        state.snapshot = nil
                        state.identity = nil
                        state.rateLimitedUntil = nil
                        state.failures = 0
                    }
                    if case .disconnected = error { state.snapshot = nil; state.identity = nil }
                    if case .expired = error { state.snapshot = nil; state.identity = nil }
                    state.checkedAt = .now
                    state.error = error.localizedDescription
                    if case .keychainPermission = error, provider == .claude {
                        state.needsKeychainApproval = true
                    }
                    state.failures = min(state.failures + 1, 6)
                    let backoff = min(300 * pow(2, Double(state.failures - 1)), 3600)
                    state.nextAllowed = max(Date().addingTimeInterval(backoff), error.retryAfter ?? Date())
                    if case .http(429, _) = error {
                        state.rateLimitedUntil = state.nextAllowed
                        state.error = "Rate limited. Try Refresh after \(state.nextAllowed.formatted(date: .abbreviated, time: .shortened))."
                    }
                } catch {
                    if !credentialLoaded || validatingIdentity {
                        state.snapshot = nil
                        state.identity = nil
                        state.rateLimitedUntil = nil
                        state.failures = 0
                    }
                    state.checkedAt = .now
                    state.error = ProviderError.network.localizedDescription
                    state.failures = min(state.failures + 1, 6)
                    state.nextAllowed = Date().addingTimeInterval(min(300 * pow(2, Double(state.failures - 1)), 3600))
                }
                states[provider] = state
            }
            isRefreshing = false
        }
    }
    func connectClaude() { refresh(claudePrompt: true, only: .claude) }
    func configureLoginItem() {
        guard !isDemo else { return }
        let bundle = Bundle.main.bundleURL
        let installed = bundle.pathExtension == "app" &&
            (bundle.path.hasPrefix(FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications").path + "/") || bundle.path.hasPrefix("/Applications/"))
        guard installed else { loginStatus = "Available after installation"; return }
        var registrationError: String?
        if !UserDefaults.standard.bool(forKey: "loginSetupDone") {
            let status = SMAppService.mainApp.status
            if status != .enabled && status != .requiresApproval {
                do { try SMAppService.mainApp.register() }
                catch { registrationError = loginError(error) }
            }
            if SMAppService.mainApp.status == .enabled || SMAppService.mainApp.status == .requiresApproval {
                UserDefaults.standard.set(true, forKey: "loginSetupDone")
            }
        } else if UserDefaults.standard.string(forKey: "loginBundlePath") != bundle.path,
                  (SMAppService.mainApp.status == .enabled || UserDefaults.standard.bool(forKey: "loginMigrationPending")) {
            do {
                if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() }
                try SMAppService.mainApp.register()
                UserDefaults.standard.set(false, forKey: "loginMigrationPending")
            } catch {
                UserDefaults.standard.set(true, forKey: "loginMigrationPending")
                registrationError = loginError(error)
            }
        }
        if registrationError == nil { UserDefaults.standard.set(bundle.path, forKey: "loginBundlePath") }
        updateLoginStatus()
        if let registrationError { loginStatus = registrationError }
    }
    func updateLoginStatus() {
        switch SMAppService.mainApp.status {
        case .enabled: loginStatus = "On"
        case .requiresApproval: loginStatus = "Needs approval in System Settings"
        case .notRegistered: loginStatus = "Off"
        case .notFound: loginStatus = "Login item not found"
        default: loginStatus = "Unavailable"
        }
    }
    func setLaunchAtLogin(_ enabled: Bool) {
        guard !isDemo else { return }
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            UserDefaults.standard.set(true, forKey: "loginSetupDone")
            UserDefaults.standard.set(Bundle.main.bundlePath, forKey: "loginBundlePath")
            UserDefaults.standard.set(false, forKey: "loginMigrationPending")
            updateLoginStatus()
        } catch { loginStatus = loginError(error) }
    }
    private func loginError(_ error: Error) -> String {
        let nsError = error as NSError
        let safeDomain = nsError.domain.count <= 80 && nsError.domain.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "." || $0 == "-" || $0 == "_" })
            ? nsError.domain : "NSError"
        return "Login registration failed (\(safeDomain) \(nsError.code))"
    }
    private func seedDemo() {
        let soon = now.addingTimeInterval(3_600 * 4 - 30)
        let weekly = now.addingTimeInterval(3_600 * 24 * 3 - 30)
        let claudeSoon = now.addingTimeInterval(3_600 + 46 * 60 + 30)
        let claudeWeekly = now.addingTimeInterval(16 * 3_600 + 6 * 60 + 30)
        states[.codex] = ProviderState(snapshot: .init(provider: .codex, plan: "Plus", windows: [
            .init(title: "5-hour", usedPercent: 42, resetsAt: soon), .init(title: "Weekly", usedPercent: 18, resetsAt: weekly),
            .init(title: "Code review · Weekly", usedPercent: nil, resetsAt: weekly)
        ], extras: [.init("Free resets", "2"), .init("Applicable now", "0")], fetchedAt: .now), checkedAt: .now)
        states[.claude] = ProviderState(snapshot: .init(provider: .claude, plan: "Max (20x)", windows: [
            .init(title: "Session limit", usedPercent: 9, resetsAt: claudeSoon), .init(title: "Weekly · all models", usedPercent: 71, resetsAt: claudeWeekly)
        ], extras: [], fetchedAt: .now), checkedAt: .now)
        states[.cursor] = ProviderState(snapshot: .init(provider: .cursor, plan: "Pro", windows: [
            .init(title: "Plan cycle", usedPercent: 7.25, resetsAt: weekly)
        ], extras: [.init("Plan used", "$1.45 of $20.00")], fetchedAt: .now), checkedAt: .now)
        states[.grok] = ProviderState(snapshot: .init(provider: .grok, plan: "SuperGrok", windows: [
            .init(title: "Weekly", usedPercent: 33, resetsAt: weekly)
        ], extras: [.init("Prepaid balance", "$8.00")], fetchedAt: .now), checkedAt: .now)
    }
}
