import Foundation

/// The state of the Work → Pounce → Rest loop.
///
/// A Rest is timed and locked: it carries the wall-clock instant at which it
/// completes. Before that instant a Shoo is rejected (Snap-back); after it, a
/// Shoo starts a fresh Work Session.
public enum SessionState: Equatable, Sendable {
    case idle
    case working(endsAt: Date)
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
    public let workDuration: TimeInterval
    public let restDuration: TimeInterval
    private let clock: Clock
    public private(set) var state: SessionState

    public init(workDuration: TimeInterval = 25 * 60, restDuration: TimeInterval = 5 * 60, clock: Clock) {
        self.workDuration = workDuration
        self.restDuration = restDuration
        self.clock = clock
        self.state = .idle
    }

    /// Begins a fresh Work Session of the full configured duration.
    public mutating func start() {
        state = .working(endsAt: clock.now + workDuration)
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

    /// Seconds left in the current Work Session, derived from the wall-clock
    /// (target end-time vs. now) rather than accumulated ticks. Zero when not
    /// in a Work Session.
    public func remaining() -> TimeInterval {
        guard case let .working(endsAt) = state else { return 0 }
        return max(0, endsAt.timeIntervalSince(clock.now))
    }

    /// Seconds left in the current Rest, derived from the wall-clock. Zero when
    /// not resting, or once the Rest has completed (at which point a Shoo is
    /// accepted instead of triggering a Snap-back).
    public func restRemaining() -> TimeInterval {
        guard case let .resting(endsAt) = state else { return 0 }
        return max(0, endsAt.timeIntervalSince(clock.now))
    }
}
