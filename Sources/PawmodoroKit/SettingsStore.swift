import Foundation

/// Where `PomodoroSettings` is persisted between launches. Injected so the store
/// can be tested in memory; the app backs it with `UserDefaults`.
public protocol SettingsPersistence: Sendable {
    /// The persisted settings, or `nil` if nothing has been saved yet.
    func load() -> PomodoroSettings?
    func save(_ settings: PomodoroSettings)
}

/// Holds the current `PomodoroSettings`, seeding from persistence on launch and
/// writing every change straight back. The presentation layer reads `settings`
/// to drive the UI and to configure the Session Engine before each session.
public final class SettingsStore {
    public private(set) var settings: PomodoroSettings
    private let persistence: SettingsPersistence

    /// Loads the persisted settings, falling back to the defaults on first run.
    public init(persistence: SettingsPersistence) {
        self.persistence = persistence
        self.settings = persistence.load() ?? .default
    }

    /// Replaces the settings and persists them immediately.
    public func update(_ settings: PomodoroSettings) {
        self.settings = settings
        persistence.save(settings)
    }
}
