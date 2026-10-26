import AppKit
import Foundation
import QuotaBarCore
import SwiftUI

@MainActor final class MenuBarDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private let model: AppModel
    private let showInitially: Bool
    private let smokeTest: Bool
    private let interactionSmokeTest: Bool
    private var didFinishLaunch = false
    private var statusItem: NSStatusItem?
    private let popover = NSPopover()
    private var keyMonitor: Any?
    init(demo: Bool, show: Bool, smokeTest: Bool, interactionSmokeTest: Bool) {
        model = AppModel(demo: demo)
        showInitially = show
        self.smokeTest = smokeTest
        self.interactionSmokeTest = interactionSmokeTest
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = QuotaMark.image
            button.action = #selector(togglePopover)
            button.target = self
            button.toolTip = "QuotaBar"
        }
        popover.behavior = .transient
        popover.delegate = self
        popover.contentSize = NSSize(width: PanelMetrics.width, height: PanelMetrics.height)
        popover.contentViewController = NSHostingController(rootView: PopoverView(model: model))
        model.start()
        didFinishLaunch = true
        if showInitially || interactionSmokeTest {
            Timer.scheduledTimer(withTimeInterval: 0.15, repeats: false) { [weak self] _ in
                Task { @MainActor in self?.togglePopover() }
            }
        }
        if interactionSmokeTest { runInteractionSmokeTest() }
        if smokeTest {
            Timer.scheduledTimer(withTimeInterval: 2, repeats: false) { [weak self] _ in
                Task { @MainActor in
                    guard let self else { return }
                    let width = Int(self.popover.contentSize.width)
                    let height = Int(self.popover.contentSize.height)
                    let checks = self.model.states.values.filter { $0.checkedAt != nil }.count
                    print("smoke: launch=\(self.didFinishLaunch ? "ok" : "failed") statusItem=\(self.statusItem?.button != nil ? "ok" : "missing") hostingView=\(self.popover.contentViewController != nil ? "ok" : "missing") size=\(width)x\(height) checks=\(checks) login=\(self.model.loginStatus)")
                    fflush(stdout)
                    NSApplication.shared.terminate(nil)
                }
            }
        }
    }
    @objc private func togglePopover() {
        guard let button = statusItem?.button else { return }
        if popover.isShown { popover.close(); model.setPopoverVisible(false); removeKeyMonitor() }
        else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApplication.shared.activate(ignoringOtherApps: true)
            popover.contentViewController?.view.window?.makeKeyAndOrderFront(nil)
            model.setPopoverVisible(true)
            installKeyMonitor()
        }
    }
    func popoverDidClose(_ notification: Notification) { model.setPopoverVisible(false); removeKeyMonitor() }

    private func installKeyMonitor() {
        removeKeyMonitor()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.popover.isShown,
                  let window = self.popover.contentViewController?.view.window,
                  event.windowNumber == window.windowNumber, window.isKeyWindow else { return event }
            let command = event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.command)
            if command {
                switch event.charactersIgnoringModifiers?.lowercased() {
                case "r": self.model.refresh(); return nil
                case ",": self.model.showingSettings = true; return nil
                case "q": NSApplication.shared.terminate(nil); return nil
                default: break
                }
            } else if event.keyCode == 53 {
                if self.model.showingSettings { self.model.showingSettings = false }
                else { DispatchQueue.main.async { self.popover.close() } }
                return nil
            }
            return event
        }
    }
    private func removeKeyMonitor() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor); self.keyMonitor = nil }
    }

    private func runInteractionSmokeTest() {
        Timer.scheduledTimer(withTimeInterval: 0.4, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                let window = self.popover.contentViewController?.view.window
                let key = window?.isKeyWindow == true
                let shown = self.popover.isShown
                let windowPresent = window != nil
                let appActive = NSApplication.shared.isActive
                let anchorPresent = self.statusItem?.button?.window != nil
                self.sendSmokeKey(",", code: 43, command: true)
                let settings = self.model.showingSettings
                self.sendSmokeKey("\u{1b}", code: 53)
                let back = !self.model.showingSettings && self.popover.isShown
                self.sendSmokeKey("\u{1b}", code: 53)
                Timer.scheduledTimer(withTimeInterval: 2, repeats: false) { [weak self] _ in
                    Task { @MainActor in
                        guard let self else { return }
                        let dismissed = !self.popover.isShown
                        print("interaction: anchor=\(anchorPresent) shown=\(shown) window=\(windowPresent) appActive=\(appActive) keyWindow=\(key) settings=\(settings) escapeBack=\(back) escapeDismiss=\(dismissed)")
                        fflush(stdout)
                        NSApplication.shared.terminate(nil)
                    }
                }
            }
        }
    }
    private func sendSmokeKey(_ characters: String, code: UInt16, command: Bool = false) {
        guard let window = popover.contentViewController?.view.window,
              let event = NSEvent.keyEvent(with: .keyDown, location: .zero,
                                           modifierFlags: command ? [.command] : [], timestamp: 0,
                                           windowNumber: window.windowNumber, context: nil,
                                           characters: characters, charactersIgnoringModifiers: characters,
                                           isARepeat: false, keyCode: code) else { return }
        NSApplication.shared.sendEvent(event)
    }
}

@main enum QuotaBarMain {
    @MainActor static func main() async {
        let args = Array(CommandLine.arguments.dropFirst())
        let arguments = Set(args)
        if arguments.contains("--diagnostics") { await diagnostics(); return }
        if let index = args.firstIndex(of: "--render-demo") {
            guard args.indices.contains(index + 1) else { fputs("usage: QuotaBar --render-demo <png-path>\n", stderr); exit(2) }
            let appearance = args.firstIndex(of: "--appearance").flatMap { args.indices.contains($0 + 1) ? args[$0 + 1] : nil } ?? "light"
            guard ["light", "dark"].contains(appearance) else { fputs("appearance must be light or dark\n", stderr); exit(2) }
            var scenario: DemoScenario = .connected
            if let scenarioIndex = args.firstIndex(of: "--scenario") {
                guard args.indices.contains(scenarioIndex + 1), let selected = DemoScenario(rawValue: args[scenarioIndex + 1]) else {
                    fputs("scenario must be connected, mixed, empty, expanded, initial, failed, or keychain\n", stderr); exit(2)
                }
                scenario = selected
            }
            do { try renderDemo(to: URL(fileURLWithPath: args[index + 1]), appearance: appearance, scenario: scenario, settings: arguments.contains("--settings")) }
            catch { fputs("demo render failed\n", stderr); exit(1) }
            return
        }
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let delegate = MenuBarDelegate(demo: arguments.contains("--demo") || arguments.contains("--interaction-smoke-test"),
                                       show: arguments.contains("--show"), smokeTest: arguments.contains("--smoke-test"),
                                       interactionSmokeTest: arguments.contains("--interaction-smoke-test"))
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
    @MainActor private static func renderDemo(to url: URL, appearance: String, scenario: DemoScenario, settings: Bool) throws {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let model = AppModel(demo: true, scenario: scenario)
        model.showingSettings = settings
        let view = NSHostingView(rootView: PopoverView(model: model)
            .preferredColorScheme(appearance == "dark" ? .dark : .light)
            .environment(\.controlActiveState, .active))
        let bounds = NSRect(x: 0, y: 0, width: PanelMetrics.width, height: PanelMetrics.height)
        let window = NSWindow(contentRect: bounds, styleMask: .borderless, backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: appearance == "dark" ? .darkAqua : .aqua)
        window.backgroundColor = NSColor.windowBackgroundColor
        window.contentView = view
        view.frame = bounds
        view.layoutSubtreeIfNeeded()
        view.displayIfNeeded()
        guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(PanelMetrics.width * 2),
                                            pixelsHigh: Int(PanelMetrics.height * 2), bitsPerSample: 8,
                                            samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { throw ProviderError.invalidResponse }
        bitmap.size = bounds.size
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
