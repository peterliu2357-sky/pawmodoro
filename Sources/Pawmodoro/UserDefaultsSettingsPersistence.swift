import Foundation
import PawmodoroKit

/// Persists `PomodoroSettings` in `UserDefaults`. The three primitive fields are
/// stored under stable keys; `load()` returns `nil` until something has been
/// written, so a first launch falls back to the defaults. `PomodoroSettings`
/// re-clamps the durations on construction, so even a hand-edited or corrupt
/// preference can never feed the engine an absurd value.
/// `@unchecked Sendable`: the only stored property is `UserDefaults`, which is
/// documented thread-safe even though it isn't annotated `Sendable`.
struct UserDefaultsSettingsPersistence: SettingsPersistence, @unchecked Sendable {
    private enum Key {
        static let work = "pawmodoro.workDuration"
        static let rest = "pawmodoro.restDuration"
        static let launch = "pawmodoro.launchAtLogin"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    func load() -> PomodoroSettings? {
        // Absence of the work key marks a never-saved store → use the defaults.
        guard defaults.object(forKey: Key.work) != nil else { return nil }
        return PomodoroSettings(
            workDuration: defaults.double(forKey: Key.work),
            restDuration: defaults.double(forKey: Key.rest),
            launchAtLogin: defaults.bool(forKey: Key.launch)
        )
    }

    func save(_ settings: PomodoroSettings) {
        defaults.set(settings.workDuration, forKey: Key.work)
        defaults.set(settings.restDuration, forKey: Key.rest)
        defaults.set(settings.launchAtLogin, forKey: Key.launch)
    }
}
