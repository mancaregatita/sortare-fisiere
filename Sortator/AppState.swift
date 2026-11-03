import SwiftUI
import AppKit
import ServiceManagement
import UniformTypeIdentifiers

enum MainTab: Hashable {
    case folders, rules, companies, cleanup, history, settings
}

struct TestTarget: Identifiable {
    let id = UUID()
    let url: URL
}

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    @Published var config: AppConfig {
        didSet { configDidChange() }
    }
    @Published var history: [HistoryEntry] = []
    @Published var statusMessage: String = "Pornit"
    @Published var launchAtLogin: Bool = false
    @Published var selectedTab: MainTab = .folders

    @Published var duplicateGroups: [DuplicateGroup] = []
    @Published var duplicateScanRunning = false
    @Published var duplicateScanProgress = ""
    @Published var lastDuplicateScan: Date?
    @Published var oldInstallers: [OldInstaller] = []
    @Published var installerScanRunning = false
    @Published var discovery = DiscoveryStore()
    @Published var companyScanRunning = false
    @Published var companyScanProgress = ""

    let engine = SortEngine()
    let cleanup = CleanupScanner()
    private var mainWindow: NSWindow?
    private var windowDelegate: MainWindowDelegate?
    private var cleanupTimer: Timer?
    private var duplicateToken = CancelToken()
    private var companyScanToken = CancelToken()
    private static let discoveryFile = "firme-gasite.json"

    private static let installerSnoozeKey = "installerSnoozeUntil"

    private init() {
        var firstRun = false
        var migrated = false
        if let loaded = Storage.load(AppConfig.self, from: "config.json") {
            let result = AppConfig.migrate(loaded)
            config = result.0
            migrated = result.1
        } else {
            let existing = Storage.url("config.json")
            if FileManager.default.fileExists(atPath: existing.path) {
                // Fișier stricat: îl păstrăm ca rezervă, nu îl suprascriem fără urmă.
                let backup = Storage.url("config-rezerva-\(Int(Date().timeIntervalSince1970)).json")
                try? FileManager.default.copyItem(at: existing, to: backup)
            }
            var fresh = AppConfig()
            if let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first {
                fresh.folders = [WatchedFolder(path: downloads.path)]
            }
            config = fresh
            firstRun = true
        }
        history = Storage.load([HistoryEntry].self, from: "history.json") ?? []
        discovery = Storage.load(DiscoveryStore.self, from: Self.discoveryFile) ?? DiscoveryStore()
        launchAtLogin = SMAppService.mainApp.status == .enabled
        if firstRun || migrated {
            Storage.save(config, to: "config.json")
        }

        Self.quitOtherInstances()

        engine.onMoved = { entry in
            Task { @MainActor in AppState.shared.recordMove(entry) }
        }
        engine.onStatus = { message in
            Task { @MainActor in AppState.shared.statusMessage = message }
        }
        engine.onParties = { key, parties in
            Task { @MainActor in AppState.shared.recordParties(DiscoveryKey.fromEngineKey(key), parties) }
        }
        engine.start(config: config)

        if firstRun {
            Task { @MainActor in AppState.shared.showMainWindow() }
        }

        // Curățenie: prima verificare la 2 minute după pornire, apoi o dată pe oră.
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { _ in
            Task { @MainActor in AppState.shared.periodicCleanup() }
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 120 * 1_000_000_000)
            AppState.shared.periodicCleanup()
        }
    }

    // MARK: Curățenie

    private func periodicCleanup() {
        guard !config.settings.paused else { return }
        if config.settings.autoDuplicateScan, !duplicateScanRunning {
            let due = lastDuplicateScan.map { Date().timeIntervalSince($0) > 12 * 3600 } ?? true
            if due { scanDuplicates() }
        }
        if config.settings.askAboutInstallers {
            checkInstallers(ask: true)
        }
    }

    private var cleanupFolders: [WatchedFolder] {
        config.folders.filter { $0.enabled }
    }

    func scanDuplicates() {
        guard !duplicateScanRunning else { return }
        duplicateScanRunning = true
        duplicateScanProgress = "Pornesc căutarea…"
        let token = CancelToken()
        duplicateToken = token
        cleanup.findDuplicates(folders: cleanupFolders, excluded: config.excludedFolders, token: token, progress: { text in
            Task { @MainActor in AppState.shared.duplicateScanProgress = text }
        }, completion: { groups in
            Task { @MainActor in
                let state = AppState.shared
                state.duplicateGroups = groups
                state.duplicateScanRunning = false
                state.duplicateScanProgress = ""
                state.lastDuplicateScan = Date()
            }
        })
    }

    func stopDuplicateScan() {
        duplicateToken.cancel()
        duplicateScanRunning = false
        duplicateScanProgress = ""
    }

    func checkInstallers(ask: Bool) {
        guard !installerScanRunning else { return }
        installerScanRunning = true
        let days = config.settings.installerDays
        cleanup.findOldInstallers(folders: cleanupFolders, excluded: config.excludedFolders, days: days) { list in
            Task { @MainActor in AppState.shared.installersFound(list, ask: ask) }
        }
    }

    private func installersFound(_ list: [OldInstaller], ask: Bool) {
        installerScanRunning = false
        oldInstallers = list
        guard ask, !list.isEmpty, config.settings.askAboutInstallers, !config.settings.paused else { return }
        if let until = UserDefaults.standard.object(forKey: Self.installerSnoozeKey) as? Date, until > Date() { return }

        let totalSize = list.reduce(Int64(0)) { $0 + $1.size }
        let names = list.prefix(8).map { "• " + $0.url.lastPathComponent }.joined(separator: "\n")
        let more = list.count > 8 ? "\n… și încă \(list.count - 8)" : ""
        let alert = NSAlert()
        alert.messageText = "Ai \(RO.count(list.count, "installer", "installere")) mai vechi de \(config.settings.installerDays) de zile"
        alert.informativeText = "\(names)\(more)\n\nÎn total \(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)). Le muți la coș? Se pot recupera din Coș dacă ai nevoie."
        alert.addButton(withTitle: "Mută la coș")
        alert.addButton(withTitle: "Arată-mi lista")
        alert.addButton(withTitle: "Mai târziu")
        NSApp.activate(ignoringOtherApps: true)
        switch alert.runModal() {
        case .alertFirstButtonReturn:
            moveToTrash(list.map { $0.url })
        case .alertSecondButtonReturn:
            UserDefaults.standard.set(Date().addingTimeInterval(86_400), forKey: Self.installerSnoozeKey)
            showMainWindow(tab: .cleanup)
        default:
            UserDefaults.standard.set(Date().addingTimeInterval(7 * 86_400), forKey: Self.installerSnoozeKey)
        }
    }

    func moveToTrash(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        cleanup.trash(urls) { trashed, errors in
            Task { @MainActor in AppState.shared.didTrash(trashed, errors) }
        }
    }

    private func didTrash(_ trashed: [String], _ errors: [String]) {
        let gone = Set(trashed)
        duplicateGroups = duplicateGroups.compactMap { group in
            let files = group.files.filter { !gone.contains($0.url.path) }
            return files.count > 1 ? DuplicateGroup(size: group.size, files: files) : nil
        }
        oldInstallers = oldInstallers.filter { !gone.contains($0.url.path) }
        statusMessage = "Am mutat \(RO.count(trashed.count, "fișier", "fișiere")) la coș"
        if !errors.isEmpty {
            showAlert("Unele fișiere nu au putut fi mutate la coș", errors.prefix(10).joined(separator: "\n"))
        }
    }

    // MARK: Firme găsite în documente

    private func recordParties(_ documentKey: String, _ parties: [Party]) {
        guard !discovery.countedDocuments.contains(documentKey) else { return }
        discovery.countedDocuments.append(documentKey)
        if discovery.countedDocuments.count > 5000 {
            discovery.countedDocuments.removeFirst(discovery.countedDocuments.count - 5000)
        }
        discovery.totalDocuments += 1
        for party in parties {
            if let index = discovery.companies.firstIndex(where: { $0.cui == party.cui }) {
                discovery.companies[index].documents += 1
                if party.role == .customer { discovery.companies[index].asCustomer += 1 }
                if party.role == .supplier { discovery.companies[index].asSupplier += 1 }
                discovery.companies[index].lastSeen = Date()
                if discovery.companies[index].name.hasPrefix("Firma cu CUI"), !party.name.hasPrefix("Firma cu CUI") {
                    discovery.companies[index].name = party.name
                }
            } else {
                discovery.companies.append(DiscoveredCompany(
                    cui: party.cui,
                    name: party.name,
                    documents: 1,
                    asCustomer: party.role == .customer ? 1 : 0,
                    asSupplier: party.role == .supplier ? 1 : 0,
                    lastSeen: Date()
                ))
            }
        }
        saveDiscovery()
    }

    private func saveDiscovery() {
        Storage.save(discovery, to: Self.discoveryFile)
    }

    /// Adevărat dacă firma e deja în „Firmele mele” (după CUI).
    func isKnownCompany(_ cui: String) -> Bool {
        config.companies.contains { company in
            company.keywordList.contains { $0.filter { $0.isNumber } == cui }
        }
    }

    /// Firmele care apar în cel puțin 2 documente și nu sunt încă ale tale sau respinse,
    /// cele care par ale tale (apar des, mai ales ca client) primele.
    var companySuggestions: [DiscoveredCompany] {
        discovery.companies
            .filter { !$0.dismissed && $0.documents >= 2 && !isKnownCompany($0.cui) }
            .sorted { likelihood($0) > likelihood($1) }
    }

    /// Cât de probabil e ca firma să fie a ta: apare pe o parte mare din documente și mai ales ca client.
    func likelihood(_ company: DiscoveredCompany) -> Double {
        let total = Double(max(1, discovery.totalDocuments))
        let share = Double(company.documents) / total
        return share * 2 + Double(company.asCustomer) * 0.5 + Double(company.documents) * 0.05
    }

    func looksLikeOwn(_ company: DiscoveredCompany) -> Bool {
        let share = Double(company.documents) / Double(max(1, discovery.totalDocuments))
        return company.documents >= 3 && (share >= 0.3 || company.asCustomer >= 2)
    }

    /// „E firma mea”: o adaugă la Firmele mele și creează regula ei (deasupra regulilor pe tipuri).
    func adoptCompany(_ company: DiscoveredCompany, name: String) {
        let cleanName = Names.safeFileName(name.trimmingCharacters(in: .whitespacesAndNewlines))
        let finalName = cleanName.isEmpty ? company.name : cleanName
        let nameKeyword = TextNormalizer.normalize(finalName).trimmingCharacters(in: .whitespaces)
        let keywords = nameKeyword.isEmpty ? company.cui : "\(company.cui), \(nameKeyword)"
        var updated = config
        if !isKnownCompany(company.cui) {
            updated.companies.append(CompanyProfile(name: finalName, keywords: keywords))
        }
        if !updated.rules.contains(where: { $0.destination.hasPrefix("Firme/\(finalName)/") || $0.destination == "Firme/\(finalName)" }) {
            let index = DefaultRules.insertionIndexForCompanyRule(in: updated.rules)
            updated.rules.insert(DefaultRules.company(finalName, keywords), at: index)
        }
        config = updated
        statusMessage = "„\(finalName)” adăugată la firmele tale, cu regula ei"
    }

    func dismissCompany(_ company: DiscoveredCompany) {
        guard let index = discovery.companies.firstIndex(where: { $0.cui == company.cui }) else { return }
        discovery.companies[index].dismissed = true
        saveDiscovery()
    }

    func restoreDismissedCompanies() {
        for index in discovery.companies.indices {
            discovery.companies[index].dismissed = false
        }
        saveDiscovery()
    }

    func scanCompaniesNow() {
        guard !companyScanRunning else { return }
        companyScanRunning = true
        companyScanProgress = "Adun documentele…"
        let token = CancelToken()
        companyScanToken = token
        cleanup.scanCompanies(folders: cleanupFolders,
                              excluded: config.excludedFolders,
                              settings: config.settings,
                              limit: 1500,
                              token: token,
                              progress: { done, total in
                                  Task { @MainActor in AppState.shared.companyScanProgress = "Citesc documentele… \(done) din \(total)" }
                              },
                              found: { key, parties in
                                  Task { @MainActor in AppState.shared.recordParties(key, parties) }
                              },
                              completion: {
                                  Task { @MainActor in
                                      AppState.shared.companyScanRunning = false
                                      AppState.shared.companyScanProgress = ""
                                  }
                              })
    }

    func stopCompanyScan() {
        companyScanToken.cancel()
        companyScanRunning = false
        companyScanProgress = ""
    }

    // MARK: Firmele mele

    func companyBinding(_ id: UUID) -> Binding<CompanyProfile> {
        Binding(
            get: {
                self.config.companies.first(where: { $0.id == id }) ?? CompanyProfile(name: "", keywords: "")
            },
            set: { newValue in
                guard let index = self.config.companies.firstIndex(where: { $0.id == id }) else { return }
                self.config.companies[index] = newValue
            }
        )
    }

    func addCompany() {
        config.companies.append(CompanyProfile(name: "Firmă nouă", keywords: ""))
    }

    func removeCompany(_ id: UUID) {
        config.companies.removeAll { $0.id == id }
    }

    /// Dacă rulează deja altă copie (ex. una veche din Aplicații), o închidem: rămâne doar cea pornită acum.
    private static func quitOtherInstances() {
        guard let bundleID = Bundle.main.bundleIdentifier else { return }
        let me = ProcessInfo.processInfo.processIdentifier
        for app in NSRunningApplication.runningApplications(withBundleIdentifier: bundleID) where app.processIdentifier != me {
            app.terminate()
        }
    }

    private func configDidChange() {
        Storage.save(config, to: "config.json")
        engine.update(config: config)
    }

    // MARK: Fereastra principală

    func showMainWindow(tab: MainTab? = nil) {
        if let tab {
            selectedTab = tab
        }
        if mainWindow == nil {
            let hosting = NSHostingController(rootView: MainView().environmentObject(self))
            hosting.sizingOptions = [.minSize]
            let window = NSWindow(contentViewController: hosting)
            window.title = "Sortator"
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            window.isReleasedWhenClosed = false
            window.setContentSize(NSSize(width: 980, height: 680))
            window.center()
            window.setFrameAutosaveName("SortatorMainWindow")
            let delegate = MainWindowDelegate { [weak self] in
                self?.mainWindowClosed()
            }
            window.delegate = delegate
            windowDelegate = delegate
            mainWindow = window
        }
        NSApp.setActivationPolicy(.regular)
        mainWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func mainWindowClosed() {
        NSApp.setActivationPolicy(.accessory)
    }

    // MARK: Istoric

    private func recordMove(_ entry: HistoryEntry) {
        history.insert(entry, at: 0)
        if history.count > 1000 {
            history.removeLast(history.count - 1000)
        }
        saveHistory()
        let newName = URL(fileURLWithPath: entry.toPath).lastPathComponent
        if newName != entry.fileName {
            statusMessage = "„\(entry.fileName)” → \(PathDisplay.parentFolder(entry.toPath))/\(newName)"
        } else {
            statusMessage = "Mutat „\(entry.fileName)” în \(PathDisplay.parentFolder(entry.toPath))"
        }
    }

    private func saveHistory() {
        Storage.save(history, to: "history.json")
    }

    func undo(_ entry: HistoryEntry) {
        let id = entry.id
        engine.undo(entry) { result in
            Task { @MainActor in AppState.shared.finishUndo(id, result) }
        }
    }

    private func finishUndo(_ id: UUID, _ result: Result<String, Error>) {
        switch result {
        case .success(let path):
            if let index = history.firstIndex(where: { $0.id == id }) {
                history[index].undone = true
                history[index].fromPath = path
            }
            saveHistory()
            statusMessage = "Readus în \(PathDisplay.parentFolder(path)) — nu va mai fi mutat automat"
        case .failure(let error):
            showAlert("Nu am putut readuce fișierul", error.localizedDescription)
        }
    }

    func reveal(_ entry: HistoryEntry) {
        let path = entry.undone ? entry.fromPath : entry.toPath
        let url = URL(fileURLWithPath: path)
        if FileManager.default.fileExists(atPath: path) {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } else {
            NSWorkspace.shared.open(url.deletingLastPathComponent())
        }
    }

    func clearHistory() {
        guard confirm("Golești istoricul?", "Fișierele rămân unde sunt; se șterge doar lista mutărilor.", ok: "Golește") else { return }
        history = []
        saveHistory()
    }

    // MARK: Foldere urmărite

    var hasDownloadsFolder: Bool {
        guard let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first else { return true }
        return config.folders.contains { $0.path == downloads.path }
    }

    func addDownloads() {
        guard let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first else { return }
        addWatchedFolder(downloads)
    }

    func addFolders() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        panel.canCreateDirectories = true
        panel.prompt = "Urmărește"
        panel.message = "Alege folderele în care Sortator să mute automat fișierele noi."
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            addWatchedFolder(url)
        }
    }

    private func addWatchedFolder(_ url: URL) {
        let path = url.standardizedFileURL.path
        if Exclusions.isExcluded(path, excluded: config.excludedFolders) {
            showAlert("„\(FileManager.default.displayName(atPath: path))” este un folder exclus",
                      "Sortator nu atinge folderele din lista de excluderi (de exemplu Aplicații). Scoate-l din listă dacă vrei totuși să fie urmărit.")
            return
        }
        guard !config.folders.contains(where: { $0.path == path }) else { return }
        config.folders.append(WatchedFolder(path: path))
    }

    func removeFolder(_ id: UUID) {
        config.folders.removeAll { $0.id == id }
    }

    func folderEnabledBinding(_ id: UUID) -> Binding<Bool> {
        Binding(
            get: { self.config.folders.first(where: { $0.id == id })?.enabled ?? false },
            set: { value in
                guard let index = self.config.folders.firstIndex(where: { $0.id == id }) else { return }
                self.config.folders[index].enabled = value
                if value {
                    self.config.folders[index].activeSince = Date()
                }
            }
        )
    }

    func isFolderExcluded(_ folder: WatchedFolder) -> Bool {
        Exclusions.isExcluded(folder.path, excluded: config.excludedFolders)
    }

    func openInFinder(_ path: String) {
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }

    // MARK: Foldere excluse

    func addExcludedFolders() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        panel.prompt = "Exclude"
        panel.message = "Alege folderele pe care Sortator nu trebuie să le atingă niciodată."
        if let first = config.folders.first {
            panel.directoryURL = first.url
        }
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            let short = PathDisplay.short(url.standardizedFileURL.path)
            let expanded = Exclusions.expand(short)
            if !config.excludedFolders.contains(where: { Exclusions.expand($0) == expanded }) {
                config.excludedFolders.append(short)
            }
        }
    }

    func removeExcludedFolder(_ path: String) {
        config.excludedFolders.removeAll { $0 == path }
    }

    func restoreDefaultExclusions() {
        for path in AppConfig.defaultExcludedFolders where !config.excludedFolders.contains(path) {
            config.excludedFolders.append(path)
        }
    }

    // MARK: Reguli

    func ruleBinding(_ id: UUID) -> Binding<SortRule> {
        Binding(
            get: {
                self.config.rules.first(where: { $0.id == id })
                    ?? SortRule(name: "", conditions: [], destination: "")
            },
            set: { newValue in
                guard let index = self.config.rules.firstIndex(where: { $0.id == id }) else { return }
                self.config.rules[index] = newValue
            }
        )
    }

    @discardableResult
    func addRule() -> UUID {
        let rule = SortRule(
            name: "Regulă nouă",
            matchMode: .all,
            conditions: [RuleCondition(field: .name, keywords: "")],
            destination: ""
        )
        config.rules.insert(rule, at: 0)
        return rule.id
    }

    func duplicateRule(_ id: UUID) -> UUID? {
        guard let index = config.rules.firstIndex(where: { $0.id == id }) else { return nil }
        var copy = config.rules[index]
        copy.id = UUID()
        copy.name += " (copie)"
        copy.conditions = copy.conditions.map { condition in
            var c = condition
            c.id = UUID()
            return c
        }
        config.rules.insert(copy, at: index + 1)
        return copy.id
    }

    func deleteRule(_ id: UUID) {
        config.rules.removeAll { $0.id == id }
    }

    func moveRule(_ id: UUID, by offset: Int) {
        guard let index = config.rules.firstIndex(where: { $0.id == id }) else { return }
        let target = index + offset
        guard target >= 0, target < config.rules.count else { return }
        config.rules.swapAt(index, target)
    }

    func resetRules() {
        guard confirm("Revii la regulile inițiale?",
                      "Regulile tale de acum se înlocuiesc cu cele inițiale (firmele și tipurile de fișiere). Poți exporta întâi regulile ca rezervă.",
                      ok: "Înlocuiește") else { return }
        config.rules = DefaultRules.all
    }

    func exportRules() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "Reguli Sortator.json"
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        do {
            try encoder.encode(config.rules).write(to: url, options: .atomic)
            statusMessage = "Reguli exportate în \(PathDisplay.short(url.path))"
        } catch {
            showAlert("Exportul nu a reușit", error.localizedDescription)
        }
    }

    func importRules() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url, let data = try? Data(contentsOf: url) else { return }

        var imported: [SortRule]
        if let rules = try? JSONDecoder().decode([SortRule].self, from: data) {
            imported = rules
        } else if let wrapper = try? JSONDecoder().decode(RulesOnly.self, from: data) {
            imported = wrapper.rules
        } else {
            showAlert("Fișierul nu conține reguli Sortator", "Alege un fișier .json exportat din Sortator.")
            return
        }
        imported = imported.map { rule in
            var r = rule
            r.id = UUID()
            r.conditions = r.conditions.map { condition in
                var c = condition
                c.id = UUID()
                return c
            }
            return r
        }

        let alert = NSAlert()
        alert.messageText = "Import: \(RO.count(imported.count, "regulă", "reguli"))"
        alert.informativeText = "Le adaugi la regulile existente sau le înlocuiești pe toate?"
        alert.addButton(withTitle: "Adaugă la cele existente")
        alert.addButton(withTitle: "Înlocuiește toate regulile")
        alert.addButton(withTitle: "Anulează")
        switch alert.runModal() {
        case .alertFirstButtonReturn:
            config.rules += imported
        case .alertSecondButtonReturn:
            config.rules = imported
        default:
            break
        }
    }

    func pickFolder() -> String? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Alege"
        if let first = config.folders.first {
            panel.directoryURL = first.url
        }
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        let chosen = url.standardizedFileURL.path
        for folder in config.folders {
            let base = folder.url.standardizedFileURL.path + "/"
            if chosen.hasPrefix(base) {
                return String(chosen.dropFirst(base.count))
            }
        }
        return PathDisplay.short(chosen)
    }

    func pickFileToTest() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Testează"
        if let first = config.folders.first {
            panel.directoryURL = first.url
        }
        return panel.runModal() == .OK ? panel.url : nil
    }

    // MARK: Pornire la login și instalare

    var isInstalledInApplications: Bool {
        Bundle.main.bundleURL.path.hasPrefix("/Applications/")
    }

    func setLaunchAtLogin(_ on: Bool) {
        do {
            if on {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            showAlert("Nu am putut schimba pornirea automată", error.localizedDescription)
        }
        let status = SMAppService.mainApp.status
        launchAtLogin = status == .enabled
        if on && status == .requiresApproval {
            SMAppService.openSystemSettingsLoginItems()
        }
    }

    func installInApplications() {
        let fm = FileManager.default
        let source = Bundle.main.bundleURL
        let destination = URL(fileURLWithPath: "/Applications", isDirectory: true).appendingPathComponent(source.lastPathComponent)
        do {
            if fm.fileExists(atPath: destination.path) {
                for app in NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "")
                where app.bundleURL?.standardizedFileURL == destination.standardizedFileURL {
                    app.terminate()
                }
                try fm.removeItem(at: destination)
            }
            try fm.copyItem(at: source, to: destination)
        } catch {
            showAlert("Nu am putut copia aplicația în Aplicații", error.localizedDescription)
            return
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: destination, configuration: configuration) { _, error in
            Task { @MainActor in
                if let error {
                    AppState.shared.showAlert("Aplicația a fost copiată, dar nu a pornit", error.localizedDescription)
                } else {
                    NSApp.terminate(nil)
                }
            }
        }
    }

    // MARK: Dialoguri

    func confirm(_ title: String, _ text: String, ok: String) -> Bool {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = text
        alert.addButton(withTitle: ok)
        alert.addButton(withTitle: "Anulează")
        return alert.runModal() == .alertFirstButtonReturn
    }

    func showAlert(_ title: String, _ text: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = text
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

@MainActor
final class MainWindowDelegate: NSObject, NSWindowDelegate {
    private let onClose: () -> Void

    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }

    func windowWillClose(_ notification: Notification) {
        onClose()
    }
}
