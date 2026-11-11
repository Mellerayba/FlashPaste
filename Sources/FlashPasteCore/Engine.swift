/// Something that must be torn down when the engine is disabled (event tap, observer, timers).
public protocol Invalidatable: AnyObject {
    func invalidate()
}

/// Owns the enabled/disabled lifecycle, the pending capture and the card state.
/// Event resources are created by an injected factory so the lifecycle can be unit tested.
public final class Engine {
    public static let historyLimit = 10

    public private(set) var isEnabled = false
    public private(set) var pending: String?
    public private(set) var history: [String] = []
    public var state = CardState()
    public var log: (String) -> Void = { _ in }

    private var resources: [Invalidatable] = []
    private let makeResources: () -> [Invalidatable]?

    /// `makeResources` returns nil when the resources could not be created (e.g. no event tap permission).
    public init(makeResources: @escaping () -> [Invalidatable]?) {
        self.makeResources = makeResources
    }

    public var resourceCount: Int { resources.count }

    /// Idempotent: never creates a second set of resources.
    @discardableResult
    public func enable() -> Bool {
        if isEnabled { log("enable: already enabled"); return true }
        guard let created = makeResources() else { log("enable: failed to create event resources"); return false }
        resources = created
        isEnabled = true
        log("enabled")
        return true
    }

    /// Complete teardown: invalidates every resource, clears pending, resets the field state.
    public func disable() {
        guard isEnabled else { return }
        resources.forEach { $0.invalidate() }
        resources = []
        pending = nil
        state.reset()
        isEnabled = false
        log("disabled")
    }

    public func setPending(_ text: String) {
        pending = text
        history.removeAll { $0 == text }
        history.insert(text, at: 0)
        if history.count > Engine.historyLimit { history.removeLast(history.count - Engine.historyLimit) }
        log("pending set (\(text.count) chars)")
    }

    public func clearPending() {
        guard pending != nil else { return }
        pending = nil
        log("pending cleared")
    }
}
