import Foundation
import Testing
@testable import PawmodoroKit

/// A display set the test controls by hand.
@MainActor
final class FakeDisplayProvider: DisplayProvider {
    var displays: [DisplayID]
    init(_ displays: [DisplayID]) { self.displays = displays }
}

/// A stand-in for a real Coverage window; records whether it is on screen and
/// can replay a Shoo (a flick off the edge) the way a real window would.
@MainActor
final class FakeVisual: CoverageVisual {
    private(set) var isShown = false
    private let onShoo: () -> ShooOutcome
    init(onShoo: @escaping () -> ShooOutcome) { self.onShoo = onShoo }
    func show() { isShown = true }
    func close() { isShown = false }

    /// Models a real flick: report the Shoo, and on `.accepted` the Visual
    /// closes itself as part of its fly-off (the orchestrator clears the rest).
    @discardableResult func flickOffEdge() -> ShooOutcome {
        let outcome = onShoo()
        if outcome == .accepted { close() }
        return outcome
    }
}

@MainActor
@Suite struct CoverageOrchestratorTests {
    /// Builds an orchestrator and tracks every visual it creates so tests can
    /// count the ones currently on screen.
    private func makeOrchestrator(
        displays: FakeDisplayProvider,
        onShoo: @escaping () -> ShooOutcome = { .snappedBack }
    ) -> (CoverageOrchestrator, () -> [FakeVisual]) {
        var created: [FakeVisual] = []
        let orchestrator = CoverageOrchestrator(
            displayProvider: displays,
            onShoo: onShoo,
            makeVisual: { _, shoo in
                let v = FakeVisual(onShoo: shoo)
                created.append(v)
                return v
            }
        )
        return (orchestrator, { created.filter(\.isShown) })
    }

    @Test func noVisualsWhenNotCovering() {
        let displays = FakeDisplayProvider([DisplayID(1), DisplayID(2)])
        let (orchestrator, shown) = makeOrchestrator(displays: displays)

        orchestrator.update(covering: false)

        #expect(shown().count == 0)
    }

    @Test func oneVisualPerDisplayWhileCovering() {
        let displays = FakeDisplayProvider([DisplayID(1)])
        let (orchestrator, shown) = makeOrchestrator(displays: displays)

        orchestrator.update(covering: true)

        #expect(shown().count == 1)
    }

    @Test func oneVisualPerDisplayAcrossMultipleDisplays() {
        let displays = FakeDisplayProvider([DisplayID(1), DisplayID(2)])
        let (orchestrator, shown) = makeOrchestrator(displays: displays)

        orchestrator.update(covering: true)

        #expect(shown().count == 2)
    }

    @Test func oneAcceptedShooClearsEveryDisplay() {
        let displays = FakeDisplayProvider([DisplayID(1), DisplayID(2)])
        let (orchestrator, shown) = makeOrchestrator(displays: displays, onShoo: { .accepted })
        orchestrator.update(covering: true)

        shown().first?.flickOffEdge()   // a single Shoo on one display

        #expect(shown().count == 0)
    }

    @Test func snappedBackShooLeavesEveryVisualInPlace() {
        let displays = FakeDisplayProvider([DisplayID(1), DisplayID(2)])
        let (orchestrator, shown) = makeOrchestrator(displays: displays, onShoo: { .snappedBack })
        orchestrator.update(covering: true)

        shown().first?.flickOffEdge()   // an early Shoo, rejected

        #expect(shown().count == 2)
    }

    @Test func displayHotplugUpdatesTheVisualSetMidRest() {
        let displays = FakeDisplayProvider([DisplayID(1)])
        let (orchestrator, shown) = makeOrchestrator(displays: displays)
        orchestrator.update(covering: true)
        #expect(shown().count == 1)

        displays.displays = [DisplayID(1), DisplayID(2)]   // a display is connected
        orchestrator.displaysChanged()
        #expect(shown().count == 2)

        displays.displays = [DisplayID(2)]                 // display 1 is disconnected
        orchestrator.displaysChanged()
        #expect(shown().count == 1)
    }
}
