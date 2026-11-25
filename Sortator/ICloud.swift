import Foundation
import AppKit

/// iCloud Drive: unde e, ce fișiere sunt doar în cloud, descărcare și eliberarea spațiului local.
enum ICloud {
    /// ~/Library/Mobile Documents/com~apple~CloudDocs
    static let driveURL: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs", isDirectory: true)
        .standardizedFileURL

    static var drivePath: String { driveURL.path }

    static var isAvailable: Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: drivePath, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    static func isInDrive(_ path: String) -> Bool {
        let p = URL(fileURLWithPath: path).standardizedFileURL.path
        return p == drivePath || p.hasPrefix(drivePath + "/")
    }

    private static func values(_ url: URL) -> URLResourceValues? {
        var fresh = url
        fresh.removeAllCachedResourceValues()
        return try? fresh.resourceValues(forKeys: [.isUbiquitousItemKey, .ubiquitousItemDownloadingStatusKey, .ubiquitousItemIsDownloadingKey])
    }

    static func isUbiquitous(_ url: URL) -> Bool {
        values(url)?.isUbiquitousItem == true
    }

    /// Fișierul e doar în iCloud (nu e pe acest Mac). Citirea lui l-ar descărca.
    static func isNotDownloaded(_ url: URL) -> Bool {
        guard let v = values(url), v.isUbiquitousItem == true else { return false }
        return v.ubiquitousItemDownloadingStatus == .notDownloaded
    }

    /// Se descarcă chiar acum (ex. un fișier pus de pe laptop).
    static func isDownloading(_ url: URL) -> Bool {
        guard let v = values(url), v.isUbiquitousItem == true else { return false }
        return v.ubiquitousItemIsDownloading == true
    }

    static func startDownloading(_ url: URL) {
        try? FileManager.default.startDownloadingUbiquitousItem(at: url)
    }

    /// Șterge copia locală; fișierul rămâne în iCloud și se descarcă din nou când e deschis.
    @discardableResult
    static func evict(_ url: URL) -> Bool {
        guard isUbiquitous(url) else { return true }
        do {
            try FileManager.default.evictUbiquitousItem(at: url)
            return true
        } catch {
            return false
        }
    }
}

/// Folderele pe care le creează și le folosește Sortator în fiecare folder urmărit.
/// Curățenia (dubluri, installere, firme, redenumire) lucrează doar aici și în rădăcină,
/// niciodată în folderele tale (repo-uri, proiecte) și niciodată în Keep.
enum ManagedFolders {
    static let keep = "Keep"
    static let ableton = "Ableton Projects"
    static let companies = "Firme"

    /// Foldere în care curățenia nu intră niciodată.
    static let untouchable: Set<String> = [keep, ableton]

    /// Primul nivel din partea fixă a destinațiilor regulilor active (ex. „Firme”, „Images”).
    static func topLevelNames(rules: [SortRule]) -> Set<String> {
        var names = Set<String>()
        for rule in rules where rule.enabled {
            let destination = rule.destination.trimmingCharacters(in: .whitespacesAndNewlines)
            if destination.isEmpty || destination.hasPrefix("/") || destination.hasPrefix("~") { continue }
            guard let first = destination.split(separator: "/").first.map(String.init),
                  !first.contains("{") else { continue }
            let name = first.trimmingCharacters(in: .whitespaces)
            if !name.isEmpty && !untouchable.contains(name) {
                names.insert(name)
            }
        }
        return names
    }

    /// Folderele Sortator din fiecare folder urmărit activ, plus destinațiile absolute ale regulilor.
    static func roots(config: AppConfig) -> [URL] {
        let names = topLevelNames(rules: config.rules)
        var roots: [URL] = []
        for folder in config.folders where folder.enabled && !Exclusions.isExcluded(folder.path, excluded: config.excludedFolders) {
            for name in names {
                roots.append(folder.url.appendingPathComponent(name, isDirectory: true))
            }
        }
        for rule in config.rules where rule.enabled {
            let destination = rule.destination.trimmingCharacters(in: .whitespacesAndNewlines)
            guard destination.hasPrefix("/") || destination.hasPrefix("~") else { continue }
            var fixed = destination
            if let brace = fixed.firstIndex(of: "{") {
                fixed = String(fixed[..<brace])
            }
            let expanded = Exclusions.expand(fixed)
            if expanded != "/" && expanded.count > 1 {
                roots.append(URL(fileURLWithPath: expanded, isDirectory: true))
            }
        }
        let paths = Array(Set(roots.map { $0.standardizedFileURL.path })).sorted()
        var kept: [String] = []
        for path in paths where !kept.contains(where: { path == $0 || path.hasPrefix($0 + "/") }) {
            if Exclusions.isExcluded(path, excluded: config.excludedFolders) { continue }
            kept.append(path)
        }
        return kept.map { URL(fileURLWithPath: $0, isDirectory: true) }
    }

    /// Folderele urmărite active (în care se uită doar la fișierele din rădăcină).
    static func watchedRoots(config: AppConfig) -> [URL] {
        config.folders
            .filter { $0.enabled && !Exclusions.isExcluded($0.path, excluded: config.excludedFolders) }
            .map { $0.url }
    }
}

/// Proiectele Ableton Live: un folder cu subfolderul „Ableton Project Info”.
enum Ableton {
    static let projectMarker = "Ableton Project Info"
    static let fileExtensions: Set<String> = ["als", "alp"]

    static func isProjectFolder(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        let marker = url.appendingPathComponent(projectMarker, isDirectory: true).path
        return FileManager.default.fileExists(atPath: marker, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    /// Ableton Live e pornit (orice versiune: Live 11, 12, Suite, Lite…).
    static var isRunning: Bool {
        NSWorkspace.shared.runningApplications.contains { app in
            let id = app.bundleIdentifier?.lowercased() ?? ""
            let name = app.localizedName?.lowercased() ?? ""
            return id.hasPrefix("com.ableton.live") || name.hasPrefix("ableton live")
        }
    }
}

/// Documentele Pages, Numbers, Keynote (și RTFD) sunt foldere pentru macOS, dar se mută ca fișiere.
enum DocumentPackages {
    static let extensions: Set<String> = ["pages", "numbers", "key", "rtfd"]
}
