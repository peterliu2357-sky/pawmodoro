import AppKit
import PawmodoroKit

/// The Coverage Visual for a Rest. Two windows enforce ADR-0001 ("never block
/// input") structurally:
///
///   • a **dim window** — the full display, dimmed, `ignoresMouseEvents`, so
///     every click outside the cat falls straight through to the app behind it;
///   • a **cat window** — a large Visual covering ~80% of the display, grabbable,
///     riding above the dim.
///
/// Flicking the cat off a screen edge asks the engine to end the Rest; its
/// verdict drives the animation (`.accepted` flies the cat off, `.snappedBack`
/// springs it home with a rubber-band bounce). Neither window steals key focus,
/// so the user can keep typing into apps in the uncovered area. No Accessibility
/// or Input-Monitoring permission is ever requested. Verified by manual QA.
@MainActor
final class VisualWindowController: CoverageVisual {
    private let dimWindow: NSWindow
    private let catWindow: NSWindow
    private let cat: CatView

    /// The display this Visual covers, in screen coordinates.
    private let screenFrame: CGRect

    /// Asks the engine to end the Rest; returns its verdict.
    private let onShoo: () -> ShooOutcome

    // Motion is one continuous spring pulling the cat window toward a slowly
    // wandering anchor: that produces the idle float, and a rejected Shoo just
    // seeds this spring with the throw velocity so it rubber-bands back into the
    // drift. Suspended while the user is dragging or the cat is flying off.
    private var motionTimer: Timer?
    private var windowVelocity: CGVector = .zero
    private var driftStart: TimeInterval = 0
    private var isDragging = false
    private var isFlying = false

    private static let stiffness: CGFloat = 120     // omega ≈ 11 rad/s
    private static let damping: CGFloat = 16        // underdamped (~0.73)
    private static let motionDT: CGFloat = 1.0 / 120.0
    private static let velocityCap: CGFloat = 2200  // keep a hard flick on-screen

    /// Both Visual windows sit above the screen saver level so they can ride over
    /// another app's true-fullscreen Space (ADR-0002). The cat sits one step
    /// above the dim so the grabbable Visual is always in front of the backdrop.
    private static let dimLevel = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 1)
    private static let catLevel = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 2)

    init(screen: NSScreen, onShoo: @escaping () -> ShooOutcome) {
        self.onShoo = onShoo

        // visibleFrame (not frame) so nothing covers the menu bar — the status
        // item stays visible and clickable during a Rest.
        screenFrame = screen.visibleFrame

        // Dim: the whole display, dimmed, click-through (purely visual).
        dimWindow = NSWindow(contentRect: screenFrame, styleMask: .borderless, backing: .buffered, defer: false)
        dimWindow.isOpaque = false
        dimWindow.backgroundColor = NSColor.black.withAlphaComponent(0.25)
        dimWindow.hasShadow = false
        // Above the screen saver, with all-Spaces + fullscreen-auxiliary
        // behavior, so the dim can reach over another app's true-fullscreen
        // Space (ADR-0002 — best-effort, degrades gracefully if the OS blocks it).
        dimWindow.level = Self.dimLevel
        dimWindow.ignoresMouseEvents = true   // clicks pass through to apps behind
        dimWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // Cat: the large Visual, ~80% of the display, transparent except the cat
        // itself, riding above the dim. Only this region is interactive.
        let catRect = CoverageGeometry.coverageFrame(in: screenFrame, areaFraction: 0.8)
        cat = CatView(frame: NSRect(origin: .zero, size: catRect.size))
        catWindow = NSWindow(contentRect: catRect, styleMask: .borderless, backing: .buffered, defer: false)
        catWindow.isOpaque = false
        catWindow.backgroundColor = .clear
        catWindow.hasShadow = false
        catWindow.level = Self.catLevel       // one step above the dim
        catWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        catWindow.contentView = cat

        cat.onGrab = { [weak self] in self?.beginDrag() }
        cat.onThrow = { [weak self] velocity in self?.handleThrow(velocity) }
    }

    func show() {
        isDragging = false
        isFlying = false
        windowVelocity = .zero
        driftStart = CACurrentMediaTime()
        catWindow.setFrameOrigin(driftAnchor(at: driftStart))   // start on the drift path
        // orderFrontRegardless (not makeKey/activate) so we float above without
        // stealing key focus — the user can keep typing into apps behind us.
        dimWindow.orderFrontRegardless()
        catWindow.orderFrontRegardless()
        cat.appear()    // play the Pounce entrance and start the idle loop
        startMotion()   // begin the gentle floating drift
    }

    func close() {
        stopMotion()
        cat.stopAnimating()
        catWindow.orderOut(nil)
        dimWindow.orderOut(nil)
    }

    // MARK: - Floating drift

    /// The wandering target the cat window springs toward. The path math lives in
    /// (and is tested through) `CatDrift`; here we just feed it the elapsed time.
    private func driftAnchor(at time: TimeInterval) -> CGPoint {
        CatDrift.anchor(in: screenFrame, windowSize: catWindow.frame.size, at: time - driftStart)
    }

    private func startMotion() {
        stopMotion()
        let timer = Timer(timeInterval: TimeInterval(Self.motionDT), repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.stepMotion() }
        }
        RunLoop.main.add(timer, forMode: .common)
        motionTimer = timer
    }

    private func stopMotion() {
        motionTimer?.invalidate()
        motionTimer = nil
    }

    /// One spring step toward the wandering anchor. Skipped while the user holds
    /// the cat or it is flying off; otherwise it both carries the idle float and
    /// rubber-bands a rejected throw home.
    private func stepMotion() {
        guard !isDragging, !isFlying else { return }
        let dt = Self.motionDT
        let target = driftAnchor(at: CACurrentMediaTime())
        var p = catWindow.frame.origin
        let fx = -Self.stiffness * (p.x - target.x) - Self.damping * windowVelocity.dx
        let fy = -Self.stiffness * (p.y - target.y) - Self.damping * windowVelocity.dy
        windowVelocity.dx += fx * dt
        windowVelocity.dy += fy * dt
        p.x += windowVelocity.dx * dt
        p.y += windowVelocity.dy * dt
        catWindow.setFrameOrigin(p)
    }

    private func beginDrag() {
        isDragging = true
        windowVelocity = .zero
    }

    /// The cat was released. Decide whether the throw carries it off a screen
    /// edge; if so ask the engine, then animate based on the verdict.
    private func handleThrow(_ velocity: CGVector) {
        isDragging = false

        // Project where the cat's centre lands a short moment after release.
        let projectionTime: CGFloat = 0.35
        let center = CGPoint(x: catWindow.frame.midX, y: catWindow.frame.midY)
        let landing = CGPoint(x: center.x + velocity.dx * projectionTime,
                              y: center.y + velocity.dy * projectionTime)

        let leavesEdge = landing.x < screenFrame.minX || landing.x > screenFrame.maxX
            || landing.y < screenFrame.minY || landing.y > screenFrame.maxY

        guard leavesEdge else {
            seedThrow(velocity)   // not a real Shoo attempt — drift reclaims it
            return
        }

        switch onShoo() {
        case .accepted:
            isFlying = true
            flyOff(direction: velocity) { [weak self] in
                MainActor.assumeIsolated { self?.close() }
            }
        case .snappedBack:
            seedThrow(velocity)   // rubber-band rejection back into the drift
        }
    }

    /// Hands the (capped) throw velocity to the running motion spring; it lunges
    /// the cat toward the edge then yanks it back toward the wandering anchor.
    private func seedThrow(_ velocity: CGVector) {
        let cap = Self.velocityCap
        windowVelocity = CGVector(dx: max(-cap, min(cap, velocity.dx)),
                                  dy: max(-cap, min(cap, velocity.dy)))
    }

    // MARK: - Animations (act on the cat window)

    /// Flings the cat window off the screen along the throw direction, then
    /// completes (which closes the Visual).
    private func flyOff(direction velocity: CGVector, completion: @escaping @Sendable () -> Void) {
        stopMotion()
        let mag = max(1, (velocity.dx * velocity.dx + velocity.dy * velocity.dy).squareRoot())
        let unit = CGVector(dx: velocity.dx / mag, dy: velocity.dy / mag)
        let distance = screenFrame.width + screenFrame.height
        let origin = catWindow.frame.origin
        let target = CGPoint(x: origin.x + unit.dx * distance, y: origin.y + unit.dy * distance)

        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.4
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            catWindow.animator().setFrameOrigin(target)
        }, completionHandler: completion)
    }
}
