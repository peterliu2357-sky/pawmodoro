import Foundation
import Testing
@testable import PawmodoroKit

@Suite struct CoverageGeometryTests {
    @Test func coverageFrameCoversTheRequestedFractionOfTheDisplayArea() {
        let display = CGRect(x: 0, y: 0, width: 1000, height: 800)

        let frame = CoverageGeometry.coverageFrame(in: display, areaFraction: 0.8)

        let coverage = (frame.width * frame.height) / (display.width * display.height)
        #expect(abs(coverage - 0.8) < 0.001)
    }

    @Test func coverageFrameIsCenteredWithinTheDisplay() {
        let display = CGRect(x: 100, y: 200, width: 1000, height: 800)

        let frame = CoverageGeometry.coverageFrame(in: display, areaFraction: 0.8)

        #expect(abs(frame.midX - display.midX) < 0.001)
        #expect(abs(frame.midY - display.midY) < 0.001)
    }

    @Test func coverageFrameNeverExceedsTheDisplay() {
        let display = CGRect(x: 0, y: 0, width: 1000, height: 800)

        let frame = CoverageGeometry.coverageFrame(in: display, areaFraction: 1.5)

        #expect(frame.width <= display.width)
        #expect(frame.height <= display.height)
    }
}
