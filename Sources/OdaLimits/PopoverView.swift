import AppKit
import OdaLimitsCore
import SwiftUI

struct PopoverView: View {
    @ObservedObject var model: AppModel
    private var lastCheckText: String {
        guard let date = model.states.values.compactMap(\.checkedAt).max() else { return "pending" }
        return date.formatted(date: .omitted, time: .shortened)
    }
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "gauge.medium").font(.system(size: 17, weight: .semibold))
                Text("Oda Limits").font(.system(size: 17, weight: .semibold))
                if model.isDemo { Text("DEMO").font(.system(size: 9, weight: .bold)).padding(.horizontal, 5).padding(.vertical, 2).background(.quaternary, in: Capsule()) }
                Spacer()
                if model.isRefreshing { ProgressView().controlSize(.small).accessibilityLabel("Refreshing usage") }
                Button { model.refresh(manual: true) } label: { Image(systemName: "arrow.clockwise") }
                    .buttonStyle(.borderless).disabled(model.isDemo || model.isRefreshing).help("Refresh usage")
                    .accessibilityLabel("Refresh usage")
            }
            .padding(.horizontal, 18).padding(.vertical, 14)
            Divider()
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(Provider.allCases) { provider in
                        if model.enabled.contains(provider) {
                            ProviderCard(provider: provider, state: model.states[provider] ?? ProviderState(), now: model.now,
                                         connect: { model.connectClaude() })
                        }
                    }
                }
                .padding(12)
            }
            Divider()
            HStack {
                Text(model.isDemo ? "Synthetic sample" : "Last check \(lastCheckText) · every 5 min")
                    .foregroundStyle(.secondary)
                Spacer()
                Button(model.showingSettings ? "Usage" : "Settings") { model.showingSettings.toggle() }
                    .buttonStyle(.borderless)
                Button("Quit") { NSApplication.shared.terminate(nil) }.buttonStyle(.borderless)
            }
            .font(.caption)
            .padding(.horizontal, 18).padding(.vertical, 11)
        }
        .frame(width: 420, height: 620)
        .overlay {
            if model.showingSettings { SettingsView(model: model).background(.regularMaterial) }
        }
    }
}

private struct ProviderCard: View {
    let provider: Provider
    let state: ProviderState
    let now: Date
    let connect: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline) {
                Text(provider.displayName).font(.headline)
                if let plan = state.snapshot?.plan { Text(plan.capitalized).font(.caption).foregroundStyle(.secondary) }
                Spacer()
                Link(destination: provider.dashboardURL) { Image(systemName: "arrow.up.right.square") }
                    .accessibilityLabel("Open \(provider.displayName) dashboard")
            }
            if let snapshot = state.snapshot {
                if let error = state.error {
                    Label("Stale · \(error)", systemImage: "exclamationmark.circle")
                        .font(.caption).foregroundStyle(.orange)
                }
                if snapshot.windows.isEmpty { Text("Usage windows unavailable").font(.caption).foregroundStyle(.secondary) }
                ForEach(Array(snapshot.windows.enumerated()), id: \.offset) { _, window in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(window.title).font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Text(DisplayText.percent(window.usedPercent) + " remaining").font(.caption).fontWeight(.medium)
                        }
                        if let remaining = window.remainingPercent {
                            ProgressView(value: remaining, total: 100)
                                .tint(.primary)
                                .accessibilityLabel("\(window.title), \(DisplayText.percent(window.usedPercent)) remaining")
                        }
                        Text(DisplayText.reset(window.resetsAt, now: now))
                            .font(.caption2).foregroundStyle(.secondary)
                            .help(window.resetsAt?.formatted(date: .complete, time: .shortened) ?? "Reset time unavailable")
                    }
                }
                if !snapshot.extras.isEmpty {
                    HStack(spacing: 12) {
                        ForEach(snapshot.extras.indices, id: \.self) { index in
                            let extra = snapshot.extras[index]
                            Text("\(extra.title): \(extra.value)").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    .lineLimit(2)
                }
                Text("Updated \(snapshot.fetchedAt.formatted(date: .omitted, time: .shortened))")
                    .font(.caption2).foregroundStyle(.tertiary)
            } else {
                Text(state.error ?? provider.loginHelp).font(.caption).foregroundStyle(.secondary)
                if provider == .claude {
                    Button("Connect Claude Keychain") { connect() }.controlSize(.small)
                }
            }
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color(nsColor: .separatorColor).opacity(0.65)))
    }
}

private struct SettingsView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Settings").font(.headline)
                Spacer()
                Button("Done") { model.showingSettings = false }.buttonStyle(.borderless)
            }
            Toggle("Launch at login", isOn: Binding(
                get: { model.loginStatus == "On" },
                set: { model.setLaunchAtLogin($0) }
            ))
            .disabled(model.isDemo || model.loginStatus == "Available after installation")
            Text(model.loginStatus).font(.caption).foregroundStyle(.secondary)
            Divider()
            Text("Providers").font(.subheadline).fontWeight(.semibold)
            ForEach(Provider.allCases) { provider in
                HStack {
                    Toggle(provider.displayName, isOn: Binding(
                        get: { model.enabled.contains(provider) },
                        set: { model.setEnabled(provider, $0) }
                    ))
                    Link("Dashboard", destination: provider.dashboardURL).font(.caption)
                }
                Text(provider.loginHelp).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Link("Source code", destination: URL(string: "https://github.com/odaofficial/oda-limits")!)
                .font(.caption)
        }
        .padding(18)
        .frame(width: 420, height: 620)
    }
}
