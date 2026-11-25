import Foundation
import CryptoKit
import CoreServices

/// Ce parcurge curățenia: folderele Sortator (recursiv) și fișierele din rădăcina folderelor urmărite.
/// Folderele tale (repo-uri, proiecte), Keep și Ableton Projects nu sunt atinse.
struct CleanupScope: Sendable {
    let roots: [URL]
    let topLevel: [URL]
    let excluded: [String]
}

/// Un installer deschis pe acest Mac (pentru notificarea „Ai instalat X. Ștergi installerul?”).
struct OpenedInstaller: Sendable {
    let url: URL
    let openedAt: Date
    let installedApp: String?
}

/// Caută dubluri și installere în folderele Sortator.
/// Nu șterge nimic singur: doar găsește, iar mutarea la coș se face doar la cererea ta.
final class CleanupScanner {
    private let queue = DispatchQueue(label: "ro.mancaregatita.sortator.cleanup", qos: .utility)
    private let fm = FileManager.default

    static let installerExtensions: Set<String> = ["dmg", "pkg", "mpkg"]

    private struct Item {
        let url: URL
        let size: Int64
        let added: Date
        let modified: Date
    }

    /// - skipCloudOnly: sare peste fișierele doar din iCloud (citirea lor le-ar descărca).
    private func enumerate(_ scope: CleanupScope, token: CancelToken?, skipCloudOnly: Bool) -> [Item] {
        let keys: [URLResourceKey] = [.isRegularFileKey, .isPackageKey, .fileSizeKey, .addedToDirectoryDateKey, .creationDateKey, .contentModificationDateKey]
        var seen = Set<String>()
        var items: [Item] = []

        func add(_ url: URL, _ values: URLResourceValues) {
            guard values.isRegularFile == true else { return }
            let ext = url.pathExtension.lowercased()
            if Exclusions.protectedExtensions.contains(ext) { return }
            let path = url.standardizedFileURL.path
            guard !seen.contains(path) else { return }
            if skipCloudOnly && ICloud.isInDrive(path) && ICloud.isNotDownloaded(url) { return }
            seen.insert(path)
            items.append(Item(
                url: url,
                size: Int64(values.fileSize ?? 0),
                added: values.addedToDirectoryDate ?? values.creationDate ?? Date(),
                modified: values.contentModificationDate ?? .distantPast
            ))
        }

        for root in scope.roots where !Exclusions.isExcluded(root.path, excluded: scope.excluded) {
            guard let enumerator = fm.enumerator(at: root, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles, .skipsPackageDescendants]) else { continue }
            for case let url as URL in enumerator {
                if token?.isCancelled == true { return items }
                if Exclusions.isExcluded(url.path, excluded: scope.excluded) || ManagedFolders.untouchable.contains(url.lastPathComponent) {
                    enumerator.skipDescendants()
                    continue
                }
                guard let values = try? url.resourceValues(forKeys: Set(keys)) else { continue }
                if values.isPackage == true {
                    enumerator.skipDescendants()
                    continue
                }
                add(url, values)
            }
        }
        for folder in scope.topLevel where !Exclusions.isExcluded(folder.path, excluded: scope.excluded) {
            let list = (try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles])) ?? []
            for url in list {
                if token?.isCancelled == true { return items }
                guard let values = try? url.resourceValues(forKeys: Set(keys)) else { continue }
                add(url, values)
            }
        }
        return items
    }

    func findDuplicates(scope: CleanupScope,
                        token: CancelToken,
                        progress: @escaping @Sendable (String) -> Void,
                        completion: @escaping @Sendable ([DuplicateGroup]) -> Void) {
        queue.async {
            progress("Adun lista de fișiere…")
            let items = self.enumerate(scope, token: token, skipCloudOnly: true)
            var bySize: [Int64: [Item]] = [:]
            for item in items where item.size > 0 {
                bySize[item.size, default: []].append(item)
            }
            let candidates = bySize.values.filter { $0.count > 1 }
            let total = candidates.reduce(0) { $0 + $1.count }
            var checked = 0
            var groups: [DuplicateGroup] = []

            for sameSize in candidates {
                if token.isCancelled { break }
                var byHash: [String: [Item]] = [:]
                for item in sameSize {
                    if token.isCancelled { break }
                    autoreleasepool {
                        if let hash = Self.sha256(item.url) {
                            byHash[hash, default: []].append(item)
                        }
                    }
                    checked += 1
                    if checked % 10 == 0 {
                        progress("Compar conținutul… \(checked) din \(total)")
                    }
                }
                for list in byHash.values where list.count > 1 {
                    let files = list
                        .sorted { $0.added < $1.added }
                        .map { DuplicateFile(url: $0.url, size: $0.size, added: $0.added) }
                    groups.append(DuplicateGroup(size: list[0].size, files: files))
                }
            }
            groups.sort { $0.size * Int64($0.files.count - 1) > $1.size * Int64($1.files.count - 1) }
            completion(token.isCancelled ? [] : groups)
        }
    }

    func findOldInstallers(scope: CleanupScope,
                           days: Int,
                           completion: @escaping @Sendable ([OldInstaller]) -> Void) {
        queue.async {
            let limit = Date().addingTimeInterval(-Double(max(1, days)) * 86_400)
            let items = self.enumerate(scope, token: nil, skipCloudOnly: false)
            let old = items
                .filter { Self.installerExtensions.contains($0.url.pathExtension.lowercased()) && $0.added < limit }
                .sorted { $0.added < $1.added }
                .map { OldInstaller(url: $0.url, size: $0.size, added: $0.added) }
            completion(old)
        }
    }

    /// Citește documentele existente din folderele urmărite și găsește firmele din ele.
    /// Cele mai noi documente sunt primele; se opresc la `limit`.
    func scanCompanies(scope: CleanupScope,
                       settings: AppSettings,
                       limit: Int,
                       token: CancelToken,
                       progress: @escaping @Sendable (Int, Int) -> Void,
                       found: @escaping @Sendable (String, [Party]) -> Void,
                       completion: @escaping @Sendable () -> Void) {
        queue.async {
            let extractor = ContentExtractor(settings: settings)
            let documents = self.enumerate(scope, token: token, skipCloudOnly: true)
                .filter { PartyExtractor.documentExtensions.contains($0.url.pathExtension.lowercased()) }
                .sorted { $0.added > $1.added }
                .prefix(limit)
            let total = documents.count
            progress(0, total)
            for (index, item) in documents.enumerated() {
                if token.isCancelled { break }
                autoreleasepool {
                    let context = FileContext(url: item.url, extractor: extractor)
                    _ = context.normalizedContent()
                    let parties = PartyExtractor.parties(text: context.extracted.text, raw: context.extracted.raw)
                    found(DiscoveryKey.make(size: item.size, modified: item.modified), parties)
                }
                if index % 5 == 4 || index == total - 1 {
                    progress(index + 1, total)
                }
            }
            completion()
        }
    }

    /// Installerele deschise pe acest Mac: dacă între timp a apărut o aplicație nouă în Applications,
    /// o raportăm după 10 minute; dacă nu, după o zi de la deschidere.
    func findOpenedInstallers(scope: CleanupScope,
                              completion: @escaping @Sendable ([OpenedInstaller]) -> Void) {
        queue.async {
            let now = Date()
            let installers = self.enumerate(scope, token: nil, skipCloudOnly: false)
                .filter { Self.installerExtensions.contains($0.url.pathExtension.lowercased()) }
            var result: [OpenedInstaller] = []
            var apps: [(name: String, added: Date)]?
            for item in installers {
                guard let opened = Self.lastOpened(item.url), opened > item.added.addingTimeInterval(5) else { continue }
                if apps == nil { apps = self.recentApplications() }
                let app = apps?
                    .filter { $0.added >= opened.addingTimeInterval(-60) && $0.added <= opened.addingTimeInterval(6 * 3600) }
                    .min { abs($0.added.timeIntervalSince(opened)) < abs($1.added.timeIntervalSince(opened)) }
                let age = now.timeIntervalSince(opened)
                if (app != nil && age >= 600) || age >= 86_400 {
                    result.append(OpenedInstaller(url: item.url, openedAt: opened, installedApp: app?.name))
                }
            }
            completion(result)
        }
    }

    /// Când a fost deschis fișierul ultima oară din Finder (Spotlight, „Last opened”).
    /// Nu folosim data ultimului acces: și citirea pentru dubluri ar schimba-o.
    static func lastOpened(_ url: URL) -> Date? {
        guard let item = MDItemCreateWithURL(kCFAllocatorDefault, url as CFURL) else { return nil }
        return MDItemCopyAttribute(item, kMDItemLastUsedDate) as? Date
    }

    /// Aplicațiile din /Applications și ~/Applications, cu data la care au apărut acolo.
    private func recentApplications() -> [(name: String, added: Date)] {
        let folders = [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            fm.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true)
        ]
        let keys: [URLResourceKey] = [.addedToDirectoryDateKey, .creationDateKey]
        var apps: [(name: String, added: Date)] = []
        for folder in folders {
            let list = (try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles])) ?? []
            for url in list where url.pathExtension.lowercased() == "app" {
                let values = try? url.resourceValues(forKeys: Set(keys))
                if let added = values?.addedToDirectoryDate ?? values?.creationDate {
                    apps.append((name: url.deletingPathExtension().lastPathComponent, added: added))
                }
            }
        }
        return apps
    }

    /// Mută la Coș (se pot recupera de acolo). Întoarce căile mutate și erorile.
    func trash(_ urls: [URL], completion: @escaping @Sendable ([String], [String]) -> Void) {
        queue.async {
            var trashed: [String] = []
            var errors: [String] = []
            for url in urls {
                guard self.fm.fileExists(atPath: url.path) else { continue }
                do {
                    try self.fm.trashItem(at: url, resultingItemURL: nil)
                    trashed.append(url.path)
                } catch {
                    errors.append("\(url.lastPathComponent): \(error.localizedDescription)")
                }
            }
            completion(trashed, errors)
        }
    }

    static func sha256(_ url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        var hasher = SHA256()
        while true {
            guard let data = try? handle.read(upToCount: 1_048_576), !data.isEmpty else { break }
            hasher.update(data: data)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}

/// Cheia unui document pentru numărare: mărime + data modificării (rămân la fel după mutare și redenumire).
enum DiscoveryKey {
    static func make(size: Int64, modified: Date) -> String {
        "\(size)|\(Int(modified.timeIntervalSince1970))"
    }

    /// Din cheia motorului „cale|mărime|dată” păstrăm doar „mărime|dată”.
    static func fromEngineKey(_ key: String) -> String {
        key.split(separator: "|").suffix(2).joined(separator: "|")
    }
}
