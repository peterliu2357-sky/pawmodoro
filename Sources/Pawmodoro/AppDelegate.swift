import AppKit
import Carbon.HIToolbox
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
    private var emergencyHotKey: GlobalHotKey?

    private let startItem = NSMenuItem(title: "Start", action: #selector(start), keyEquivalent: "")
    private let stopItem = NSMenuItem(title: "Stop", action: #selector(stop), keyEquivalent: "")
    private let pauseItem = NSMenuItem(title: "Pause", action: #selector(pauseOrResume), keyEquivalent: "")
    private let restNowItem = NSMenuItem(title: "Take a Rest Now", action: #selector(takeRestNow), keyEquivalent: "")
    private let emergencyItem = NSMenuItem(title: "Emergency Shoo", action: #selector(emergencyShoo), keyEquivalent: ".")

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

        // The Emergency Shoo: a permission-free system-wide ⌃⌥⌘. that force-ends
        // a Rest from any app, so the user is never truly trapped.
        emergencyHotKey = GlobalHotKey(
            keyCode: UInt32(kVK_ANSI_Period),
            modifiers: UInt32(controlKey | optionKey | cmdKey)
        ) { [weak self] in self?.emergencyShoo() }
    }

    private func buildMenu() {
        let menu = NSMenu()
        // renderStatus drives every item's enabled state by hand; without this,
        // AppKit auto-enables anything whose target responds to its action.
        menu.autoenablesItems = false
        startItem.target = self
        stopItem.target = self
        pauseItem.target = self
        restNowItem.target = self
        menu.addItem(startItem)
        menu.addItem(stopItem)
        menu.addItem(pauseItem)
        menu.addItem(restNowItem)
        menu.addItem(.separator())
        let settings = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        // Deliberately low-key: a plain item near the bottom, showing its
        // shortcut as a hint, not advertised as a primary control.
        emergencyItem.keyEquivalentModifierMask = [.control, .option, .command]
        emergencyItem.target = self
        menu.addItem(emergencyItem)
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

    /// One menu item serves both directions: it pauses a running Work Session
    /// and resumes a paused one. The engine no-ops in any other state.
    @objc private func pauseOrResume() {
        switch engine.state {
        case .working: engine.pause()
        case .paused: engine.resume()
        default: break
        }
        render()
    }

    /// Begins a Rest right now from any non-resting state — the Visual pounces
    /// and the configured Rest runs, just as if a Work Session had elapsed.
    /// `render()` then brings up Coverage on every display.
    @objc private func takeRestNow() {
        // Pick up the latest configured Rest length for this on-demand Rest.
        let settings = settingsStore.settings
        engine.configure(workDuration: settings.workDuration, restDuration: settings.restDuration)
        engine.startRest()
        render()
    }

    /// The escape hatch. Force-ends an active Rest; `render()` then sees the
    /// engine is no longer resting and clears the cats on every display.
    @objc private func emergencyShoo() {
        engine.emergencyShoo()
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
        // restCompleted flips the cats from sleepy to awake at 00:00; the 0.5s
        // tick cadence bounds how late the wake-up can be.
        coverage?.update(covering: isResting, restCompleted: engine.restCompleted())
    }

    private var isResting: Bool {
        if case .resting = engine.state { return true }
        return false
    }

    private func renderStatus() {
        // The Emergency Shoo is capped per day (the engine enforces it; the
        // hotkey just no-ops once spent). Surface the count so hitting the cap
        // is never a surprise.
        let shoosLeft = engine.emergencyShoosRemaining()
        emergencyItem.title = "Emergency Shoo (\(shoosLeft) left today)"
        emergencyItem.isEnabled = shoosLeft > 0

        // Pause/Resume is offered only around a Work Session — never during a
        // Rest (the enforced part) or while idle.
        // "Take a Rest Now" is offered everywhere except during a Rest, where
        // the engine no-ops (there's already a Rest running).
        switch engine.state {
        case .idle:
            // A template SF Symbol auto-adapts to the menu bar's light/dark
            // appearance, so the icon is always visible — a color emoji (🐾)
            // renders dark and disappears against a dark-tinted menu bar.
            setStatusIcon("pawprint.fill", fallbackTitle: "🐾")
            startItem.isEnabled = true
            stopItem.isEnabled = false
            pauseItem.isHidden = true
            restNowItem.isEnabled = true
        case .working:
            setStatusTitle(format(engine.remaining()))
            startItem.isEnabled = false
            stopItem.isEnabled = true
            pauseItem.isHidden = false
            pauseItem.title = "Pause"
            restNowItem.isEnabled = true
        case .paused:
            setStatusTitle("⏸ " + format(engine.remaining()))
            startItem.isEnabled = false
            stopItem.isEnabled = true
            pauseItem.isHidden = false
            pauseItem.title = "Resume"
            restNowItem.isEnabled = true
        case .resting:
            setStatusTitle("😺 " + format(engine.restRemaining()))
            startItem.isEnabled = false
            stopItem.isEnabled = true
            pauseItem.isHidden = true
            restNowItem.isEnabled = false
        }
    }

    /// Shows a template-rendered SF Symbol in the status item (clearing any
    /// countdown text). Falls back to a title if the symbol is unavailable.
    private func setStatusIcon(_ symbolName: String, fallbackTitle: String) {
        guard let button = statusItem.button else { return }
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Pawmodoro")
        image?.isTemplate = true
        button.image = image
        button.title = image == nil ? fallbackTitle : ""
    }

    /// Shows text in the status item (clearing any icon).
    private func setStatusTitle(_ title: String) {
        guard let button = statusItem.button else { return }
        button.image = nil
        button.title = title
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
