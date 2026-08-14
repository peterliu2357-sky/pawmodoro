import Foundation

/// The state of the Work → Pounce → Rest loop.
///
/// A Rest is timed and locked: it carries the wall-clock instant at which it
/// completes. Before that instant a Shoo is rejected (Snap-back); after it, a
/// Shoo starts a fresh Work Session.
public enum SessionState: Equatable, Sendable {
    case idle
    case working(endsAt: Date)
    /// A Work Session frozen by the user, holding the seconds that remained when
    /// it was paused. The countdown does not advance and never becomes a Rest.
    case paused(remaining: TimeInterval)
    case resting(endsAt: Date)
}

/// The result of attempting a Shoo while resting.
public enum ShooOutcome: Equatable, Sendable {
    /// The Rest had completed; the Visual leaves and a fresh Work Session begins.
    case accepted
    /// The Rest was still running; the Visual springs back and the Rest continues.
    case snappedBack
}

/// Pure domain logic for the Work loop. Holds no AppKit dependency; time comes
/// from an injected `Clock` so behavior is fully testable.
public struct SessionEngine: Sendable {
    /// How many Emergency Shoos a single day allows. The cap makes reflexively
    /// escaping every Rest costly without truly trapping anyone: it lives only
    /// in memory, so quitting and relaunching the app is the (deliberately
    /// inconvenient) way past it.
    public static let emergencyShooDailyLimit = 3

    public private(set) var workDuration: TimeInterval
    public private(set) var restDuration: TimeInterval
    private let clock: Clock
    private let calendar: Calendar
    public private(set) var state: SessionState

    // The day (start-of-day) the last Emergency Shoo was consumed in, and how
    // many that day has consumed. A day change simply makes both stale.
    private var emergencyShooDay: Date?
    private var emergencyShoosUsed = 0

    public init(
        workDuration: TimeInterval = 25 * 60,
        restDuration: TimeInterval = 5 * 60,
        clock: Clock,
        calendar: Calendar = .current
    ) {
        self.workDuration = workDuration
        self.restDuration = restDuration
        self.clock = clock
        self.calendar = calendar
        self.state = .idle
    }

    /// Updates the configured durations. The change applies to the next Work
    /// Session and Rest; any session already running keeps its original
    /// end-time, since that instant is baked into the current state.
    public mutating func configure(workDuration: TimeInterval, restDuration: TimeInterval) {
        self.workDuration = workDuration
        self.restDuration = restDuration
    }

    /// Begins a fresh Work Session of the full configured duration.
    public mutating func start() {
        state = .working(endsAt: clock.now + workDuration)
    }

    /// Begins a timed Rest of the full configured length right now — the same
    /// transition `poll` makes when a Work Session elapses, but on demand. A
    /// no-op while already resting, so it never restarts (extends) a Rest the
    /// user is already serving out from under them.
    public mutating func startRest() {
        guard !isResting else { return }
        state = .resting(endsAt: clock.now + restDuration)
    }

    private var isResting: Bool {
        if case .resting = state { return true }
        return false
    }

    /// Advances the state machine to the current wall-clock time. When a Work
    /// Session's timer has elapsed, the Visual pounces and a Rest begins. Call
    /// this periodically from the presentation layer.
    public mutating func poll() {
        guard case let .working(endsAt) = state else { return }
        if clock.now >= endsAt {
            state = .resting(endsAt: clock.now + restDuration)
        }
    }

    /// Freezes a running Work Session, capturing the seconds that remain so a
    /// later `resume` can continue from exactly here. A no-op unless working —
    /// a Rest is the enforced part of the loop and cannot be paused.
    public mutating func pause() {
        guard case .working = state else { return }
        state = .paused(remaining: remaining())
    }

    /// Continues a paused Work Session from exactly where it left off, anchoring
    /// a fresh end-time to the current clock. A no-op unless paused.
    public mutating func resume() {
        guard case let .paused(remaining) = state else { return }
        state = .working(endsAt: clock.now + remaining)
    }

    /// Ends the loop entirely and returns to Idle, from any state.
    public mutating func stop() {
        state = .idle
    }

    /// The user has flicked the Visual off a screen edge. If the Rest has not yet
    /// completed the attempt is rejected and the Visual snaps back; otherwise the
    /// Rest ends and a fresh, full-length Work Session begins on the gesture.
    @discardableResult
    public mutating func attemptShoo() -> ShooOutcome {
        guard case .resting = state else { return .snappedBack }
        if restRemaining() > 0 {
            return .snappedBack
        }
        start()
        return .accepted
    }

    /// The escape hatch: force-ends an active Rest immediately, ignoring the
    /// Snap-back lock and any remaining Rest time, and begins a fresh full-length
    /// Work Session. A no-op while working or idle — there is no Rest to escape,
    /// and we must not reset a running Work Session out from under the user.
    public mutating func emergencyShoo() {
        guard case .resting = state else { return }
        guard emergencyShoosRemaining() > 0 else { return }
        let today = calendar.startOfDay(for: clock.now)
        if emergencyShooDay != today {      // first consumption of a fresh day
            emergencyShooDay = today
            emergencyShoosUsed = 0
        }
        emergencyShoosUsed += 1
        start()
    }

    /// How many Emergency Shoos are left today. Full again once the calendar
    /// day rolls over at midnight.
    public func emergencyShoosRemaining() -> Int {
        guard let day = emergencyShooDay, calendar.isDate(clock.now, inSameDayAs: day) else {
            return Self.emergencyShooDailyLimit
        }
        return max(0, Self.emergencyShooDailyLimit - emergencyShoosUsed)
    }

    /// Seconds left in the current Work Session, derived from the wall-clock
    /// (target end-time vs. now) rather than accumulated ticks. Zero when not
    /// in a Work Session.
    public func remaining() -> TimeInterval {
        switch state {
        case let .working(endsAt): return max(0, endsAt.timeIntervalSince(clock.now))
        case let .paused(remaining): return remaining
        default: return 0
        }
    }

    /// True from the instant an active Rest's timer elapses until the Rest ends —
    /// the stretch where the Visual is still up but a Shoo would be accepted. The
    /// presentation uses this to switch the Visual from its sleepy look to its
    /// awake one. False in every other state.
    public func restCompleted() -> Bool {
        guard case .resting = state else { return false }
        return restRemaining() <= 0
    }

    /// Seconds left in the current Rest, derived from the wall-clock. Zero when
    /// not resting, or once the Rest has completed (at which point a Shoo is
    /// accepted instead of triggering a Snap-back).
    public func restRemaining() -> TimeInterval {
        guard case let .resting(endsAt) = state else { return 0 }
        return max(0, endsAt.timeIntervalSince(clock.now))
    }
}
