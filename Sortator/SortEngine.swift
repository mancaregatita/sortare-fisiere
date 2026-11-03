import Foundation

/// Motorul de sortare. Totul rulează pe o coadă proprie, în fundal, ca interfața să nu se blocheze.
final class SortEngine {
    var onMoved: (@Sendable (HistoryEntry) -> Void)?
    var onStatus: (@Sendable (String) -> Void)?
    /// Firmele (nume + CUI) găsite într-un document nou: cheia documentului și lista.
    var onParties: (@Sendable (String, [Party]) -> Void)?

    private let queue = DispatchQueue(label: "ro.mancaregatita.sortator.engine", qos: .utility)
    private let fm = FileManager.default
    private var config = AppConfig()
    private var extractor = ContentExtractor(settings: AppSettings())
    private var watchers: [String: FolderWatcher] = [:]
    private var timer: DispatchSourceTimer?
    private var dirty = true
    private var lastFullScan = Date.distantPast
    private var pending: [String: PendingInfo] = [:]
    private var evaluated: [String: Date] = [:]
    private var ignored: Set<String> = []

    private struct PendingInfo {
        var size: Int64
        var modified: Date
        var lastChange: Date
    }

    private struct PersistedState: Codable {
        var evaluated: [String: Date]
        var ignored: [String]
    }

    private static let stateFile = "engine-state.json"
    private static let temporaryExtensions: Set<String> = [
        "crdownload", "download", "part", "partial", "tmp", "temp", "opdownload",
        "filepart", "!ut", "td", "aria2", "unconfirmed", "dtapart"
    ]

    // MARK: Pornire și configurare

    func start(config: AppConfig) {
        queue.async {
            if let saved = Storage.load(PersistedState.self, from: Self.stateFile) {
                self.evaluated = saved.evaluated
                self.ignored = Set(saved.ignored)
            }
            self.apply(config)
            let t = DispatchSource.makeTimerSource(queue: self.queue)
            t.schedule(deadline: .now() + 1, repeating: 2.0)
            t.setEventHandler { [weak self] in
                self?.tick()
            }
            self.timer = t
            t.resume()
        }
    }

    func update(config: AppConfig) {
        queue.async {
            self.apply(config)
        }
    }

    func rescanNow() {
        queue.async {
            self.dirty = true
            self.lastFullScan = .distantPast
        }
    }

    private func apply(_ newConfig: AppConfig) {
        config = newConfig
        extractor = ContentExtractor(settings: newConfig.settings)
        syncWatchers()
        dirty = true
    }

    private var activeFolders: [WatchedFolder] {
        config.folders.filter { $0.enabled && !Exclusions.isExcluded($0.path, excluded: config.excludedFolders) }
    }

    private func syncWatchers() {
        let wanted = Set(config.settings.paused ? [] : activeFolders.map { $0.path })
        for (path, watcher) in watchers where !wanted.contains(path) {
            watcher.stop()
            watchers[path] = nil
        }
        for path in wanted where watchers[path] == nil {
            let watcher = FolderWatcher(path: path, queue: queue) { [weak self] in
                self?.dirty = true
            }
            if watcher.start() {
                watchers[path] = watcher
            }
        }
    }

    // MARK: Urmărire automată

    private func tick() {
        guard !config.settings.paused else { return }
        let now = Date()
        let fullScan = now.timeIntervalSince(lastFullScan) >= 30
        guard dirty || !pending.isEmpty || fullScan else { return }
        dirty = false
        if fullScan {
            lastFullScan = now
            syncWatchers()
            pruneIgnored()
        }
        for folder in activeFolders {
            scan(folder)
        }
    }

    private func scan(_ folder: WatchedFolder) {
        let keys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey, .addedToDirectoryDateKey, .creationDateKey]
        guard let items = try? fm.contentsOfDirectory(at: folder.url, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]) else { return }
        let names = Set(items.map { $0.lastPathComponent })
        let now = Date()
        let delay = max(1.0, config.settings.delaySeconds)
        var present = Set<String>()

        for url in items {
            let name = url.lastPathComponent
            guard Self.isCandidateName(name, siblings: names) else { continue }
            guard let values = try? url.resourceValues(forKeys: Set(keys)), values.isRegularFile == true else { continue }
            let path = url.path
            present.insert(path)
            if ignored.contains(path) { continue }

            let added = values.addedToDirectoryDate ?? values.creationDate ?? .distantPast
            if added < folder.activeSince { continue }

            let size = Int64(values.fileSize ?? 0)
            let modified = values.contentModificationDate ?? .distantPast
            let key = Self.evaluationKey(path: path, size: size, modified: modified)
            if evaluated[key] != nil { continue }

            guard var info = pending[path] else {
                pending[path] = PendingInfo(size: size, modified: modified, lastChange: now)
                continue
            }
            if info.size != size || info.modified != modified {
                info.size = size
                info.modified = modified
                info.lastChange = now
                pending[path] = info
                continue
            }
            // Fișierele goale pot fi descărcări abia începute: le dăm mai mult timp.
            let wait = size == 0 ? max(delay, 30) : delay
            let modifiedAge = now.timeIntervalSince(modified)
            guard now.timeIntervalSince(info.lastChange) >= wait,
                  modifiedAge >= wait || modifiedAge < -60 else { continue }
            pending[path] = nil
            process(url, in: folder, key: key)
        }

        let prefix = folder.url.standardizedFileURL.path + "/"
        for path in pending.keys where path.hasPrefix(prefix) && !present.contains(path) {
            pending[path] = nil
        }
    }

    /// Unde ar merge fișierul și sub ce nume, după regula care s-a potrivit.
    private func target(for rule: SortRule, context: FileContext, base: URL) -> (folder: URL, name: String, info: DocumentInfo?)? {
        let destination = rule.destination.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !destination.isEmpty else { return nil }
        let wantsRename = rule.rename && config.settings.renameDocuments
        var info: DocumentInfo?
        if wantsRename || rule.usesDocumentFields {
            info = context.documentInfo(companies: config.companies, settings: config.settings)
        }
        let folderURL = Self.resolveDestination(destination, base: base, file: context.url, info: info)
        var name = context.url.lastPathComponent
        if wantsRename, let info, let newName = info.fileName(extension: context.url.pathExtension) {
            name = newName
        }
        return (folderURL, name, info)
    }

    private func discoverParties(_ context: FileContext, key: String) {
        guard PartyExtractor.documentExtensions.contains(context.ext) else { return }
        _ = context.normalizedContent()
        let parties = PartyExtractor.parties(text: context.extracted.text, raw: context.extracted.raw)
        onParties?(key, parties)
    }

    private func process(_ url: URL, in folder: WatchedFolder, key: String) {
        let context = FileContext(url: url, extractor: extractor)
        discoverParties(context, key: key)
        guard let rule = RuleMatcher.firstMatch(config.rules, context) else {
            markEvaluated(key)
            return
        }
        guard let planned = target(for: rule, context: context, base: folder.url) else {
            markEvaluated(key)
            return
        }
        let destinationFolder = planned.folder
        // Destinația e chiar folderul urmărit: lăsăm fișierul așa (nici nu-l redenumim pe loc, ca să nu intrăm în buclă).
        if Self.samePath(destinationFolder, url.deletingLastPathComponent()) {
            markEvaluated(key)
            return
        }
        if Exclusions.isExcluded(destinationFolder.path, excluded: config.excludedFolders) {
            markEvaluated(key)
            onStatus?("„\(url.lastPathComponent)” nu a fost mutat: regula „\(rule.name)” duce într-un folder exclus.")
            return
        }
        do {
            let target = try moveFile(url, into: destinationFolder, name: planned.name)
            let entry = HistoryEntry(
                date: Date(),
                fileName: url.lastPathComponent,
                fromPath: url.path,
                toPath: target.path,
                ruleName: rule.name
            )
            onMoved?(entry)
        } catch {
            markEvaluated(key)
            onStatus?("Nu am putut muta „\(url.lastPathComponent)”: \(error.localizedDescription)")
        }
    }

    // MARK: Acțiuni cerute din interfață

    func undo(_ entry: HistoryEntry, completion: @escaping @Sendable (Result<String, Error>) -> Void) {
        queue.async {
            let current = URL(fileURLWithPath: entry.toPath)
            guard self.fm.fileExists(atPath: current.path) else {
                completion(.failure(EngineError(message: "Fișierul nu mai este la destinație (a fost mutat sau șters între timp).")))
                return
            }
            let original = URL(fileURLWithPath: entry.fromPath)
            let folder = original.deletingLastPathComponent()
            do {
                try self.fm.createDirectory(at: folder, withIntermediateDirectories: true)
                let target = Self.uniqueURL(in: folder, name: original.lastPathComponent, fileManager: self.fm)
                try self.fm.moveItem(at: current, to: target)
                self.ignored.insert(target.path)
                self.saveState()
                completion(.success(target.path))
            } catch {
                completion(.failure(error))
            }
        }
    }

    /// Previzualizare pentru „Sortează ce există”: ce s-ar muta, fără să mute nimic.
    func plan(folder: WatchedFolder,
              token: CancelToken,
              progress: @escaping @Sendable (Int, Int) -> Void,
              completion: @escaping @Sendable ([PlannedMove]) -> Void) {
        queue.async {
            guard !Exclusions.isExcluded(folder.path, excluded: self.config.excludedFolders) else {
                completion([])
                return
            }
            let items = (try? self.fm.contentsOfDirectory(at: folder.url, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles])) ?? []
            let names = Set(items.map { $0.lastPathComponent })
            let files = items
                .filter { url in
                    guard Self.isCandidateName(url.lastPathComponent, siblings: names) else { return false }
                    return (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
                }
                .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }

            var moves: [PlannedMove] = []
            progress(0, files.count)
            for (index, url) in files.enumerated() {
                if token.isCancelled { break }
                autoreleasepool {
                    let context = FileContext(url: url, extractor: self.extractor)
                    if let rule = RuleMatcher.firstMatch(self.config.rules, context),
                       let planned = self.target(for: rule, context: context, base: folder.url) {
                        if !Self.samePath(planned.folder, url.deletingLastPathComponent()),
                           !Exclusions.isExcluded(planned.folder.path, excluded: self.config.excludedFolders) {
                            moves.append(PlannedMove(source: url, destinationFolder: planned.folder, newName: planned.name, ruleName: rule.name))
                        }
                    }
                }
                progress(index + 1, files.count)
            }
            completion(token.isCancelled ? [] : moves)
        }
    }

    func execute(_ moves: [PlannedMove], completion: @escaping @Sendable (Int, [String]) -> Void) {
        queue.async {
            var count = 0
            var errors: [String] = []
            for move in moves {
                guard self.fm.fileExists(atPath: move.source.path) else { continue }
                do {
                    let target = try self.moveFile(move.source, into: move.destinationFolder, name: move.newName)
                    self.ignored.remove(move.source.path)
                    self.onMoved?(HistoryEntry(
                        date: Date(),
                        fileName: move.source.lastPathComponent,
                        fromPath: move.source.path,
                        toPath: target.path,
                        ruleName: move.ruleName
                    ))
                    count += 1
                } catch {
                    errors.append("\(move.source.lastPathComponent): \(error.localizedDescription)")
                }
            }
            self.saveState()
            completion(count, errors)
        }
    }

    /// Arată ce regulă s-ar aplica unui fișier și ce text a fost găsit în el. Nu mută nimic.
    func test(_ url: URL, completion: @escaping @Sendable (TestResult) -> Void) {
        queue.async {
            let context = FileContext(url: url, extractor: self.extractor)
            _ = context.normalizedContent()
            var report: [String] = []
            var firstRule: SortRule?
            for rule in self.config.rules {
                if !rule.enabled {
                    report.append("–  \(rule.name) (oprită)")
                    continue
                }
                let ok = RuleMatcher.ruleMatches(rule, context)
                if ok && firstRule == nil { firstRule = rule }
                report.append((ok ? "✓  " : "✗  ") + rule.name)
            }
            var destination: String?
            var proposedName = url.lastPathComponent
            if Exclusions.isExcluded(url.path, excluded: self.config.excludedFolders) {
                destination = "fișierul e într-un folder exclus — nu va fi atins"
            } else if let rule = firstRule {
                let base = self.watchedFolder(containing: url)?.url ?? url.deletingLastPathComponent()
                if let planned = self.target(for: rule, context: context, base: base) {
                    proposedName = planned.name
                    if Exclusions.isExcluded(planned.folder.path, excluded: self.config.excludedFolders) {
                        destination = PathDisplay.short(planned.folder.path) + " — folder exclus, nu va fi mutat"
                    } else {
                        destination = PathDisplay.short(planned.folder.path)
                    }
                } else {
                    destination = "rămâne pe loc (regula nu are destinație)"
                }
            }

            let info = context.documentInfo(companies: self.config.companies, settings: self.config.settings)
            let typeText: String
            if let type = info.type {
                typeText = info.usedAI ? "\(type.name) (recunoscut de AI-ul Apple)" : type.name
            } else {
                typeText = "nerecunoscut"
            }
            if firstRule == nil || firstRule?.rename != true || !self.config.settings.renameDocuments {
                if let name = info.fileName(extension: url.pathExtension), firstRule != nil {
                    proposedName = url.lastPathComponent + "   (cu redenumirea pornită: " + name + ")"
                }
            }
            completion(TestResult(
                fileName: url.lastPathComponent,
                ruleName: firstRule?.name,
                destination: destination,
                textMethod: context.extracted.method,
                textSnippet: String(context.extracted.text.prefix(4000)),
                ruleReport: report,
                documentType: typeText,
                company: info.company ?? "—",
                partner: info.partner ?? "—",
                dateText: "\(info.dateString) — \(info.dateSource)",
                proposedName: proposedName
            ))
        }
    }

    // MARK: Utilitare

    private func watchedFolder(containing url: URL) -> WatchedFolder? {
        let parent = url.deletingLastPathComponent()
        return config.folders.first { Self.samePath($0.url, parent) }
    }

    private func moveFile(_ source: URL, into folder: URL, name: String) throws -> URL {
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        let target = Self.uniqueURL(in: folder, name: name, fileManager: fm)
        try fm.moveItem(at: source, to: target)
        return target
    }

    private func markEvaluated(_ key: String) {
        evaluated[key] = Date()
        if evaluated.count > 3000 {
            let newest = evaluated.sorted { $0.value > $1.value }.prefix(2000)
            evaluated = Dictionary(uniqueKeysWithValues: newest.map { ($0.key, $0.value) })
        }
        saveState()
    }

    private func pruneIgnored() {
        let before = ignored.count
        ignored = ignored.filter { fm.fileExists(atPath: $0) }
        if ignored.count != before { saveState() }
    }

    private func saveState() {
        Storage.save(PersistedState(evaluated: evaluated, ignored: Array(ignored)), to: Self.stateFile)
    }

    static func isCandidateName(_ name: String, siblings: Set<String>) -> Bool {
        let lower = name.lowercased()
        let ext = (lower as NSString).pathExtension
        if lower.hasPrefix(".") || lower.hasPrefix("~$") || lower.hasPrefix("unconfirmed ") { return false }
        if lower == ".ds_store" || lower == ".localized" || name == "Icon\r" { return false }
        if temporaryExtensions.contains(ext) { return false }
        if Exclusions.protectedExtensions.contains(ext) { return false }
        for suffix in [".part", ".crdownload", ".download", ".opdownload"] where siblings.contains(name + suffix) {
            return false
        }
        return true
    }

    static func evaluationKey(path: String, size: Int64, modified: Date) -> String {
        "\(path)|\(size)|\(Int(modified.timeIntervalSince1970))"
    }

    static func samePath(_ a: URL, _ b: URL) -> Bool {
        a.standardizedFileURL.path == b.standardizedFileURL.path
    }

    static func uniqueURL(in folder: URL, name: String, fileManager: FileManager) -> URL {
        let base = (name as NSString).deletingPathExtension
        let ext = (name as NSString).pathExtension
        var candidate = folder.appendingPathComponent(name)
        var number = 2
        while fileManager.fileExists(atPath: candidate.path) {
            let newName = ext.isEmpty ? "\(base) (\(number))" : "\(base) (\(number)).\(ext)"
            candidate = folder.appendingPathComponent(newName)
            number += 1
        }
        return candidate
    }

    /// Transformă destinația scrisă în regulă într-un folder real.
    /// {an} {luna} {ext} {tip} {firma} {tipdoc} {partener} sunt înlocuite;
    /// „~/…” sau „/…” = cale absolută; altfel e relativ la folderul urmărit.
    static func resolveDestination(_ template: String, base: URL, file: URL, info: DocumentInfo? = nil) -> URL {
        let parts = Calendar.current.dateComponents([.year, .month], from: info?.date ?? Date())
        let ext = file.pathExtension.lowercased()
        var t = template.trimmingCharacters(in: .whitespacesAndNewlines)
        t = t.replacingOccurrences(of: "{firma}", with: Names.safeFileName(info?.company ?? "Fără firmă"))
        t = t.replacingOccurrences(of: "{tipdoc}", with: info?.type?.folder ?? "Altele")
        t = t.replacingOccurrences(of: "{partener}", with: Names.safeFileName(info?.partner ?? "Necunoscut"))
        t = t.replacingOccurrences(of: "{an}", with: String(format: "%04ld", parts.year ?? 0))
        t = t.replacingOccurrences(of: "{luna}", with: String(format: "%02ld", parts.month ?? 0))
        t = t.replacingOccurrences(of: "{ext}", with: ext.isEmpty ? "fara extensie" : ext.uppercased())
        t = t.replacingOccurrences(of: "{tip}", with: DefaultRules.category(forExtension: ext))
        if t.hasPrefix("~") {
            t = (t as NSString).expandingTildeInPath
        }
        if t.hasPrefix("/") {
            return URL(fileURLWithPath: t, isDirectory: true).standardizedFileURL
        }
        var result = base
        for component in t.split(separator: "/") {
            let piece = component.trimmingCharacters(in: .whitespaces)
            if piece.isEmpty || piece == "." || piece == ".." { continue }
            result.appendPathComponent(piece, isDirectory: true)
        }
        return result
    }
}
