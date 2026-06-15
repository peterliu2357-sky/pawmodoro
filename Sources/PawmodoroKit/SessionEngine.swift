import Foundation

/// The state of the Work → Pounce → Rest loop.
///
/// Slice 1 models a placeholder `resting` state with no timer: any dismiss
/// returns to a fresh Work Session. The timed, locked Rest with Snap-back
/// arrives in a later slice.
public enum SessionState: Equatable, Sendable {
    case idle
    case working(endsAt: Date)
    case resting
}

/// Pure domain logic for the Work loop. Holds no AppKit dependency; time comes
/// from an injected `Clock` so behavior is fully testable.
public struct SessionEngine: Sendable {
    public let workDuration: TimeInterval
    private let clock: Clock
    public private(set) var state: SessionState

    public init(workDuration: TimeInterval = 25 * 60, clock: Clock) {
        self.workDuration = workDuration
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
            state = .resting
        }
    }

    /// Ends the loop entirely and returns to Idle, from any state.
    public mutating func stop() {
        state = .idle
    }

    /// Clears the Visual and begins the next Work Session at its full configured
    /// duration. Slice 1 placeholder for the Shoo gesture; the timed, locked Rest
    /// (with Snap-back before the Rest completes) arrives in a later slice.
    public mutating func dismiss() {
        guard case .resting = state else { return }
        start()
    }

    /// Seconds left in the current Work Session, derived from the wall-clock
    /// (target end-time vs. now) rather than accumulated ticks. Zero when not
    /// in a Work Session.
    public func remaining() -> TimeInterval {
        guard case let .working(endsAt) = state else { return 0 }
        return max(0, endsAt.timeIntervalSince(clock.now))
    }
}
