import Foundation

/// A source of the current wall-clock time. Injected into the Session Engine so
/// remaining time can be derived from a target end-time rather than accumulated
/// ticks, and so tests can advance time deterministically.
public protocol Clock: Sendable {
    var now: Date { get }
}

/// The real clock, backed by the system wall-clock.
public struct SystemClock: Clock {
    public init() {}
    public var now: Date { Date() }
}
