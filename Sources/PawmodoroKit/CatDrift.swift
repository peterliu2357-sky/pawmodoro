import CoreGraphics
import Foundation

/// Pure motion math for the floating cat: where the cat window should drift to
/// over time. The presentation layer springs the window toward this wandering
/// anchor each frame; keeping the path itself pure makes the "stays on screen"
/// guarantee testable without any AppKit window.
public enum CatDrift {
    /// The window origin the cat should drift toward at `t` seconds since the
    /// drift began, for a window of `windowSize` on `display`.
    ///
    /// A slow Lissajous across whatever room the window leaves on the display:
    /// the two axes use different periods so the path never collapses to a line.
    /// The amplitude is bounded by that room (and pulled in slightly), so the
    /// returned origin always keeps the window fully on screen — and degrades to
    /// the single valid origin when an axis has no room to move.
    public static func anchor(in display: CGRect, windowSize: CGSize, at t: TimeInterval) -> CGPoint {
        let roomX = max(0, display.width - windowSize.width)
        let roomY = max(0, display.height - windowSize.height)
        let x = display.minX + roomX / 2 + (roomX / 2) * 0.95 * CGFloat(sin(t * 0.16))
        let y = display.minY + roomY / 2 + (roomY / 2) * 0.95 * CGFloat(sin(t * 0.22 + 1.0))
        return CGPoint(x: x, y: y)
    }
}
