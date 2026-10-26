import AppKit
import Foundation
import OdaLimitsCore
import SwiftUI

@MainActor final class MenuBarDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private let model: AppModel
    private let showInitially: Bool
    private var statusItem: NSStatusItem?
    private let popover = NSPopover()
    init(demo: Bool, show: Bool) {
        model = AppModel(demo: demo)
        showInitially = show
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "gauge.medium", accessibilityDescription: "Oda Limits")
            button.image?.isTemplate = true
            button.action = #selector(togglePopover)
            button.target = self
            button.toolTip = "Oda Limits"
        }
        popover.behavior = .transient
        popover.delegate = self
        popover.contentSize = NSSize(width: 420, height: 620)
        popover.contentViewController = NSHostingController(rootView: PopoverView(model: model))
        model.start()
        if showInitially { togglePopover() }
    }
    @objc private func togglePopover() {
        guard let button = statusItem?.button else { return }
        if popover.isShown { popover.performClose(nil); model.setPopoverVisible(false) }
        else { popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY); model.setPopoverVisible(true) }
    }
    func popoverDidClose(_ notification: Notification) { model.setPopoverVisible(false) }
}

@main enum OdaLimitsMain {
    @MainActor static func main() async {
        let arguments = Set(CommandLine.arguments.dropFirst())
        if arguments.contains("--diagnostics") { await diagnostics(); return }
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let delegate = MenuBarDelegate(demo: arguments.contains("--demo"), show: arguments.contains("--show"))
        app.delegate = delegate
        app.run()
    }
    private static func diagnostics() async {
        for provider in Provider.allCases {
            do {
                let (snapshot, _) = try await ProviderClient.fetch(provider)
                let windows = snapshot.windows.map { window in
                    "\(window.title): \(window.usedPercent.map { String(format: "%.3f%% used", $0) } ?? "unknown"), reset \(window.resetsAt?.formatted(.iso8601) ?? "unknown")"
                }.joined(separator: "; ")
                print("\(provider.displayName): connected; plan \(snapshot.plan ?? "unknown"); \(windows)")
            } catch let error as ProviderError {
                print("\(provider.displayName): \(error.localizedDescription)")
            } catch {
                print("\(provider.displayName): unavailable")
            }
        }
    }
}
