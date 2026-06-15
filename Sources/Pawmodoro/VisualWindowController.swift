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

    private var springTimer: Timer?

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
        dimWindow.level = .screenSaver
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
        catWindow.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 1)
        catWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        catWindow.contentView = cat

        cat.onGrab = { [weak self] in self?.cancelSpring() }
        cat.onThrow = { [weak self] velocity in self?.handleThrow(velocity) }
    }

    func show() {
        centerCat()
        // orderFrontRegardless (not makeKey/activate) so we float above without
        // stealing key focus — the user can keep typing into apps behind us.
        dimWindow.orderFrontRegardless()
        catWindow.orderFrontRegardless()
    }

    func close() {
        cancelSpring()
        catWindow.orderOut(nil)
        dimWindow.orderOut(nil)
    }

    /// Screen-coordinate origin that centers the cat window on the display.
    private var homeOrigin: CGPoint {
        CGPoint(x: screenFrame.midX - catWindow.frame.width / 2,
                y: screenFrame.midY - catWindow.frame.height / 2)
    }

    private func centerCat() {
        catWindow.setFrameOrigin(homeOrigin)
    }

    /// The cat was released. Decide whether the throw carries it off a screen
    /// edge; if so ask the engine, then animate based on the verdict.
    private func handleThrow(_ velocity: CGVector) {
        // Project where the cat's centre lands a short moment after release.
        let projectionTime: CGFloat = 0.35
        let center = CGPoint(x: catWindow.frame.midX, y: catWindow.frame.midY)
        let landing = CGPoint(x: center.x + velocity.dx * projectionTime,
                              y: center.y + velocity.dy * projectionTime)

        let leavesEdge = landing.x < screenFrame.minX || landing.x > screenFrame.maxX
            || landing.y < screenFrame.minY || landing.y > screenFrame.maxY

        guard leavesEdge else {
            springHome(initialVelocity: velocity)   // not a real Shoo attempt
            return
        }

        switch onShoo() {
        case .accepted:
            flyOff(direction: velocity) { [weak self] in
                MainActor.assumeIsolated { self?.close() }
            }
        case .snappedBack:
            springHome(initialVelocity: velocity)   // rubber-band rejection
        }
    }

    // MARK: - Animations (act on the cat window)

    private func cancelSpring() {
        springTimer?.invalidate()
        springTimer = nil
    }

    /// Springs the cat window back to centre — the visible Snap-back. A damped
    /// spring, seeded with the (rejected) throw velocity, so the cat lunges
    /// toward the edge then is yanked home: a rubber band.
    private func springHome(initialVelocity: CGVector) {
        cancelSpring()

        let stiffness: CGFloat = 200    // omega ≈ 14 rad/s
        let damping: CGFloat = 18       // underdamped (~0.64) → a little overshoot
        let dt: CGFloat = 1.0 / 120.0
        let cap: CGFloat = 2200         // keep a hard flick from slinging fully away
        var v = CGVector(dx: max(-cap, min(cap, initialVelocity.dx)),
                         dy: max(-cap, min(cap, initialVelocity.dy)))
        let target = homeOrigin

        let timer = Timer(timeInterval: TimeInterval(dt), repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                var p = self.catWindow.frame.origin
                let fx = -stiffness * (p.x - target.x) - damping * v.dx
                let fy = -stiffness * (p.y - target.y) - damping * v.dy
                v.dx += fx * dt
                v.dy += fy * dt
                p.x += v.dx * dt
                p.y += v.dy * dt
                self.catWindow.setFrameOrigin(p)

                if abs(p.x - target.x) < 0.5, abs(p.y - target.y) < 0.5, (v.dx * v.dx + v.dy * v.dy).squareRoot() < 5 {
                    self.catWindow.setFrameOrigin(target)
                    self.cancelSpring()
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        springTimer = timer
    }

    /// Flings the cat window off the screen along the throw direction, then
    /// completes (which closes the Visual).
    private func flyOff(direction velocity: CGVector, completion: @escaping @Sendable () -> Void) {
        cancelSpring()
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
