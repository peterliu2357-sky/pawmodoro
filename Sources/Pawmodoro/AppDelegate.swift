import AppKit
import PawmodoroKit

/// Menu-bar presentation for the Work → Pounce → Rest loop. Holds the pure
/// Session Engine and translates its state into a status-item countdown, a menu,
/// and a placeholder Visual window. This layer is verified by manual QA; the
/// behavior it drives lives in (and is tested through) `SessionEngine`.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var engine = SessionEngine(clock: SystemClock())
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var visual: VisualWindowController?
    private var timer: Timer?

    private let startItem = NSMenuItem(title: "Start", action: #selector(start), keyEquivalent: "")
    private let stopItem = NSMenuItem(title: "Stop", action: #selector(stop), keyEquivalent: "")

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMenu()
        render()

        // Drives the wall-clock state machine. A coarse cadence is fine: the
        // countdown is recomputed from the clock, so it never drifts.
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func buildMenu() {
        let menu = NSMenu()
        startItem.target = self
        stopItem.target = self
        menu.addItem(startItem)
        menu.addItem(stopItem)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit Pawmodoro", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
        statusItem.menu = menu
    }

    // MARK: - Menu actions

    @objc private func start() {
        engine.start()
        render()
    }

    @objc private func stop() {
        engine.stop()
        render()
    }

    // MARK: - Loop

    private func tick() {
        engine.poll()
        render()
    }

    /// Dismisses the Visual (Shoo placeholder) and lets the loop continue into a
    /// fresh Work Session.
    private func shoo() {
        engine.dismiss()
        render()
    }

    /// Single source of truth: reconcile the UI with the engine's state.
    private func render() {
        switch engine.state {
        case .idle:
            statusItem.button?.title = "🐾"
            startItem.isEnabled = true
            stopItem.isEnabled = false
            dismissVisual()
        case .working:
            statusItem.button?.title = format(engine.remaining())
            startItem.isEnabled = false
            stopItem.isEnabled = true
            dismissVisual()
        case .resting:
            statusItem.button?.title = "😺"
            startItem.isEnabled = false
            stopItem.isEnabled = true
            presentVisual()
        }
    }

    private func presentVisual() {
        guard visual == nil else { return }
        visual = VisualWindowController { [weak self] in self?.shoo() }
        visual?.show()
    }

    private func dismissVisual() {
        visual?.close()
        visual = nil
    }

    private func format(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded(.up))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}
