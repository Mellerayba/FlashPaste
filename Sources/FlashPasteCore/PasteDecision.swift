import Foundation

public struct PasteContext {
    public var pending: String?
    public var appBundleID: String?
    public var windowTitle: String?
    public var isSourceWindow: Bool
    public var enabled: Bool

    public init(pending: String?, appBundleID: String?, windowTitle: String?, isSourceWindow: Bool, enabled: Bool) {
        self.pending = pending
        self.appBundleID = appBundleID
        self.windowTitle = windowTitle
        self.isSourceWindow = isSourceWindow
        self.enabled = enabled
    }
}

public enum PasteDecision {
    /// True when a focused window is the Quizlet window and there is something to paste into it.
    public static func shouldPaste(_ ctx: PasteContext, config: Config) -> Bool {
        guard ctx.enabled, let pending = ctx.pending, !pending.isEmpty, !ctx.isSourceWindow else { return false }
        guard let bundleID = ctx.appBundleID, config.quizletApps.contains(bundleID) else { return false }
        return titleMatches(ctx.windowTitle, config)
    }

    public static func titleMatches(_ title: String?, _ config: Config) -> Bool {
        guard let title, !config.quizletTitlePattern.isEmpty else { return false }
        return title.range(of: config.quizletTitlePattern, options: .caseInsensitive) != nil
    }
}
