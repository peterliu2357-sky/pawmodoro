import Foundation
import Testing
@testable import PawmodoroKit

/// A clock whose time the test advances by hand.
final class TestClock: Clock, @unchecked Sendable {
    private var current: Date
    init(_ start: Date = Date(timeIntervalSinceReferenceDate: 0)) { current = start }
    var now: Date { current }
    func advance(by interval: TimeInterval) { current += interval }
}

@Suite struct SessionEngineTests {
    @Test func startBeginsWorkSessionWithFullRemaining() {
        let clock = TestClock()
        var engine = SessionEngine(workDuration: 25 * 60, clock: clock)

        engine.start()

        #expect(engine.remaining() == 25 * 60)
    }

    @Test func remainingShrinksAsTheClockAdvances() {
        let clock = TestClock()
        var engine = SessionEngine(workDuration: 25 * 60, clock: clock)
        engine.start()

        clock.advance(by: 60)

        #expect(engine.remaining() == 24 * 60)
    }

    @Test func pollPouncesIntoRestWhenWorkElapses() {
        let clock = TestClock()
        var engine = SessionEngine(workDuration: 25 * 60, clock: clock)
        engine.start()

        clock.advance(by: 25 * 60)
        engine.poll()

        #expect(engine.state == .resting)
    }

    @Test func pollLeavesWorkSessionRunningBeforeItElapses() {
        let clock = TestClock()
        var engine = SessionEngine(workDuration: 25 * 60, clock: clock)
        engine.start()

        clock.advance(by: 24 * 60)
        engine.poll()

        #expect(engine.state == .working(endsAt: clock.now + 60))
    }

    @Test func dismissStartsAFreshFullLengthWorkSession() {
        let clock = TestClock()
        var engine = SessionEngine(workDuration: 25 * 60, clock: clock)
        engine.start()
        clock.advance(by: 25 * 60)
        engine.poll()
        #expect(engine.state == .resting)

        engine.dismiss()

        #expect(engine.state == .working(endsAt: clock.now + 25 * 60))
        #expect(engine.remaining() == 25 * 60)
    }

    @Test func stopReturnsToIdleFromWork() {
        let clock = TestClock()
        var engine = SessionEngine(workDuration: 25 * 60, clock: clock)
        engine.start()

        engine.stop()

        #expect(engine.state == .idle)
    }

    @Test func stopReturnsToIdleFromRest() {
        let clock = TestClock()
        var engine = SessionEngine(workDuration: 25 * 60, clock: clock)
        engine.start()
        clock.advance(by: 25 * 60)
        engine.poll()

        engine.stop()

        #expect(engine.state == .idle)
    }
}
