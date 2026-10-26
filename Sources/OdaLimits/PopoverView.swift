import AppKit
import OdaLimitsCore
import SwiftUI

enum PanelMetrics {
    static let width: CGFloat = 420
    static let height: CGFloat = 660
}

private enum PanelSurface {
    static func shell(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.125, green: 0.125, blue: 0.133) : Color(red: 0.953, green: 0.953, blue: 0.961)
    }
    static func card(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.173, green: 0.173, blue: 0.180) : .white
    }
    static func warning(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 1, green: 0.72, blue: 0.37) : Color(red: 0.59, green: 0.30, blue: 0)
    }
}

struct PopoverView: View {
    @ObservedObject var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    private var lastCheckText: String {
        guard let date = model.enabled.compactMap({ model.states[$0]?.checkedAt }).max() else { return "Not checked yet" }
        let hasStale = model.enabled.contains { model.states[$0]?.snapshot != nil && model.states[$0]?.error != nil }
        let hasFailure = model.enabled.contains { model.states[$0]?.error != nil }
        let suffix = hasStale ? " · some data stale" : (hasFailure ? " · check issues" : "")
        return "Checked \(date.formatted(date: .omitted, time: .shortened))\(suffix)"
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Rectangle().fill(Color(nsColor: .separatorColor).opacity(0.5)).frame(height: 0.5)
            Group {
                if model.showingSettings { SettingsView(model: model) }
                else { summary }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            Rectangle().fill(Color(nsColor: .separatorColor).opacity(0.5)).frame(height: 0.5)
            footer
        }
        .frame(width: PanelMetrics.width, height: PanelMetrics.height)
        .background {
            if model.isDemo { PanelSurface.shell(colorScheme) }
            else { Rectangle().fill(.regularMaterial) }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: model.showingSettings)
    }

    private var header: some View {
        HStack(spacing: 12) {
            if model.showingSettings {
                PanelIconButton(symbol: "chevron.left", title: "Back to usage", hint: "Esc") { model.showingSettings = false }
            } else {
                Image(nsImage: OdaMark.image)
                    .frame(width: 20, height: 18)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(model.showingSettings ? "Settings" : "Oda Limits")
                    .font(.system(size: 20, weight: .semibold))
                Text(model.showingSettings ? "Make this menu yours" : "Your usage at a glance")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if model.isDemo {
                Text("SAMPLE").font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(0.6).foregroundStyle(.secondary)
                    .padding(.horizontal, 7).padding(.vertical, 4)
                    .background(Color(nsColor: .quaternaryLabelColor).opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
            }
            if !model.showingSettings {
                if model.isRefreshing { ProgressView().controlSize(.small).accessibilityLabel("Refreshing usage") }
                PanelIconButton(symbol: "arrow.clockwise", title: "Refresh usage", hint: "⌘R") { model.refresh() }
                    .disabled(model.isDemo || model.isRefreshing)
                PanelIconButton(symbol: "gearshape", title: "Settings", hint: "⌘,") { model.showingSettings = true }
            }
        }
        .padding(.horizontal, 16).frame(height: 68)
    }

    private var summary: some View {
        ScrollView {
            if model.enabled.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "rectangle.stack.badge.plus")
                        .font(.system(size: 28)).foregroundStyle(.secondary)
                    Text("No providers selected").font(.system(size: 15, weight: .semibold))
                    Text("Choose the services you want to see here.")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                    Button("Open Settings") { model.showingSettings = true }
                        .buttonStyle(.borderedProminent).controlSize(.small)
                }
                .frame(maxWidth: .infinity).padding(.top, 145)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(Provider.allCases) { provider in
                        if model.enabled.contains(provider) {
                            ProviderCard(provider: provider, state: model.states[provider] ?? ProviderState(), now: model.now,
                                         connect: { model.connectClaude() }, initiallyExpanded: model.demoScenario == .expanded)
                        }
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 8)
            }
        }
        .scrollIndicators(.hidden)
    }

    private var footer: some View {
        HStack {
            Text(model.isDemo ? "Sample data" : "\(lastCheckText) · manual refresh")
                .foregroundStyle(.secondary).lineLimit(1)
            Spacer(minLength: 8)
            PanelIconButton(symbol: "power", title: "Quit Oda Limits", hint: "⌘Q") {
                NSApplication.shared.terminate(nil)
            }
        }
        .font(.system(size: 11))
        .padding(.horizontal, 16).frame(height: 36)
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
                .background(hovered || focused ? Color(nsColor: .quaternaryLabelColor).opacity(0.18) : Color.clear,
                            in: RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(focused ? Color.accentColor : .clear, lineWidth: 1.5))
        }
        .buttonStyle(PanelPressStyle()).onHover { hovered = $0 }.focused($focused)
        .help("\(title) (\(hint))").accessibilityLabel(title)
    }
}

private struct PanelPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.55 : 1)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
    }
}

private struct WarningLabelStyle: LabelStyle {
    let color: Color
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            configuration.icon.foregroundStyle(color)
            configuration.title.foregroundStyle(.primary)
        }
    }
}

private struct ProviderCard: View {
    let provider: Provider
    let state: ProviderState
    let now: Date
    let connect: () -> Void
    @State private var expanded = false
    let initiallyExpanded: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast

    private var symbol: String {
        switch provider {
        case .codex: "terminal"
        case .claude: "asterisk"
        case .cursor: "cursorarrow"
        case .grok: "sparkle"
        }
    }
    private var resetExtras: [UsageExtra] {
        state.snapshot?.extras.filter { $0.title.localizedCaseInsensitiveContains("reset") || $0.title == "Applicable now" } ?? []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 9) {
                Group {
                    if let image = ProviderMark.image(for: provider) {
                        Image(nsImage: image).resizable().interpolation(.high)
                            .frame(width: 24, height: 24)
                    } else {
                        Image(systemName: symbol).font(.system(size: 18, weight: .medium))
                            .frame(width: 24, height: 24)
                    }
                }
                .frame(width: 28, height: 28)
                .help(provider.displayName)
                .accessibilityLabel(provider.displayName)
                if let plan = state.snapshot?.plan {
                    Text(plan).font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer(minLength: 4)
                Link(destination: provider.dashboardURL) {
                    Image(systemName: "arrow.up.right.square").frame(width: 24, height: 24)
                }
                .buttonStyle(.plain).help("Open \(provider.displayName) dashboard")
                .accessibilityLabel("Open \(provider.displayName) dashboard")
                if state.snapshot != nil {
                    Button {
                        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { expanded.toggle() }
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                            .rotationEffect(.degrees(expanded ? 180 : 0))
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain).help(expanded ? "Hide details" : "Show details")
                    .accessibilityLabel("\(expanded ? "Hide" : "Show") \(provider.displayName) details")
                }
            }
            if let snapshot = state.snapshot {
                if let error = state.error {
                    Label("Stale · \(error)", systemImage: "exclamationmark.circle")
                        .font(.system(size: 11)).foregroundStyle(.primary)
                        .labelStyle(WarningLabelStyle(color: PanelSurface.warning(colorScheme)))
                        .fixedSize(horizontal: false, vertical: true)
                }
                if snapshot.windows.isEmpty {
                    Text("Usage windows unavailable").font(.system(size: 12)).foregroundStyle(.secondary)
                } else if snapshot.windows.count == 1 {
                    CompactAllowanceView(window: snapshot.windows[0], now: now)
                } else {
                    HStack(alignment: .top, spacing: 8) {
                        ForEach(snapshot.windows.prefix(2).indices, id: \.self) { index in
                            AllowanceView(window: snapshot.windows[index], now: now)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                if provider == .codex && !resetExtras.isEmpty && !expanded {
                    Text(resetExtras.map { "\($0.title): \($0.value)" }.joined(separator: "  ·  "))
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                        .lineLimit(1).help(snapshot.extras.map { "\($0.title): \($0.value)" }.joined(separator: ", "))
                }
                if expanded {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(snapshot.windows.indices.dropFirst(2)), id: \.self) { index in
                            AllowanceView(window: snapshot.windows[index], now: now)
                        }
                        ForEach(snapshot.extras.indices, id: \.self) { index in
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(snapshot.extras[index].title).foregroundStyle(.secondary)
                                Spacer(minLength: 8)
                                Text(snapshot.extras[index].value).multilineTextAlignment(.trailing)
                            }
                            .font(.system(size: 11)).fixedSize(horizontal: false, vertical: true)
                        }
                        Text("Updated \(snapshot.fetchedAt.formatted(date: .complete, time: .standard))")
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    .padding(.top, 6)
                    .overlay(alignment: .top) { Divider() }
                }
            } else {
                Label(state.error ?? "Click Refresh to check usage", systemImage: state.error == nil ? "arrow.clockwise" : "exclamationmark.circle")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if provider == .claude && state.error != nil {
                    Button("Connect Claude Keychain") { connect() }
                        .buttonStyle(.bordered).controlSize(.small)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PanelSurface.card(colorScheme), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color(nsColor: .separatorColor).opacity(contrast == .increased ? 1 : 0.5), lineWidth: 0.5))
        .onAppear { expanded = initiallyExpanded }
    }
}

private struct CompactAllowanceView: View {
    let window: UsageWindow
    let now: Date
    @Environment(\.colorScheme) private var colorScheme
    private var remaining: Double? { window.remainingPercent }
    private var low: Bool { (remaining ?? 101) < 20 }
    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(window.title).font(.system(size: 11)).foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(DisplayText.percent(window.usedPercent))
                        .font(.system(size: 22, weight: .semibold, design: .rounded)).monospacedDigit()
                        .foregroundStyle(low ? PanelSurface.warning(colorScheme) : Color.primary)
                    if remaining != nil { Text("left").font(.system(size: 11)).foregroundStyle(.secondary) }
                }
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 7) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color(nsColor: .quaternaryLabelColor).opacity(0.22))
                        if let remaining {
                            Capsule().fill(low ? PanelSurface.warning(colorScheme) : Color.accentColor)
                                .frame(width: geometry.size.width * max(0, min(100, remaining)) / 100)
                        }
                    }
                }
                .frame(height: 3).accessibilityHidden(true)
                Text(DisplayText.reset(window.resetsAt, now: now))
                    .font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                    .help(window.resetsAt?.formatted(date: .complete, time: .standard) ?? "Reset time unavailable")
            }
            .frame(width: 175)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(window.title), \(DisplayText.percent(window.usedPercent)) remaining, \(DisplayText.reset(window.resetsAt, now: now))")
    }
}

private struct AllowanceView: View {
    let window: UsageWindow
    let now: Date
    @Environment(\.colorScheme) private var colorScheme
    private var remaining: Double? { window.remainingPercent }
    private var low: Bool { (remaining ?? 101) < 20 }
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(window.title).font(.system(size: 11)).foregroundStyle(.secondary)
                .lineLimit(1).help(window.title)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(DisplayText.percent(window.usedPercent))
                    .font(.system(size: 22, weight: .semibold, design: .rounded)).monospacedDigit()
                    .foregroundStyle(low ? PanelSurface.warning(colorScheme) : Color.primary)
                    .minimumScaleFactor(0.75).lineLimit(1)
                if remaining != nil { Text("left").font(.system(size: 11)).foregroundStyle(.secondary) }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(window.title), \(DisplayText.percent(window.usedPercent)) remaining")
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(nsColor: .quaternaryLabelColor).opacity(0.22))
                    if let remaining {
                        Capsule().fill(low ? PanelSurface.warning(colorScheme) : Color.accentColor)
                            .frame(width: geometry.size.width * max(0, min(100, remaining)) / 100)
                    }
                }
            }
            .frame(height: 3)
            .accessibilityHidden(true)
            Text(DisplayText.reset(window.resetsAt, now: now))
                .font(.system(size: 11)).foregroundStyle(.secondary)
                .lineLimit(1)
                .help(window.resetsAt?.formatted(date: .complete, time: .standard) ?? "Reset time unavailable")
        }
    }
}

private struct SettingsView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Launch at login")
                        Spacer()
                        Toggle("Launch at login", isOn: Binding(
                            get: { model.loginStatus == "On" },
                            set: { model.setLaunchAtLogin($0) }
                        ))
                        .labelsHidden().toggleStyle(.switch)
                        .disabled(model.isDemo || model.loginStatus == "Available after installation")
                    }
                    Text(model.isDemo ? "Available in the installed app" : model.loginStatus)
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
                .settingsGroup()

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
                            }
                            Text(provider.loginHelp).font(.system(size: 11)).foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if provider != Provider.allCases.last { Divider() }
                    }
                }
                .settingsGroup()
                VStack(alignment: .leading, spacing: 8) {
                    Text("KEYBOARD").font(.system(size: 10, weight: .semibold)).tracking(0.7).foregroundStyle(.secondary)
                    Text("Refresh  ⌘R       Settings  ⌘,       Quit  ⌘Q")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                    Text("Escape returns to usage or closes the menu.")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
                .settingsGroup()
                Link("Source code  ↗", destination: URL(string: "https://github.com/odaofficial/oda-limits")!)
                    .font(.system(size: 11))
            }
            .padding(16)
        }
        .scrollIndicators(.hidden)
    }
}

private extension View {
    func settingsGroup() -> some View {
        modifier(SettingsGroupStyle())
    }
}

private struct SettingsGroupStyle: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    func body(content: Content) -> some View {
        content.padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(PanelSurface.card(colorScheme), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color(nsColor: .separatorColor).opacity(contrast == .increased ? 1 : 0.5), lineWidth: 0.5))
    }
}
