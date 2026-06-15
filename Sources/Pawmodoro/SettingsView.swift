import PawmodoroKit
import SwiftUI

/// The Settings pane: steppers for the two durations and a Launch-at-login
/// toggle. Edits are seeded from the current `PomodoroSettings` and pushed back
/// out through `apply` on every change, so there is no Save button to forget.
/// The stepper ranges mirror `PomodoroSettings`' clamps (shown in minutes);
/// `PomodoroSettings` is the real guardrail, this is just a convenience.
struct SettingsView: View {
    @State private var workMinutes: Double
    @State private var restMinutes: Double
    @State private var launchAtLogin: Bool

    /// Hands the edited settings to the app to persist and apply.
    private let apply: (PomodoroSettings) -> Void

    init(settings: PomodoroSettings, apply: @escaping (PomodoroSettings) -> Void) {
        _workMinutes = State(initialValue: (settings.workDuration / 60).rounded())
        _restMinutes = State(initialValue: (settings.restDuration / 60).rounded())
        _launchAtLogin = State(initialValue: settings.launchAtLogin)
        self.apply = apply
    }

    var body: some View {
        Form {
            Stepper("Work session: \(Int(workMinutes)) min", value: $workMinutes, in: 1...60)
            Stepper("Rest: \(Int(restMinutes)) min", value: $restMinutes, in: 1...30)
            Toggle("Launch at login", isOn: $launchAtLogin)
            Text("Duration changes take effect on your next session.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(width: 300)
        .onChange(of: workMinutes) { commit() }
        .onChange(of: restMinutes) { commit() }
        .onChange(of: launchAtLogin) { commit() }
    }

    private func commit() {
        apply(PomodoroSettings(
            workDuration: workMinutes * 60,
            restDuration: restMinutes * 60,
            launchAtLogin: launchAtLogin
        ))
    }
}
