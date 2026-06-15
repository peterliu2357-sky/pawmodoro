import Foundation

/// The user-adjustable configuration for the Work → Pounce → Rest loop: the two
/// durations and whether Pawmodoro launches at login. A value type so it is
/// trivially testable and `Sendable`; the presentation layer persists it and
/// feeds the durations into the Session Engine.
///
/// Durations are clamped to sensible ranges on construction, so a settings UI
/// (or a corrupt persisted value) can never push the engine to an absurd state.
public struct PomodoroSettings: Equatable, Sendable {
    /// Allowed Work Session length: 1 minute to 1 hour.
    public static let workRange: ClosedRange<TimeInterval> = (1 * 60)...(60 * 60)
    /// Allowed Rest length: 1 minute to 30 minutes.
    public static let restRange: ClosedRange<TimeInterval> = (1 * 60)...(30 * 60)

    /// The out-of-the-box configuration: a classic 25/5 Pomodoro, no login item.
    public static let `default` = PomodoroSettings(workDuration: 25 * 60, restDuration: 5 * 60, launchAtLogin: false)

    public let workDuration: TimeInterval
    public let restDuration: TimeInterval
    public let launchAtLogin: Bool

    public init(workDuration: TimeInterval, restDuration: TimeInterval, launchAtLogin: Bool) {
        self.workDuration = Self.workRange.clamping(workDuration)
        self.restDuration = Self.restRange.clamping(restDuration)
        self.launchAtLogin = launchAtLogin
    }
}

private extension ClosedRange where Bound: Comparable {
    func clamping(_ value: Bound) -> Bound { Swift.min(upperBound, Swift.max(lowerBound, value)) }
}
