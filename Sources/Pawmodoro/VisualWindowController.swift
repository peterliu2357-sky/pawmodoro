import AppKit

/// A borderless, full-screen placeholder Visual that pounces onto the main
/// display when a Rest begins. Slice 1 is intentionally minimal: a big cat
/// covering the screen that dismisses on click. Drag/throw physics, Snap-back,
/// coverage shaping, click-through, and multi-display all arrive in later slices.
@MainActor
final class VisualWindowController {
    private let window: NSWindow
    private let onShoo: () -> Void

    init(onShoo: @escaping () -> Void) {
        self.onShoo = onShoo

        let frame = (NSScreen.main ?? NSScreen.screens.first)?.frame ?? .zero
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
        window.ignoresMouseEvents = false

        let view = ClickView()
        view.onClick = onShoo
        window.contentView = view
    }

    func show() {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func close() {
        window.orderOut(nil)
    }
}

/// Fills its bounds with a large placeholder cat and reports clicks.
private final class ClickView: NSView {
    var onClick: (() -> Void)?

    override func mouseDown(with event: NSEvent) { onClick?() }

    override func draw(_ dirtyRect: NSRect) {
        let cat = "🐱" as NSString
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: min(bounds.width, bounds.height) * 0.5)
        ]
        let size = cat.size(withAttributes: attrs)
        let origin = NSPoint(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2)
        cat.draw(at: origin, withAttributes: attrs)

        let hint = "Click the cat to Shoo it away" as NSString
        let hintAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 24, weight: .medium),
            .foregroundColor: NSColor.white.withAlphaComponent(0.85)
        ]
        let hintSize = hint.size(withAttributes: hintAttrs)
        hint.draw(at: NSPoint(x: bounds.midX - hintSize.width / 2, y: origin.y - 48), withAttributes: hintAttrs)
    }
}
