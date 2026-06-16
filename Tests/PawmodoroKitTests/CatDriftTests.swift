import CoreGraphics
import Foundation
import Testing
@testable import PawmodoroKit

@Suite struct CatDriftTests {
    private let display = CGRect(x: 0, y: 0, width: 1440, height: 900)
    private let window = CGSize(width: 1280, height: 800)   // a large, ~80% cat window

    @Test func anchorAlwaysKeepsTheWindowFullyOnScreen() {
        // Sample many times across several drift periods.
        for step in 0..<400 {
            let t = TimeInterval(step) * 0.25
            let origin = CatDrift.anchor(in: display, windowSize: window, at: t)
            #expect(origin.x >= display.minX)
            #expect(origin.x <= display.maxX - window.width)
            #expect(origin.y >= display.minY)
            #expect(origin.y <= display.maxY - window.height)
        }
    }

    @Test func anchorStaysCenteredWhenThereIsNoRoomToMove() {
        // A window exactly the size of the display can only sit at the origin.
        let full = CGSize(width: display.width, height: display.height)
        for step in 0..<50 {
            let origin = CatDrift.anchor(in: display, windowSize: full, at: TimeInterval(step))
            #expect(origin.x == display.minX)
            #expect(origin.y == display.minY)
        }
    }

    @Test func anchorWandersOnBothAxesOverTime() {
        // Sample across a couple of minutes and confirm real movement on each
        // axis (the cat floats around, it doesn't sit in one spot).
        var xs: Set<Int> = [], ys: Set<Int> = []
        for step in 0..<240 {
            let p = CatDrift.anchor(in: display, windowSize: window, at: TimeInterval(step) * 0.5)
            xs.insert(Int(p.x.rounded())); ys.insert(Int(p.y.rounded()))
        }
        #expect(xs.count > 10)
        #expect(ys.count > 10)
    }
}
