import AppKit
import QuartzCore

/// The draggable cat — "Dozy", a sleepy charcoal cat drawn entirely in code so
/// it stays crisp at any Coverage size and can animate. It fills its own small,
/// transparent window so clicks anywhere else fall straight through to the apps
/// behind the Coverage (ADR-0001 — never block input). While dragged it moves
/// *its window* to follow the pointer, measures throw velocity, and reports a
/// release via `onThrow`; spring-home and fly-off are driven by the controller.
///
/// Two animations run here, both as layer-free redraws driven by a timer:
///   • an **idle loop** — a gentle breathing scale and a few floating "z"s;
///   • a **Pounce entrance** — a springy scale-in with squash-and-stretch, so
///     the cat lands when a Rest begins instead of just appearing.
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

    // Animation state.
    private var animationTimer: Timer?
    private var idlePhase: TimeInterval = 0      // seconds, drives breathing + z's
    private var lastTick: TimeInterval = 0
    private var pounceStart: TimeInterval?       // CACurrentMediaTime when the pounce began
    private static let pounceDuration: TimeInterval = 0.5

    /// The cat is authored in a 240×240 top-down space (matching the design), so
    /// the view draws flipped to use those coordinates directly.
    override var isFlipped: Bool { true }

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not used") }

    // MARK: - Animation lifecycle

    /// Begins the idle loop and plays the Pounce entrance. Called by the
    /// controller when the Visual is shown for a Rest.
    func appear() {
        idlePhase = 0
        lastTick = CACurrentMediaTime()
        pounceStart = CACurrentMediaTime()
        guard animationTimer == nil else { return }
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        animationTimer = timer
    }

    /// Stops all animation and releases the timer.
    func stopAnimating() {
        animationTimer?.invalidate()
        animationTimer = nil
        pounceStart = nil
    }

    private func tick() {
        let now = CACurrentMediaTime()
        idlePhase += now - lastTick
        lastTick = now
        if let start = pounceStart, now - start > Self.pounceDuration { pounceStart = nil }
        needsDisplay = true
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current else { return }

        // Map the 240-unit design space into the view, centered.
        let s = min(bounds.width, bounds.height) / 240
        let tx = (bounds.width - 240 * s) / 2
        let ty = (bounds.height - 240 * s) / 2

        let now = CACurrentMediaTime()
        let (sx, sy, alpha) = animationFactors(now: now)
        let pivot = CGPoint(x: 120, y: 214)   // feet stay planted under scaling

        ctx.saveGraphicsState()
        let t = NSAffineTransform()
        t.translateX(by: tx, yBy: ty)
        t.scaleX(by: s, yBy: s)
        t.translateX(by: pivot.x, yBy: pivot.y)
        t.scaleX(by: sx, yBy: sy)
        t.translateX(by: -pivot.x, yBy: -pivot.y)
        t.concat()

        drawCat(alpha: alpha)
        drawZs(now: now, alpha: alpha)

        ctx.restoreGraphicsState()
    }

    /// Combines the breathing idle and the pounce entrance into per-axis scale
    /// factors and an overall alpha (the cat fades in as it pounces).
    private func animationFactors(now: TimeInterval) -> (sx: CGFloat, sy: CGFloat, alpha: CGFloat) {
        // Idle breathing: a slow ~3s cycle, belly rises, body narrows a touch.
        let breath = CGFloat(sin(idlePhase * 2 * .pi / 3.0))
        let breathX: CGFloat = 1 - 0.012 * breath
        let breathY: CGFloat = 1 + 0.020 * breath

        // Pounce: scale up from a crouch with an overshoot (ease-out-back) and a
        // coupled squash-and-stretch (wide-low while small, tall-thin on the pop).
        var popX: CGFloat = 1, popY: CGFloat = 1, alpha: CGFloat = 1
        if let start = pounceStart {
            let p = CGFloat(min(1, max(0, (now - start) / Self.pounceDuration)))
            let pop = 0.45 + (Self.easeOutBack(p) * (1 - 0.45))
            let stretch = pop - 1
            popX = pop * (1 - 0.45 * stretch)
            popY = pop * (1 + 0.45 * stretch)
            alpha = min(1, p * 2)
        }
        return (popX * breathX, popY * breathY, alpha)
    }

    private static func easeOutBack(_ p: CGFloat) -> CGFloat {
        let c1: CGFloat = 1.70158
        let c3 = c1 + 1
        let x = p - 1
        return 1 + c3 * x * x * x + c1 * x * x
    }

    /// Draws Dozy in design coordinates. The graphics context already carries the
    /// design→view and animation transforms.
    private func drawCat(alpha: CGFloat) {
        let body = NSColor(srgb: 0x43434F, alpha: alpha)
        let bodyDark = NSColor(srgb: 0x34343E, alpha: alpha)
        let rim = NSColor(srgb: 0x5A5A68, alpha: alpha)
        let earPink = NSColor(srgb: 0xFF9EB0, alpha: alpha)
        let eyeLine = NSColor(srgb: 0xCFD4E0, alpha: alpha)
        let cheek = NSColor(srgb: 0xFF7E9C, alpha: 0.4 * alpha)
        let mouthLine = NSColor(srgb: 0x20202A, alpha: alpha)
        let whisker = NSColor(srgb: 0xCFD4E0, alpha: 0.6 * alpha)

        // Tail — a filled curl behind the body (a closed shape curls smoothly,
        // where a stroked multi-segment path kinks where its segments meet).
        let tail = NSBezierPath()
        tail.move(to: CGPoint(x: 54, y: 196))
        tail.addQuad(to: CGPoint(x: 20, y: 140), control: CGPoint(x: 8, y: 190))
        tail.addQuad(to: CGPoint(x: 46, y: 124), control: CGPoint(x: 26, y: 118))
        tail.addQuad(to: CGPoint(x: 32, y: 150), control: CGPoint(x: 32, y: 130))
        tail.addQuad(to: CGPoint(x: 66, y: 180), control: CGPoint(x: 32, y: 186))
        tail.close()
        body.setFill(); tail.fill()
        rim.setStroke(); tail.lineWidth = 1.5; tail.stroke()

        // Body + head.
        let bodyOval = NSBezierPath(ovalIn: CGRect(x: 68, y: 138, width: 104, height: 84))
        body.setFill(); bodyOval.fill()
        rim.setStroke(); bodyOval.lineWidth = 1.5; bodyOval.stroke()

        // Front paws.
        for cx in [98.0, 142.0] {
            let paw = NSBezierPath(ovalIn: CGRect(x: cx - 15, y: 197, width: 30, height: 22))
            bodyDark.setFill(); paw.fill()
        }

        let head = NSBezierPath(ovalIn: CGRect(x: 60, y: 46, width: 120, height: 120))
        body.setFill(); head.fill()
        rim.setStroke(); head.lineWidth = 1.5; head.stroke()

        // Ears (outer charcoal + rim, inner pink).
        drawTriangle([(72, 66), (60, 16), (106, 50)], fill: body, stroke: rim)
        drawTriangle([(168, 66), (180, 16), (134, 50)], fill: body, stroke: rim)
        drawTriangle([(77, 58), (73, 32), (98, 50)], fill: earPink, stroke: nil)
        drawTriangle([(163, 58), (167, 32), (142, 50)], fill: earPink, stroke: nil)

        // Sleepy, content eyes (downward arcs).
        let eyes = NSBezierPath()
        eyes.move(to: CGPoint(x: 82, y: 108)); eyes.addQuad(to: CGPoint(x: 110, y: 108), control: CGPoint(x: 96, y: 122))
        eyes.move(to: CGPoint(x: 130, y: 108)); eyes.addQuad(to: CGPoint(x: 158, y: 108), control: CGPoint(x: 144, y: 122))
        eyes.lineWidth = 5; eyes.lineCapStyle = .round
        eyeLine.setStroke(); eyes.stroke()

        // Cheeks.
        for cx in [80.0, 160.0] {
            let c = NSBezierPath(ovalIn: CGRect(x: cx - 12, y: 115, width: 24, height: 14))
            cheek.setFill(); c.fill()
        }

        // Nose + mouth.
        drawTriangle([(115, 124), (125, 124), (120, 130)], fill: earPink, stroke: nil)
        let mouth = NSBezierPath()
        mouth.move(to: CGPoint(x: 120, y: 130)); mouth.addQuad(to: CGPoint(x: 108, y: 133), control: CGPoint(x: 114, y: 135))
        mouth.move(to: CGPoint(x: 120, y: 130)); mouth.addQuad(to: CGPoint(x: 132, y: 133), control: CGPoint(x: 126, y: 135))
        mouth.lineWidth = 3; mouth.lineCapStyle = .round
        mouthLine.setStroke(); mouth.stroke()

        // Whiskers.
        let w = NSBezierPath()
        w.move(to: CGPoint(x: 70, y: 118)); w.line(to: CGPoint(x: 48, y: 114))
        w.move(to: CGPoint(x: 72, y: 126)); w.line(to: CGPoint(x: 50, y: 130))
        w.move(to: CGPoint(x: 170, y: 118)); w.line(to: CGPoint(x: 192, y: 114))
        w.move(to: CGPoint(x: 168, y: 126)); w.line(to: CGPoint(x: 190, y: 130))
        w.lineWidth = 2.5; w.lineCapStyle = .round
        whisker.setStroke(); w.stroke()
    }

    /// A few "z"s drifting up-right from beside the head, once the pounce settles.
    private func drawZs(now: TimeInterval, alpha: CGFloat) {
        // Hold the z's back until the entrance has landed.
        var reveal: CGFloat = 1
        if let start = pounceStart {
            reveal = CGFloat(min(1, max(0, (now - start - Self.pounceDuration + 0.2) / 0.4)))
        }
        guard reveal > 0 else { return }

        for i in 0..<3 {
            let zp = CGFloat((idlePhase * 0.35 + Double(i) / 3.0).truncatingRemainder(dividingBy: 1.0))
            let x = 158 + zp * 38
            let y = 80 - zp * 48        // design space is y-down, so up = smaller y
            let a = sin(zp * .pi) * 0.8 * Double(reveal * alpha)
            let size = 13 + zp * 9
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: size, weight: .semibold),
                .foregroundColor: NSColor(srgb: 0xCFD4E0, alpha: CGFloat(a)),
            ]
            ("z" as NSString).draw(at: CGPoint(x: x, y: y), withAttributes: attrs)
        }
    }

    private func drawTriangle(_ pts: [(CGFloat, CGFloat)], fill: NSColor, stroke: NSColor?) {
        let p = NSBezierPath()
        p.move(to: CGPoint(x: pts[0].0, y: pts[0].1))
        p.line(to: CGPoint(x: pts[1].0, y: pts[1].1))
        p.line(to: CGPoint(x: pts[2].0, y: pts[2].1))
        p.close()
        fill.setFill(); p.fill()
        if let stroke { stroke.setStroke(); p.lineWidth = 1.5; p.stroke() }
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

private extension NSBezierPath {
    /// Appends a quadratic Bézier (SVG `q`) by promoting it to the cubic curve
    /// AppKit draws, so the design's quadratic shapes translate directly.
    func addQuad(to end: CGPoint, control: CGPoint) {
        let start = currentPoint
        let c1 = CGPoint(x: start.x + 2.0 / 3 * (control.x - start.x),
                         y: start.y + 2.0 / 3 * (control.y - start.y))
        let c2 = CGPoint(x: end.x + 2.0 / 3 * (control.x - end.x),
                         y: end.y + 2.0 / 3 * (control.y - end.y))
        curve(to: end, controlPoint1: c1, controlPoint2: c2)
    }
}

private extension NSColor {
    /// Builds a color from a 0xRRGGBB literal in the sRGB space.
    convenience init(srgb hex: Int, alpha: CGFloat) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: alpha)
    }
}
