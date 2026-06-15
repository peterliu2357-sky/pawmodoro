import AppKit

/// The draggable cat. Follows the pointer while dragged, measures throw velocity
/// from the last moments of the drag, and reports a release via `onThrow`. All
/// animation (spring-home, fly-off) is requested by the controller after the
/// engine rules on the throw.
@MainActor
final class CatView: NSView {
    /// Called on mouse-up with the release velocity in points/second.
    var onThrow: ((CGVector) -> Void)?

    private var dragOffset: CGSize = .zero
    private var lastPoint: CGPoint = .zero
    private var lastTime: TimeInterval = 0
    private var velocity: CGVector = .zero

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not used") }

    override func draw(_ dirtyRect: NSRect) {
        let cat = "🐱" as NSString
        let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: bounds.height * 0.8)]
        let size = cat.size(withAttributes: attrs)
        cat.draw(at: NSPoint(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2), withAttributes: attrs)
    }

    // MARK: - Dragging

    override func mouseDown(with event: NSEvent) {
        layer?.removeAllAnimations()
        let inWindow = event.locationInWindow
        let origin = frame.origin
        dragOffset = CGSize(width: inWindow.x - origin.x, height: inWindow.y - origin.y)
        lastPoint = inWindow
        lastTime = event.timestamp
        velocity = .zero
    }

    override func mouseDragged(with event: NSEvent) {
        let p = event.locationInWindow
        setFrameOrigin(CGPoint(x: p.x - dragOffset.width, y: p.y - dragOffset.height))

        let dt = event.timestamp - lastTime
        if dt > 0 {
            // Smooth a little so a single jittery sample doesn't dominate.
            let instant = CGVector(dx: (p.x - lastPoint.x) / dt, dy: (p.y - lastPoint.y) / dt)
            velocity = CGVector(dx: velocity.dx * 0.4 + instant.dx * 0.6,
                                dy: velocity.dy * 0.4 + instant.dy * 0.6)
        }
        lastPoint = p
        lastTime = event.timestamp
    }

    override func mouseUp(with event: NSEvent) {
        onThrow?(velocity)
    }

    // MARK: - Animations (requested by the controller)

    /// Springs the cat back to a resting centre — the visible Snap-back.
    func springHome(to center: CGPoint) {
        let target = CGPoint(x: center.x - frame.width / 2, y: center.y - frame.height / 2)
        let spring = CASpringAnimation(keyPath: "position")
        spring.damping = 12
        spring.stiffness = 180
        spring.mass = 1
        spring.initialVelocity = 6
        spring.duration = spring.settlingDuration
        spring.fromValue = layer?.position
        layer?.add(spring, forKey: "snapback")
        setFrameOrigin(target)
    }

    /// Flings the cat off the screen along the throw direction, then completes.
    func flyOff(direction velocity: CGVector, within bounds: CGRect, completion: @escaping @Sendable () -> Void) {
        let mag = max(1, (velocity.dx * velocity.dx + velocity.dy * velocity.dy).squareRoot())
        let unit = CGVector(dx: velocity.dx / mag, dy: velocity.dy / mag)
        let distance = (bounds.width + bounds.height)
        let target = CGPoint(x: frame.origin.x + unit.dx * distance, y: frame.origin.y + unit.dy * distance)

        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.4
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            animator().setFrameOrigin(target)
        }, completionHandler: completion)
    }
}
