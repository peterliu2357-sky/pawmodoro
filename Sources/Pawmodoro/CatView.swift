import AppKit

/// The draggable cat. It fills its own small, transparent window so that clicks
/// anywhere else fall straight through to the apps behind the Coverage (see
/// ADR-0001 — never block input). While dragged it moves *its window* to follow
/// the pointer, measures throw velocity from the last moments of the drag, and
/// reports a release via `onThrow`. Spring-home and fly-off are driven by the
/// controller, which owns the window.
@MainActor
final class CatView: NSView {
    /// Called on mouse-down so the controller can interrupt any running spring.
    var onGrab: (() -> Void)?
    /// Called on mouse-up with the release velocity in screen points/second.
    var onThrow: ((CGVector) -> Void)?

    private var grabOffset: CGSize = .zero
    private var lastLocation: CGPoint = .zero
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

    // MARK: - Dragging (moves the cat's window, in screen coordinates)

    override func mouseDown(with event: NSEvent) {
        onGrab?()
        guard let window else { return }
        let loc = NSEvent.mouseLocation
        let origin = window.frame.origin
        grabOffset = CGSize(width: loc.x - origin.x, height: loc.y - origin.y)
        lastLocation = loc
        lastTime = event.timestamp
        velocity = .zero
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window else { return }
        let loc = NSEvent.mouseLocation
        window.setFrameOrigin(CGPoint(x: loc.x - grabOffset.width, y: loc.y - grabOffset.height))

        let dt = event.timestamp - lastTime
        if dt > 0 {
            // Smooth a little so a single jittery sample doesn't dominate.
            let instant = CGVector(dx: (loc.x - lastLocation.x) / dt, dy: (loc.y - lastLocation.y) / dt)
            velocity = CGVector(dx: velocity.dx * 0.4 + instant.dx * 0.6,
                                dy: velocity.dy * 0.4 + instant.dy * 0.6)
        }
        lastLocation = loc
        lastTime = event.timestamp
    }

    override func mouseUp(with event: NSEvent) {
        onThrow?(velocity)
    }
}
