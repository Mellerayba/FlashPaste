import Foundation
import FlashPasteCore

/// Reads and writes ~/Library/Application Support/FlashPaste/config.json.
final class ConfigStore {
    let url: URL

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        url = support.appendingPathComponent("FlashPaste/config.json")
    }

    func load() -> Config {
        guard let data = try? Data(contentsOf: url) else {
            log("no config file; writing defaults to \(url.path)")
            let config = Config()
            save(config)
            return config
        }
        let result = Config.parse(data)
        result.warnings.forEach { log("config warning: \($0)") }
        log("config loaded from \(url.path)")
        return result.config
    }

    func save(_ config: Config) {
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try config.jsonData().write(to: url, options: .atomic)
        } catch {
            log("could not save config: \(error.localizedDescription)")
        }
    }
}
