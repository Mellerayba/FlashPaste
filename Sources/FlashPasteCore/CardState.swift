/// Which Quizlet field the next paste goes into.
public enum Field: String, Equatable {
    case term, def

    public var next: Field { self == .term ? .def : .term }
    public var label: String { self == .term ? "term" : "definition" }
}

public struct PasteRecord: Equatable {
    public let field: Field
    public let tabs: Int
    public init(field: Field, tabs: Int) { self.field = field; self.tabs = tabs }
}

/// The term/definition alternation state machine.
public struct CardState: Equatable {
    public private(set) var nextField: Field = .term
    public private(set) var lastPaste: PasteRecord?

    public init() {}

    public func tabs(after field: Field, config: Config) -> Int {
        field == .term ? config.tabsAfterTerm : config.tabsAfterDef
    }

    /// Records a paste into `nextField`, advances, and returns what was pasted and how many Tabs follow.
    @discardableResult
    public mutating func didPaste(config: Config) -> PasteRecord {
        let record = PasteRecord(field: nextField, tabs: tabs(after: nextField, config: config))
        nextField = nextField.next
        lastPaste = record
        return record
    }

    public mutating func reset() {
        nextField = .term
        lastPaste = nil
    }

    /// Steps back one paste. Returns the paste being undone, or nil when there is nothing to undo.
    public mutating func undo() -> PasteRecord? {
        guard let record = lastPaste else { return nil }
        nextField = record.field
        lastPaste = nil
        return record
    }
}
