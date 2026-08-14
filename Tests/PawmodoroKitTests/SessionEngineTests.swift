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

    @Test func configuredDurationIsUsedByTheNextWorkSession() {
        let clock = TestClock()
        var engine = SessionEngine(workDuration: 25 * 60, clock: clock)

        engine.configure(workDuration: 30 * 60, restDuration: 5 * 60)
        engine.start()

        #expect(engine.remaining() == 30 * 60)
    }

    @Test func configuringDoesNotDisturbACurrentlyRunningWorkSession() {
        let clock = TestClock()
        var engine = SessionEngine(workDuration: 25 * 60, clock: clock)
        engine.start()
        let originalEnd = clock.now + 25 * 60

        engine.configure(workDuration: 30 * 60, restDuration: 5 * 60)

        #expect(engine.state == .working(endsAt: originalEnd))
        #expect(engine.remaining() == 25 * 60)
    }

    @Test func emergencyShooEndsAnActiveRestImmediatelyIntoAFreshWorkSession() {
        let clock = TestClock()
        var engine = SessionEngine(workDuration: 25 * 60, restDuration: 5 * 60, clock: clock)
        engine.start()
        clock.advance(by: 25 * 60)
        engine.poll()                       // now resting

        clock.advance(by: 60)               // 4 minutes of Rest still to go
        engine.emergencyShoo()

        #expect(engine.state == .working(endsAt: clock.now + 25 * 60))
        #expect(engine.remaining() == 25 * 60)
    }

    @Test func emergencyShooWhileWorkingLeavesTheWorkSessionUntouched() {
        let clock = TestClock()
        var engine = SessionEngine(workDuration: 25 * 60, clock: clock)
        engine.start()
        let originalEnd = clock.now + 25 * 60
        clock.advance(by: 60)

        engine.emergencyShoo()

        #expect(engine.state == .working(endsAt: originalEnd))
    }

    @Test func emergencyShooWhileIdleDoesNothing() {
        let clock = TestClock()
        var engine = SessionEngine(workDuration: 25 * 60, clock: clock)

        engine.emergencyShoo()

        #expect(engine.state == .idle)
    }

    @Test func emergencyShooConsumesOneOfThreeDailyUses() {
        let clock = TestClock()
        var engine = SessionEngine(workDuration: 25 * 60, restDuration: 5 * 60, clock: clock)
        #expect(engine.emergencyShoosRemaining() == 3)

        engine.startRest()
        engine.emergencyShoo()

        #expect(engine.emergencyShoosRemaining() == 2)
    }

    @Test func fourthEmergencyShooOfTheDayIsRejectedAndTheRestKeepsRunning() {
        let clock = TestClock()
        var engine = SessionEngine(workDuration: 25 * 60, restDuration: 5 * 60, clock: clock)
        for _ in 1...3 {                    // burn the whole daily budget
            engine.startRest()
            engine.emergencyShoo()
        }
        #expect(engine.emergencyShoosRemaining() == 0)

        engine.startRest()
        let restEnd = clock.now + 5 * 60
        engine.emergencyShoo()              // the exploit attempt

        #expect(engine.state == .resting(endsAt: restEnd))
        #expect(engine.emergencyShoosRemaining() == 0)
    }

    @Test func emergencyShooBudgetIsFullAgainAfterMidnight() {
        // A fixed-zone calendar so the test's midnight is the engine's midnight.
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let clock = TestClock(Date(timeIntervalSinceReferenceDate: 22 * 3600))  // 22:00 UTC
        var engine = SessionEngine(workDuration: 25 * 60, restDuration: 5 * 60, clock: clock, calendar: calendar)
        for _ in 1...3 {                    // burn the whole daily budget
            engine.startRest()
            engine.emergencyShoo()
        }
        #expect(engine.emergencyShoosRemaining() == 0)

        clock.advance(by: 3 * 3600)         // 01:00 the next day
        #expect(engine.emergencyShoosRemaining() == 3)

        engine.startRest()
        engine.emergencyShoo()              // a fresh day's budget is spendable

        #expect(engine.state == .working(endsAt: clock.now + 25 * 60))
        #expect(engine.emergencyShoosRemaining() == 2)
    }

    @Test func emergencyShooOutsideARestConsumesNoBudget() {
        let clock = TestClock()
        var engine = SessionEngine(workDuration: 25 * 60, restDuration: 5 * 60, clock: clock)

        engine.emergencyShoo()              // idle — nothing to escape
        engine.start()
        engine.emergencyShoo()              // working — a no-op too

        #expect(engine.emergencyShoosRemaining() == 3)
    }

    @Test func pauseFreezesTheRemainingTimeAcrossClockAdvancement() {
        let clock = TestClock()
        var engine = SessionEngine(workDuration: 25 * 60, clock: clock)
        engine.start()
        clock.advance(by: 10 * 60)          // 15 minutes remaining

        engine.pause()
        clock.advance(by: 60 * 60)          // a long time passes while paused

        #expect(engine.remaining() == 15 * 60)
    }

    @Test func resumeContinuesFromTheExactRemainingTime() {
        let clock = TestClock()
        var engine = SessionEngine(workDuration: 25 * 60, clock: clock)
        engine.start()
        clock.advance(by: 10 * 60)          // 15 minutes remaining
        engine.pause()
        clock.advance(by: 60 * 60)          // time passes while paused

        engine.resume()

        #expect(engine.state == .working(endsAt: clock.now + 15 * 60))
        #expect(engine.remaining() == 15 * 60)

        clock.advance(by: 5 * 60)           // and it counts down again
        #expect(engine.remaining() == 10 * 60)
    }

    @Test func pausedWorkSessionNeverTransitionsToRestOnItsOwn() {
        let clock = TestClock()
        var engine = SessionEngine(workDuration: 25 * 60, restDuration: 5 * 60, clock: clock)
        engine.start()
        clock.advance(by: 10 * 60)
        engine.pause()

        clock.advance(by: 60 * 60)          // well past the original work end
        engine.poll()

        #expect(engine.state == .paused(remaining: 15 * 60))
    }

    @Test func pauseDuringARestIsIgnored() {
        let clock = TestClock()
        var engine = SessionEngine(workDuration: 25 * 60, restDuration: 5 * 60, clock: clock)
        engine.start()
        clock.advance(by: 25 * 60)
        engine.poll()                       // now resting
        let restEnd = clock.now + 5 * 60

        engine.pause()

        #expect(engine.state == .resting(endsAt: restEnd))
    }

    @Test func startRestFromIdleBeginsATimedRestOfTheConfiguredLength() {
        let clock = TestClock()
        var engine = SessionEngine(workDuration: 25 * 60, restDuration: 5 * 60, clock: clock)

        engine.startRest()

        #expect(engine.state == .resting(endsAt: clock.now + 5 * 60))
        #expect(engine.restRemaining() == 5 * 60)
    }

    @Test func startRestDuringAWorkSessionCutsItShortIntoARest() {
        let clock = TestClock()
        var engine = SessionEngine(workDuration: 25 * 60, restDuration: 5 * 60, clock: clock)
        engine.start()
        clock.advance(by: 10 * 60)          // 15 minutes of work still to go

        engine.startRest()

        #expect(engine.state == .resting(endsAt: clock.now + 5 * 60))
        #expect(engine.restRemaining() == 5 * 60)
    }

    @Test func startRestWhileAlreadyRestingDoesNotRestartTheRest() {
        let clock = TestClock()
        var engine = SessionEngine(workDuration: 25 * 60, restDuration: 5 * 60, clock: clock)
        engine.start()
        clock.advance(by: 25 * 60)
        engine.poll()                       // now resting, ends 5 min from here
        let restEnd = clock.now + 5 * 60

        clock.advance(by: 2 * 60)           // 3 minutes of Rest still to go
        engine.startRest()

        // The original Rest keeps its end-time; it isn't extended back to a full 5.
        #expect(engine.state == .resting(endsAt: restEnd))
        #expect(engine.restRemaining() == 3 * 60)
    }

    @Test func startRestFromAPausedWorkSessionBeginsARest() {
        let clock = TestClock()
        var engine = SessionEngine(workDuration: 25 * 60, restDuration: 5 * 60, clock: clock)
        engine.start()
        clock.advance(by: 10 * 60)
        engine.pause()                      // frozen, 15 minutes remaining

        engine.startRest()

        #expect(engine.state == .resting(endsAt: clock.now + 5 * 60))
        #expect(engine.restRemaining() == 5 * 60)
    }

    @Test func restCompletedFlipsTrueTheInstantTheRestTimerElapses() {
        let clock = TestClock()
        var engine = SessionEngine(workDuration: 25 * 60, restDuration: 5 * 60, clock: clock)
        engine.start()
        clock.advance(by: 25 * 60)
        engine.poll()                       // now resting

        #expect(engine.restCompleted() == false)   // the Rest just began

        clock.advance(by: 5 * 60)           // Rest fully elapsed, Visual still up
        #expect(engine.restCompleted() == true)
    }

    @Test func restCompletedIsFalseOutsideARest() {
        let clock = TestClock()
        var engine = SessionEngine(workDuration: 25 * 60, restDuration: 5 * 60, clock: clock)

        #expect(engine.restCompleted() == false)   // idle

        engine.start()
        clock.advance(by: 26 * 60)          // work elapsed, but poll not yet called
        #expect(engine.restCompleted() == false)   // still (over-)working
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
