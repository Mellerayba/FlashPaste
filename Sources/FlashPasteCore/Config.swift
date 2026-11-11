import Foundation

/// On/off switches shown in the Preferences submenu and stored in config.json.
public enum Toggle: String, CaseIterable {
    case cleanPDFText, stripBullets, captureFeedback, autoPause, captureHistory, undoLastPaste

    public var title: String {
        switch self {
        case .cleanPDFText:    return "Clean PDF text (join lines, fix hyphens)"
        case .stripBullets:    return "Strip leading bullets and numbering"
        case .captureFeedback: return "Capture feedback (sound and HUD)"
        case .autoPause:       return "Only capture while a Quizlet window exists"
        case .captureHistory:  return "Keep capture history (last 10)"
        case .undoLastPaste:   return "Undo last paste hotkey (⌃⌥Z)"
        }
    }

    public var defaultValue: Bool { self == .cleanPDFText }
}

public struct Config: Equatable {
    public var sourceApps = ["com.apple.Safari", "com.apple.Preview"]
    public var quizletApps = ["com.apple.Safari"]
    public var quizletTitlePattern = "Quizlet"
    public var focusDelay = 0.15
    public var tabsAfterTerm = 1
    public var tabsAfterDef = 1
    public var toggles = Dictionary(uniqueKeysWithValues: Toggle.allCases.map { ($0, $0.defaultValue) })
    /// Keys this version does not understand, preserved verbatim when saving.
    public var unknown: [String: Any] = [:]

    public init() {}

    public subscript(toggle: Toggle) -> Bool {
        get { toggles[toggle] ?? toggle.defaultValue }
        set { toggles[toggle] = newValue }
    }

    public var cleanOptions: CleanOptions {
        CleanOptions(joinLines: self[.cleanPDFText], stripBullets: self[.stripBullets])
    }

    public static func == (a: Config, b: Config) -> Bool {
        a.sourceApps == b.sourceApps && a.quizletApps == b.quizletApps
            && a.quizletTitlePattern == b.quizletTitlePattern && a.focusDelay == b.focusDelay
            && a.tabsAfterTerm == b.tabsAfterTerm && a.tabsAfterDef == b.tabsAfterDef && a.toggles == b.toggles
    }

    static let knownKeys = ["sourceApps", "quizletApps", "quizletTitlePattern", "focusDelay",
                            "tabsAfterTerm", "tabsAfterDef"] + Toggle.allCases.map(\.rawValue)

    public struct LoadResult {
        public let config: Config
        public let warnings: [String]
    }

    /// Parses config JSON. Invalid JSON or a non-object falls back to defaults; bad individual
    /// values fall back to that key's default. Problems are reported as warnings.
    public static func parse(_ data: Data) -> LoadResult {
        guard let object = try? JSONSerialization.jsonObject(with: data), let dict = object as? [String: Any] else {
            return LoadResult(config: Config(), warnings: ["config is not valid JSON; using defaults"])
        }
        var config = Config()
        var warnings: [String] = []
        func read<T>(_ key: String, _ cast: (Any) -> T?, _ valid: (T) -> Bool = { _ in true }, _ apply: (T) -> Void) {
            guard let raw = dict[key] else { return }
            if let value = cast(raw), valid(value) { apply(value) } else { warnings.append("ignoring invalid value for \"\(key)\"") }
        }
        read("sourceApps", { $0 as? [String] }, { !$0.isEmpty }) { config.sourceApps = $0 }
        read("quizletApps", { $0 as? [String] }, { !$0.isEmpty }) { config.quizletApps = $0 }
        read("quizletTitlePattern", { $0 as? String }, { !$0.isEmpty }) { config.quizletTitlePattern = $0 }
        read("focusDelay", { $0 as? Double }, { $0 >= 0 && $0 <= 10 }) { config.focusDelay = $0 }
        read("tabsAfterTerm", { $0 as? Int }, { (0...20).contains($0) }) { config.tabsAfterTerm = $0 }
        read("tabsAfterDef", { $0 as? Int }, { (0...20).contains($0) }) { config.tabsAfterDef = $0 }
        for toggle in Toggle.allCases {
            read(toggle.rawValue, { $0 as? Bool }) { config[toggle] = $0 }
        }
        config.unknown = dict.filter { !knownKeys.contains($0.key) }
        return LoadResult(config: config, warnings: warnings)
    }

    /// Serialises the config, keeping unknown keys. Output is pretty-printed with sorted keys.
    public func jsonData() throws -> Data {
        var dict = unknown
        dict["sourceApps"] = sourceApps
        dict["quizletApps"] = quizletApps
        dict["quizletTitlePattern"] = quizletTitlePattern
        dict["focusDelay"] = focusDelay
        dict["tabsAfterTerm"] = tabsAfterTerm
        dict["tabsAfterDef"] = tabsAfterDef
        for toggle in Toggle.allCases { dict[toggle.rawValue] = self[toggle] }
        return try JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys])
    }
}
