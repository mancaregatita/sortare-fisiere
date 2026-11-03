import Foundation

/// Fișierele aplicației: ~/Library/Application Support/Sortator
enum Storage {
    static let directory: URL = {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fm.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support", isDirectory: true)
        let dir = base.appendingPathComponent("Sortator", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    static func url(_ name: String) -> URL {
        directory.appendingPathComponent(name)
    }

    static func load<T: Decodable>(_ type: T.Type, from name: String) -> T? {
        guard let data = try? Data(contentsOf: url(name)) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    static func save<T: Encodable>(_ value: T, to name: String) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(value) else { return }
        try? data.write(to: url(name), options: .atomic)
    }
}

enum PathDisplay {
    /// /Users/mihaela/Downloads → ~/Downloads
    static func short(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path == home { return "~" }
        if path.hasPrefix(home + "/") { return "~" + String(path.dropFirst(home.count)) }
        return path
    }

    static func parentFolder(_ path: String) -> String {
        short(URL(fileURLWithPath: path).deletingLastPathComponent().path)
    }
}

enum RO {
    /// 1 fișier · 5 fișiere · 20 de fișiere
    static func count(_ n: Int, _ singular: String, _ plural: String) -> String {
        if n == 1 { return "1 \(singular)" }
        let rest = n % 100
        if n == 0 || (rest >= 1 && rest <= 19) { return "\(n) \(plural)" }
        return "\(n) de \(plural)"
    }
}
