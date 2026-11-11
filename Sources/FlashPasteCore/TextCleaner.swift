import Foundation

public struct CleanOptions: Equatable {
    public var joinLines: Bool
    public var stripBullets: Bool
    public init(joinLines: Bool = true, stripBullets: Bool = false) {
        self.joinLines = joinLines
        self.stripBullets = stripBullets
    }
}

/// Tidies captured text. It never changes wording: only whitespace, line breaks,
/// hyphenation artefacts and leading list markers.
public enum TextCleaner {
    public static func clean(_ text: String, options: CleanOptions) -> String {
        var s = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        if options.stripBullets {
            s = s.components(separatedBy: "\n").map(stripBullet).joined(separator: "\n")
        }
        if options.joinLines {
            // "infor-\nmation" -> "information" (only when the continuation starts lowercase)
            s = replace(s, #"(\p{L})-\n[ \t]*(\p{Ll})"#, with: "$1$2")
            // Keep paragraph breaks (blank lines) as a single newline, join everything else.
            s = replace(s, #"\n(?:[ \t]*\n)+"#, with: "\u{1}")
            s = replace(s, #"[ \t]*\n[ \t]*"#, with: " ")
            s = s.replacingOccurrences(of: "\u{1}", with: "\n")
            s = replace(s, #"[ \t ]+"#, with: " ")
            s = s.components(separatedBy: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return s
    }

    /// Removes a leading bullet ("• ", "- ", "* ") or numbering ("1. ", "2) ", "(3) ", "a) ") from one line.
    public static func stripBullet(_ line: String) -> String {
        replace(line, #"^[ \t]*(?:[•·‣◦▪▫■□●○◆◇\-–—*>]+|\(?\d{1,3}[.)\]:]?|\(?[A-Za-z][.)])[ \t]+"#, with: "")
    }

    private static func replace(_ s: String, _ pattern: String, with template: String) -> String {
        let regex = try! NSRegularExpression(pattern: pattern)
        return regex.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: template)
    }
}
