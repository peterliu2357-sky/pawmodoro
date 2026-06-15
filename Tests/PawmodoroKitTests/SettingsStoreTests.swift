import Foundation
import Testing
@testable import PawmodoroKit

@Suite struct PomodoroSettingsTests {
    @Test func durationsAreClampedToTheirAllowedRanges() {
        let tooLong = PomodoroSettings(workDuration: 999 * 60, restDuration: 999 * 60, launchAtLogin: false)
        #expect(tooLong.workDuration == PomodoroSettings.workRange.upperBound)
        #expect(tooLong.restDuration == PomodoroSettings.restRange.upperBound)

        let tooShort = PomodoroSettings(workDuration: 0, restDuration: 0, launchAtLogin: false)
        #expect(tooShort.workDuration == PomodoroSettings.workRange.lowerBound)
        #expect(tooShort.restDuration == PomodoroSettings.restRange.lowerBound)
    }
}

/// An in-memory stand-in for the real (UserDefaults-backed) persistence.
final class FakePersistence: SettingsPersistence, @unchecked Sendable {
    var stored: PomodoroSettings?
    func load() -> PomodoroSettings? { stored }
    func save(_ settings: PomodoroSettings) { stored = settings }
}

@Suite struct SettingsStoreTests {
    @Test func updatedSettingsSurviveBeingReloadedFromPersistence() {
        let persistence = FakePersistence()
        let store = SettingsStore(persistence: persistence)
        let edited = PomodoroSettings(workDuration: 30 * 60, restDuration: 10 * 60, launchAtLogin: true)

        store.update(edited)
        let reloaded = SettingsStore(persistence: persistence)

        #expect(reloaded.settings == edited)
    }

    @Test func fallsBackToTheDefaultsWhenNothingHasBeenPersisted() {
        let store = SettingsStore(persistence: FakePersistence())

        #expect(store.settings == .default)
    }
}
