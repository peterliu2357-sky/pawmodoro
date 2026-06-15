import AppKit
import PawmodoroKit
import ServiceManagement
import SwiftUI

/// Menu-bar presentation for the Work → Pounce → Rest loop. Holds the pure
/// Session Engine and a Coverage Orchestrator, translating engine state into a
/// status-item countdown, a menu, and (during a Rest) one cat Visual per
/// display. This layer is verified by manual QA; the behavior it drives lives in
/// (and is tested through) `SessionEngine` and `CoverageOrchestrator`.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var engine = SessionEngine(clock: SystemClock())
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let displayProvider = ScreenDisplayProvider()
    private var coverage: CoverageOrchestrator?
    private var timer: Timer?

    private let settingsStore = SettingsStore(persistence: UserDefaultsSettingsPersistence())
    private var settingsWindow: NSWindow?

    private let startItem = NSMenuItem(title: "Start", action: #selector(start), keyEquivalent: "")
    private let stopItem = NSMenuItem(title: "Stop", action: #selector(stop), keyEquivalent: "")

    func applicationDidFinishLaunching(_ notification: Notification) {
        coverage = CoverageOrchestrator(
            displayProvider: displayProvider,
            onShoo: { [weak self] in self?.resolveShoo() ?? .snappedBack },
            makeVisual: { [weak self] id, shoo in
                self?.makeVisual(for: id, onShoo: shoo) ?? VisualWindowController(screen: NSScreen.screens[0], onShoo: shoo)
            }
        )

        buildMenu()
        render()

        // Drives the wall-clock state machine. A coarse cadence is fine: the
        // countdown is recomputed from the clock, so it never drifts.
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer

        // A monitor was plugged in or removed — update the cat set mid-Rest.
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.coverage?.displaysChanged() }
        }
    }

    private func buildMenu() {
        let menu = NSMenu()
        startItem.target = self
        stopItem.target = self
        menu.addItem(startItem)
        menu.addItem(stopItem)
        menu.addItem(.separator())
        let settings = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        let quit = NSMenuItem(title: "Quit Pawmodoro", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
        statusItem.menu = menu
    }

    // MARK: - Menu actions

    @objc private func start() {
        // Apply the latest configured durations to this fresh session.
        let settings = settingsStore.settings
        engine.configure(workDuration: settings.workDuration, restDuration: settings.restDuration)
        engine.start()
        render()
    }

    @objc private func stop() {
        engine.stop()
        render()
    }

    // MARK: - Settings

    @objc private func openSettings() {
        if settingsWindow == nil {
            let view = SettingsView(settings: settingsStore.settings) { [weak self] edited in
                self?.applySettings(edited)
            }
            let window = NSWindow(contentViewController: NSHostingController(rootView: view))
            window.title = "Pawmodoro Settings"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            settingsWindow = window
        }
        // The user opened this window explicitly, so it's fine to come forward
        // and take key focus — ADR-0001 governs the Rest coverage, not Settings.
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.center()
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    /// Persists the edited settings and reconciles the login item. Durations are
    /// not pushed into a running session — they're picked up by the next `start`.
    private func applySettings(_ settings: PomodoroSettings) {
        settingsStore.update(settings)
        applyLaunchAtLogin(settings.launchAtLogin)
    }

    private func applyLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Pawmodoro: failed to update launch-at-login: \(error)")
        }
    }

    // MARK: - Loop

    private func tick() {
        engine.poll()
        render()
    }

    /// A cat was flicked off an edge. The engine accepts the Shoo only if the
    /// Rest has completed; otherwise it snaps back and the Rest continues. The
    /// Orchestrator clears the cats on the other displays when this is accepted.
    private func resolveShoo() -> ShooOutcome {
        let outcome = engine.attemptShoo()
        renderStatus()
        return outcome
    }

    private func makeVisual(for id: DisplayID, onShoo: @escaping () -> ShooOutcome) -> CoverageVisual {
        let screen = NSScreen.screens.first { $0.pawDisplayID == id } ?? NSScreen.main ?? NSScreen.screens[0]
        return VisualWindowController(screen: screen, onShoo: onShoo)
    }

    // MARK: - Rendering

    /// Single source of truth: reconcile the UI with the engine's state — the
    /// status item, and Coverage (one cat per display during a Rest, none else).
    private func render() {
        renderStatus()
        coverage?.update(covering: isResting)
    }

    private var isResting: Bool {
        if case .resting = engine.state { return true }
        return false
    }

    private func renderStatus() {
        switch engine.state {
        case .idle:
            statusItem.button?.title = "🐾"
            startItem.isEnabled = true
            stopItem.isEnabled = false
        case .working:
            statusItem.button?.title = format(engine.remaining())
            startItem.isEnabled = false
            stopItem.isEnabled = true
        case .resting:
            statusItem.button?.title = "😺 " + format(engine.restRemaining())
            startItem.isEnabled = false
            stopItem.isEnabled = true
        }
    }

    private func format(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded(.up))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}

/// The connected displays, read from AppKit. The Orchestrator depends only on
/// the `DisplayProvider` protocol, never on this type.
@MainActor
final class ScreenDisplayProvider: DisplayProvider {
    var displays: [DisplayID] { NSScreen.screens.compactMap(\.pawDisplayID) }
}

extension NSScreen {
    /// The stable Core Graphics display identifier for this screen, if available.
    var pawDisplayID: DisplayID? {
        guard let number = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return nil }
        return DisplayID(number.uint32Value)
    }
}
