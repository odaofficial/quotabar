import AppKit
import QuotaBarCore
import SwiftUI

enum PanelMetrics {
    static let width: CGFloat = 410
    static let height: CGFloat = 630
}

private enum PanelSurface {
    static func content(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.13, green: 0.13, blue: 0.14) : Color(red: 0.985, green: 0.985, blue: 0.99)
    }
    static func chrome(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.17, green: 0.17, blue: 0.18) : Color(red: 0.95, green: 0.95, blue: 0.96)
    }
    static func warning(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 1, green: 0.72, blue: 0.37) : Color(red: 0.59, green: 0.30, blue: 0)
    }
}

struct PopoverView: View {
    @ObservedObject var model: AppModel
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private var checkText: String {
        guard let date = model.enabled.compactMap({ model.states[$0]?.checkedAt }).max() else {
            return "Click Refresh to check usage"
        }
        let stale = model.enabled.contains { provider in
            model.states[provider]?.snapshot != nil && model.states[provider]?.error != nil
        }
        let failed = model.enabled.contains { model.states[$0]?.error != nil }
        let status = stale ? " · some data stale" : (failed ? " · check issues" : "")
        return "Checked \(date.formatted(date: .omitted, time: .shortened))\(status)"
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Group {
                if model.showingSettings { SettingsView(model: model) }
                else { summary }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider()
            footer
        }
        .frame(width: PanelMetrics.width, height: PanelMetrics.height)
        .background(PanelSurface.content(scheme))
    }

    private var header: some View {
        HStack(spacing: 10) {
            if model.showingSettings {
                PanelIconButton(symbol: "chevron.left", title: "Back to usage", hint: "Esc") { model.showingSettings = false }
            } else {
                Image(nsImage: QuotaMark.image).frame(width: 20, height: 18).accessibilityHidden(true)
            }
            Text(model.showingSettings ? "Settings" : "QuotaBar")
                .font(.system(size: 17, weight: .semibold))
            Spacer(minLength: 0)
            if model.isDemo {
                Text("SAMPLE").font(.system(size: 9, weight: .semibold)).tracking(0.5).foregroundStyle(.secondary)
            }
            if !model.showingSettings {
                if model.isRefreshing { ProgressView().controlSize(.small).accessibilityLabel("Refreshing usage") }
                PanelIconButton(symbol: "arrow.clockwise", title: "Refresh usage", hint: "⌘R") { model.refresh() }
                    .disabled(model.isDemo || model.isRefreshing || model.enabled.isEmpty)
                PanelIconButton(symbol: "gearshape", title: "Settings", hint: "⌘,") { model.showingSettings = true }
            }
        }
        .padding(.horizontal, 18)
        .frame(height: 52)
        .background {
            if model.isDemo || reduceTransparency { PanelSurface.chrome(scheme) }
            else { Rectangle().fill(.regularMaterial) }
        }
    }

    private var summary: some View {
        ScrollView {
            if model.enabled.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "rectangle.stack.badge.plus")
                        .font(.system(size: 26)).foregroundStyle(.secondary)
                    Text("No providers selected").font(.system(size: 14, weight: .semibold))
                    Text("Choose the services you want to see here.")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                    Button("Open Settings") { model.showingSettings = true }
                        .buttonStyle(.borderedProminent).controlSize(.small)
                        .tint(Color(nsColor: .systemBlue))
                }
                .frame(maxWidth: .infinity).padding(.top, 165)
            } else {
                VStack(spacing: 0) {
                    ForEach(Provider.allCases) { provider in
                        if model.enabled.contains(provider) {
                            ProviderSection(provider: provider, state: model.states[provider] ?? ProviderState(), now: model.now,
                                            connect: { model.connectClaude() }, initiallyExpanded: model.demoScenario == .expanded)
                            if provider != Provider.allCases.last {
                                Divider().padding(.leading, 30)
                            }
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 4)
            }
        }
        .scrollIndicators(.hidden)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Text(checkText)
                .foregroundStyle(.secondary).lineLimit(1)
            Spacer(minLength: 8)
            PanelIconButton(symbol: "power", title: "Quit QuotaBar", hint: "⌘Q") {
                NSApplication.shared.terminate(nil)
            }
        }
        .font(.system(size: 11))
        .padding(.horizontal, 18).frame(height: 36)
        .background {
            if model.isDemo || reduceTransparency { PanelSurface.chrome(scheme) }
            else { Rectangle().fill(.regularMaterial) }
        }
    }
}

private struct PanelIconButton: View {
    let symbol: String
    let title: String
    let hint: String
    let action: () -> Void
    @State private var hovered = false
    @FocusState private var focused: Bool
    var body: some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 13, weight: .medium))
                .frame(width: 28, height: 28)
                .background(hovered || focused ? Color(nsColor: .quaternaryLabelColor).opacity(0.18) : .clear,
                            in: RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(focused ? Color.accentColor : .clear, lineWidth: 1.5))
        }
        .buttonStyle(PanelPressStyle()).onHover { hovered = $0 }.focused($focused)
        .help("\(title) (\(hint))").accessibilityLabel(title)
    }
}

private struct PanelPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.55 : 1)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
    }
}

private struct ProviderSection: View {
    let provider: Provider
    let state: ProviderState
    let now: Date
    let connect: () -> Void
    @State private var expanded: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var scheme
    private var resetExtras: [UsageExtra] {
        state.snapshot?.extras.filter { $0.title.localizedCaseInsensitiveContains("reset") || $0.title == "Applicable now" } ?? []
    }
    init(provider: Provider, state: ProviderState, now: Date, connect: @escaping () -> Void, initiallyExpanded: Bool) {
        self.provider = provider; self.state = state; self.now = now; self.connect = connect
        _expanded = State(initialValue: initiallyExpanded)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                if let image = ProviderMark.image(for: provider) {
                    Image(nsImage: image).resizable().interpolation(.high).frame(width: 22, height: 22)
                        .help(provider.displayName).accessibilityLabel(provider.displayName)
                } else {
                    Image(systemName: "square.stack.3d.up").frame(width: 22, height: 22)
                        .help(provider.displayName).accessibilityLabel(provider.displayName)
                }
                if let snapshot = state.snapshot {
                    Text(snapshot.plan ?? "Plan unavailable")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(snapshot.plan == nil ? .secondary : .primary)
                }
                Spacer(minLength: 4)
                Link(destination: provider.dashboardURL) {
                    Image(systemName: "arrow.up.right.square").frame(width: 24, height: 24)
                }
                .buttonStyle(PanelPressStyle()).help("Open \(provider.displayName) dashboard")
                .accessibilityLabel("Open \(provider.displayName) dashboard")
                if state.snapshot != nil {
                    Button {
                        withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 1)) { expanded.toggle() }
                    } label: {
                        Image(systemName: "chevron.down").font(.system(size: 10, weight: .semibold))
                            .rotationEffect(.degrees(expanded ? 180 : 0)).frame(width: 24, height: 24)
                    }
                    .buttonStyle(PanelPressStyle()).help(expanded ? "Hide details" : "Show details")
                    .accessibilityLabel("\(expanded ? "Hide" : "Show") \(provider.displayName) details")
                }
            }
            .frame(height: 29)
            if let snapshot = state.snapshot {
                if let error = state.error { errorLabel("Stale · \(error)") }
                if snapshot.windows.isEmpty {
                    Text("Usage windows unavailable").font(.system(size: 11)).foregroundStyle(.secondary)
                }
                ForEach(Array(snapshot.windows.prefix(2).enumerated()), id: \.offset) { _, window in
                    QuotaRow(window: window, now: now)
                }
                if provider == .codex && !resetExtras.isEmpty && !expanded {
                    Text(resetExtras.map { "\($0.title): \($0.value)" }.joined(separator: "  ·  "))
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                        .lineLimit(1).padding(.top, 3)
                }
                if expanded {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(snapshot.windows.dropFirst(2).enumerated()), id: \.offset) { _, window in
                            QuotaRow(window: window, now: now)
                        }
                        ForEach(snapshot.extras.indices, id: \.self) { index in
                            HStack {
                                Text(snapshot.extras[index].title).foregroundStyle(.secondary)
                                Spacer()
                                Text(snapshot.extras[index].value)
                            }
                            .font(.system(size: 11))
                        }
                        Text("Updated \(snapshot.fetchedAt.formatted(date: .complete, time: .standard))")
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    .padding(.top, 6)
                }
            } else {
                if let error = state.error { errorLabel(error) }
                else {
                    Text("Click Refresh to check usage").font(.system(size: 11)).foregroundStyle(.secondary)
                }
                if provider == .claude && state.needsKeychainApproval {
                    Button("Connect Claude Keychain") { connect() }.buttonStyle(.bordered).controlSize(.small)
                        .padding(.top, 6)
                }
            }
        }
        .padding(.vertical, 7)
    }
    private func errorLabel(_ message: String) -> some View {
        Label {
            Text(message).foregroundStyle(.primary)
        } icon: {
            Image(systemName: "exclamationmark.circle.fill").foregroundStyle(PanelSurface.warning(scheme))
        }
        .font(.system(size: 11)).fixedSize(horizontal: false, vertical: true)
        .padding(.vertical, 3)
    }
}

private struct QuotaRow: View {
    let window: UsageWindow
    let now: Date
    @Environment(\.colorScheme) private var scheme
    private var used: Double? { window.usedPercent }
    private var meterColor: Color {
        guard let used else { return .accentColor }
        if used >= 95 { return .red }
        if used >= 80 { return PanelSurface.warning(scheme) }
        return Color(nsColor: .systemBlue)
    }
    var body: some View {
        VStack(spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(window.title).font(.system(size: 12)).lineLimit(1)
                Spacer(minLength: 4)
                Text(used == nil ? "Unknown usage" : "\(DisplayText.used(used)) used")
                    .font(.system(size: 12, weight: .semibold)).monospacedDigit().lineLimit(1)
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(nsColor: .quaternaryLabelColor).opacity(0.22))
                    if let used {
                        Capsule().fill(meterColor)
                            .frame(width: geometry.size.width * max(0, min(100, used)) / 100)
                    }
                }
            }
            .frame(height: 3).accessibilityHidden(true)
            HStack(spacing: 4) {
                Text(used == nil ? "Remaining unknown" : "\(DisplayText.remaining(used)) remaining")
                Spacer(minLength: 3)
                Image(systemName: "clock").accessibilityHidden(true)
                Text(DisplayText.reset(window.resetsAt, now: now))
                    .help(window.resetsAt?.formatted(date: .complete, time: .standard) ?? "Reset time unavailable")
            }
            .font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
        }
        .padding(.vertical, 5)
        .accessibilityElement(children: .combine)
    }
}

private struct SettingsView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text("Launch at login")
                        Spacer()
                        Toggle("Launch at login", isOn: Binding(
                            get: { model.loginStatus == "On" },
                            set: { model.setLaunchAtLogin($0) }
                        ))
                        .labelsHidden().toggleStyle(.switch)
                        .tint(Color(nsColor: .systemBlue))
                        .disabled(model.isDemo || model.loginStatus == "Available after installation")
                    }
                    Text(model.isDemo ? "Available in the installed app" : model.loginStatus)
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Divider()
                VStack(alignment: .leading, spacing: 12) {
                    Text("PROVIDERS").font(.system(size: 10, weight: .semibold)).tracking(0.7).foregroundStyle(.secondary)
                    ForEach(Provider.allCases) { provider in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                if let image = ProviderMark.image(for: provider) {
                                    Image(nsImage: image).resizable().interpolation(.high)
                                        .frame(width: 18, height: 18).accessibilityHidden(true)
                                }
                                Text(provider.displayName)
                                Spacer()
                                Toggle(provider.displayName, isOn: Binding(
                                    get: { model.enabled.contains(provider) },
                                    set: { model.setEnabled(provider, $0) }
                                ))
                                .labelsHidden().toggleStyle(.switch)
                                .tint(Color(nsColor: .systemBlue))
                            }
                            Text(provider.loginHelp).font(.system(size: 11)).foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if provider != Provider.allCases.last { Divider() }
                    }
                }
                Divider()
                VStack(alignment: .leading, spacing: 7) {
                    Text("KEYBOARD").font(.system(size: 10, weight: .semibold)).tracking(0.7).foregroundStyle(.secondary)
                    Text("Refresh  ⌘R       Settings  ⌘,       Quit  ⌘Q")
                    Text("Escape returns to usage or closes the menu.")
                }
                .font(.system(size: 11)).foregroundStyle(.secondary)
                Link("Source code  ↗", destination: URL(string: "https://github.com/odaofficial/quotabar")!)
                    .font(.system(size: 11))
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
    }
}
