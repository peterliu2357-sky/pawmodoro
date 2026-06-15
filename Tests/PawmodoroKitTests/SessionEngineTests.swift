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

    @Test func pollBeginsTimedRestOfConfiguredLengthWhenWorkElapses() {
        let clock = TestClock()
        var engine = SessionEngine(workDuration: 25 * 60, restDuration: 5 * 60, clock: clock)
        engine.start()

        clock.advance(by: 25 * 60)
        engine.poll()

        #expect(engine.state == .resting(endsAt: clock.now + 5 * 60))
        #expect(engine.restRemaining() == 5 * 60)
    }

    @Test func restRemainingShrinksAsTheClockAdvances() {
        let clock = TestClock()
        var engine = SessionEngine(workDuration: 25 * 60, restDuration: 5 * 60, clock: clock)
        engine.start()
        clock.advance(by: 25 * 60)
        engine.poll()

        clock.advance(by: 60)

        #expect(engine.restRemaining() == 4 * 60)
    }

    @Test func pollLeavesWorkSessionRunningBeforeItElapses() {
        let clock = TestClock()
        var engine = SessionEngine(workDuration: 25 * 60, clock: clock)
        engine.start()

        clock.advance(by: 24 * 60)
        engine.poll()

        #expect(engine.state == .working(endsAt: clock.now + 60))
    }

    @Test func attemptShooBeforeRestCompletesSnapsBack() {
        let clock = TestClock()
        var engine = SessionEngine(workDuration: 25 * 60, restDuration: 5 * 60, clock: clock)
        engine.start()
        clock.advance(by: 25 * 60)
        engine.poll()
        let restEnd = clock.now + 5 * 60

        clock.advance(by: 4 * 60)            // 1 minute of Rest still to go
        let outcome = engine.attemptShoo()

        #expect(outcome == .snappedBack)
        #expect(engine.state == .resting(endsAt: restEnd))
    }

    @Test func attemptShooAfterRestCompletesStartsFreshFullWorkSession() {
        let clock = TestClock()
        var engine = SessionEngine(workDuration: 25 * 60, restDuration: 5 * 60, clock: clock)
        engine.start()
        clock.advance(by: 25 * 60)
        engine.poll()

        clock.advance(by: 5 * 60)            // Rest fully elapsed
        let outcome = engine.attemptShoo()

        #expect(outcome == .accepted)
        #expect(engine.state == .working(endsAt: clock.now + 25 * 60))
        #expect(engine.remaining() == 25 * 60)
    }

    @Test func attemptShooWhenNotRestingIsIgnored() {
        let clock = TestClock()
        var engine = SessionEngine(workDuration: 25 * 60, restDuration: 5 * 60, clock: clock)
        engine.start()

        let outcome = engine.attemptShoo()

        #expect(outcome == .snappedBack)
        #expect(engine.state == .working(endsAt: clock.now + 25 * 60))
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
