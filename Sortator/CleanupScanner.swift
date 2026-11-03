import Foundation
import CryptoKit

/// Caută dubluri și installere vechi în folderele urmărite (inclusiv subfolderele lor).
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

    private func enumerate(folders: [WatchedFolder], excluded: [String], token: CancelToken?) -> [Item] {
        let keys: [URLResourceKey] = [.isRegularFileKey, .isPackageKey, .fileSizeKey, .addedToDirectoryDateKey, .creationDateKey, .contentModificationDateKey]
        var seen = Set<String>()
        var items: [Item] = []
        for folder in folders where !Exclusions.isExcluded(folder.path, excluded: excluded) {
            guard let enumerator = fm.enumerator(at: folder.url, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles, .skipsPackageDescendants]) else { continue }
            for case let url as URL in enumerator {
                if token?.isCancelled == true { return items }
                if Exclusions.isExcluded(url.path, excluded: excluded) {
                    enumerator.skipDescendants()
                    continue
                }
                guard let values = try? url.resourceValues(forKeys: Set(keys)) else { continue }
                if values.isPackage == true {
                    enumerator.skipDescendants()
                    continue
                }
                guard values.isRegularFile == true else { continue }
                let ext = url.pathExtension.lowercased()
                if Exclusions.protectedExtensions.contains(ext) { continue }
                let path = url.standardizedFileURL.path
                guard !seen.contains(path) else { continue }
                seen.insert(path)
                items.append(Item(
                    url: url,
                    size: Int64(values.fileSize ?? 0),
                    added: values.addedToDirectoryDate ?? values.creationDate ?? Date(),
                    modified: values.contentModificationDate ?? .distantPast
                ))
            }
        }
        return items
    }

    func findDuplicates(folders: [WatchedFolder],
                        excluded: [String],
                        token: CancelToken,
                        progress: @escaping @Sendable (String) -> Void,
                        completion: @escaping @Sendable ([DuplicateGroup]) -> Void) {
        queue.async {
            progress("Adun lista de fișiere…")
            let items = self.enumerate(folders: folders, excluded: excluded, token: token)
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

    func findOldInstallers(folders: [WatchedFolder],
                           excluded: [String],
                           days: Int,
                           completion: @escaping @Sendable ([OldInstaller]) -> Void) {
        queue.async {
            let limit = Date().addingTimeInterval(-Double(max(1, days)) * 86_400)
            let items = self.enumerate(folders: folders, excluded: excluded, token: nil)
            let old = items
                .filter { Self.installerExtensions.contains($0.url.pathExtension.lowercased()) && $0.added < limit }
                .sorted { $0.added < $1.added }
                .map { OldInstaller(url: $0.url, size: $0.size, added: $0.added) }
            completion(old)
        }
    }

    /// Citește documentele existente din folderele urmărite și găsește firmele din ele.
    /// Cele mai noi documente sunt primele; se opresc la `limit`.
    func scanCompanies(folders: [WatchedFolder],
                       excluded: [String],
                       settings: AppSettings,
                       limit: Int,
                       token: CancelToken,
                       progress: @escaping @Sendable (Int, Int) -> Void,
                       found: @escaping @Sendable (String, [Party]) -> Void,
                       completion: @escaping @Sendable () -> Void) {
        queue.async {
            let extractor = ContentExtractor(settings: settings)
            let documents = self.enumerate(folders: folders, excluded: excluded, token: token)
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
