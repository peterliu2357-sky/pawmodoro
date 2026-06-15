import AppKit
import PawmodoroKit

/// A borderless, full-screen Visual that pounces onto the main display when a
/// Rest begins. The cat can be grabbed and thrown; flicking it off a screen edge
/// asks the engine to end the Rest. The engine's verdict drives the animation:
/// `.accepted` flies the cat off, `.snappedBack` springs it home.
///
/// Coverage shaping (~80%), click-through outside the cat, and multi-display all
/// arrive in later slices. This layer is verified by manual QA.
@MainActor
final class VisualWindowController {
    private let window: NSWindow
    private let cat: CatView

    /// Asks the engine to end the Rest; returns its verdict.
    private let onShoo: () -> ShooOutcome

    init(onShoo: @escaping () -> ShooOutcome) {
        self.onShoo = onShoo

        // visibleFrame (not frame) so the cat never covers the menu bar — the
        // status item stays visible and clickable during a Rest.
        let frame = (NSScreen.main ?? NSScreen.screens.first)?.visibleFrame ?? NSRect(x: 0, y: 0, width: 800, height: 600)
        window = NSWindow(
            contentRect: frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = NSColor.black.withAlphaComponent(0.25)
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let content = NSView(frame: NSRect(origin: .zero, size: frame.size))
        let side = min(frame.width, frame.height) * 0.45
        cat = CatView(frame: NSRect(x: 0, y: 0, width: side, height: side))
        content.addSubview(cat)
        window.contentView = content

        cat.onThrow = { [weak self] velocity in self?.handleThrow(velocity) }
        centerCat()
    }

    func show() {
        centerCat()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func close() {
        window.orderOut(nil)
    }

    private var home: CGPoint {
        guard let content = window.contentView else { return .zero }
        return CGPoint(x: content.bounds.midX, y: content.bounds.midY)
    }

    private func centerCat() {
        cat.setFrameOrigin(CGPoint(x: home.x - cat.frame.width / 2, y: home.y - cat.frame.height / 2))
    }

    /// The cat was released. Decide whether the throw carries it off a screen
    /// edge; if so ask the engine, then animate based on the verdict.
    private func handleThrow(_ velocity: CGVector) {
        guard let content = window.contentView else { return }
        let bounds = content.bounds

        // Project where the cat's centre lands a short moment after release.
        let projectionTime: CGFloat = 0.35
        let center = CGPoint(x: cat.frame.midX, y: cat.frame.midY)
        let landing = CGPoint(x: center.x + velocity.dx * projectionTime,
                              y: center.y + velocity.dy * projectionTime)

        let leavesEdge = landing.x < 0 || landing.x > bounds.width
            || landing.y < 0 || landing.y > bounds.height

        guard leavesEdge else {
            cat.springHome(to: home)   // not a real Shoo attempt
            return
        }

        switch onShoo() {
        case .accepted:
            cat.flyOff(direction: velocity, within: bounds) { [weak self] in
                MainActor.assumeIsolated { self?.close() }
            }
        case .snappedBack:
            cat.springHome(to: home)
        }
    }
}
