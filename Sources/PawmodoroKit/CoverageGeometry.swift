import CoreGraphics
import Foundation

/// Pure geometry for the Coverage Visual. Holds no AppKit dependency so the
/// "~80% of the display" rule is testable without a screen.
public enum CoverageGeometry {
    /// A rect centered in `display` whose area is `areaFraction` of the display.
    /// The Coverage window is sized to this; the uncovered margin stays
    /// click-through so the user can still reach apps behind it.
    public static func coverageFrame(in display: CGRect, areaFraction: CGFloat) -> CGRect {
        let scale = min(1, max(0, areaFraction)).squareRoot()
        let width = display.width * scale
        let height = display.height * scale
        return CGRect(
            x: display.midX - width / 2,
            y: display.midY - height / 2,
            width: width,
            height: height
        )
    }
}
