import Foundation

/// All log lines carry the "FlashPaste:" prefix so Console.app can filter on it.
func log(_ message: String) {
    NSLog("FlashPaste: %@", message)
}

/// First ~30 characters of a capture, on one line, for alerts and menus.
func preview(_ text: String, limit: Int = 30) -> String {
    let flat = text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    return flat.count > limit ? String(flat.prefix(limit)) + "…" : flat
}
