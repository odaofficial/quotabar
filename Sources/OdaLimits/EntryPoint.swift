import AppKit
import Foundation
import OdaLimitsCore
import SwiftUI

@MainActor final class MenuBarDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private let model: AppModel
    private let showInitially: Bool
    private let smokeTest: Bool
    private var didFinishLaunch = false
    private var statusItem: NSStatusItem?
    private let popover = NSPopover()
    init(demo: Bool, show: Bool, smokeTest: Bool) {
        model = AppModel(demo: demo)
        showInitially = show
        self.smokeTest = smokeTest
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
        didFinishLaunch = true
        if showInitially { togglePopover() }
        if smokeTest {
            Timer.scheduledTimer(withTimeInterval: 2, repeats: false) { [weak self] _ in
                Task { @MainActor in
                    guard let self else { return }
                    let width = Int(self.popover.contentSize.width)
                    let height = Int(self.popover.contentSize.height)
                    print("smoke: launch=\(self.didFinishLaunch ? "ok" : "failed") statusItem=\(self.statusItem?.button != nil ? "ok" : "missing") hostingView=\(self.popover.contentViewController != nil ? "ok" : "missing") size=\(width)x\(height) login=\(self.model.loginStatus)")
                    fflush(stdout)
                    NSApplication.shared.terminate(nil)
                }
            }
        }
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
        let args = Array(CommandLine.arguments.dropFirst())
        let arguments = Set(args)
        if arguments.contains("--diagnostics") { await diagnostics(); return }
        if let index = args.firstIndex(of: "--render-demo") {
            guard args.indices.contains(index + 1) else { fputs("usage: OdaLimits --render-demo <png-path>\n", stderr); exit(2) }
            do { try renderDemo(to: URL(fileURLWithPath: args[index + 1])) }
            catch { fputs("demo render failed\n", stderr); exit(1) }
            return
        }
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let delegate = MenuBarDelegate(demo: arguments.contains("--demo"), show: arguments.contains("--show"), smokeTest: arguments.contains("--smoke-test"))
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
    @MainActor private static func renderDemo(to url: URL) throws {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let view = NSHostingView(rootView: PopoverView(model: AppModel(demo: true)))
        let bounds = NSRect(x: 0, y: 0, width: 420, height: 620)
        let window = NSWindow(contentRect: bounds, styleMask: .borderless, backing: .buffered, defer: false)
        window.contentView = view
        view.frame = bounds
        view.layoutSubtreeIfNeeded()
        view.displayIfNeeded()
        guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { throw ProviderError.invalidResponse }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        guard let png = bitmap.representation(using: .png, properties: [:]) else { throw ProviderError.invalidResponse }
        try png.write(to: url)
        print("demo render: \(Int(view.bounds.width))x\(Int(view.bounds.height))")
        withExtendedLifetime(window) {}
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
