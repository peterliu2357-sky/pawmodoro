import Foundation

/// Identifies a connected display, independent of AppKit. The presentation layer
/// maps these to real screens; the orchestrator only ever compares identities.
public struct DisplayID: Hashable, Sendable {
    public let rawValue: UInt32
    public init(_ rawValue: UInt32) { self.rawValue = rawValue }
}

/// Supplies the set of currently-connected displays. Injected so the
/// orchestrator carries no real `NSScreen` dependency.
@MainActor
public protocol DisplayProvider: AnyObject {
    var displays: [DisplayID] { get }
}

/// One Coverage Visual, abstracted so the orchestrator can manage it without
/// knowing it is an AppKit window.
@MainActor
public protocol CoverageVisual: AnyObject {
    func show()
    func close()
}

/// Coordinates Coverage across every connected display. During a Rest there is
/// exactly one Visual per display; during a Work Session there are none. The
/// Rest is a single global state, so one accepted Shoo on any display clears the
/// cats everywhere.
@MainActor
public final class CoverageOrchestrator {
    private let displayProvider: DisplayProvider
    private let onShoo: () -> ShooOutcome
    private let makeVisual: (DisplayID, @escaping () -> ShooOutcome) -> CoverageVisual

    private var visuals: [DisplayID: CoverageVisual] = [:]
    private var covering = false

    public init(
        displayProvider: DisplayProvider,
        onShoo: @escaping () -> ShooOutcome,
        makeVisual: @escaping (DisplayID, @escaping () -> ShooOutcome) -> CoverageVisual
    ) {
        self.displayProvider = displayProvider
        self.onShoo = onShoo
        self.makeVisual = makeVisual
    }

    /// Reconciles the on-screen Visuals to the engine's state and the current
    /// display set. Call whenever the Rest begins/ends.
    public func update(covering: Bool) {
        self.covering = covering
        reconcile()
    }

    /// The set of connected displays changed (a monitor was plugged in or
    /// removed). Re-reconciles so a mid-Rest hotplug adds or removes its cat.
    public func displaysChanged() {
        reconcile()
    }

    /// Brings the on-screen Visual set in line with `covering` and the current
    /// displays: one Visual per display while covering, none otherwise.
    private func reconcile() {
        let wanted = covering ? Set(displayProvider.displays) : []
        for (id, visual) in visuals where !wanted.contains(id) {
            visual.close()
            visuals[id] = nil
        }
        for id in wanted where visuals[id] == nil {
            let visual = makeVisual(id) { [weak self] in self?.shoo(from: id) ?? .snappedBack }
            visuals[id] = visual
            visual.show()
        }
    }

    /// A Visual on `id` was flicked off its edge. The Rest is global, so an
    /// accepted Shoo ends Coverage everywhere: the flicked Visual closes itself
    /// as part of its fly-off, and we clear the cats on every other display. A
    /// Snap-back leaves the Visuals in place (the Visual itself springs back).
    private func shoo(from id: DisplayID) -> ShooOutcome {
        let outcome = onShoo()
        if outcome == .accepted {
            covering = false
            for (other, visual) in visuals where other != id {
                visual.close()
                visuals[other] = nil
            }
            // The flicked Visual stays referenced so its fly-off can finish; the
            // next reconcile (now not covering) closes and removes it.
        }
        return outcome
    }
}
