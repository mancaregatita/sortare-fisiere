import Foundation

// MARK: - Foldere urmărite

struct WatchedFolder: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var path: String
    var enabled: Bool = true
    /// Doar fișierele adăugate în folder după acest moment sunt sortate automat.
    var activeSince: Date = Date()
    /// Mod de probă: până la această dată Sortator doar propune mutările, tu le aprobi.
    var trialUntil: Date? = nil

    var inTrial: Bool { (trialUntil ?? .distantPast) > Date() }

    var url: URL { URL(fileURLWithPath: path, isDirectory: true) }
    var displayName: String { FileManager.default.displayName(atPath: path) }
    var shortPath: String { PathDisplay.short(path) }
}

// MARK: - Reguli

enum ConditionField: String, Codable, CaseIterable, Identifiable {
    case ext
    case name
    case content
    case nameOrContent

    var id: String { rawValue }

    var label: String {
        switch self {
        case .ext: return "Extensia este"
        case .name: return "Numele conține"
        case .content: return "Conținutul conține"
        case .nameOrContent: return "Numele sau conținutul conține"
        }
    }

    var placeholder: String {
        switch self {
        case .ext: return "pdf, docx, xlsx"
        case .name: return "factura, contract, oferta*"
        case .content: return "CUI, nume firmă, cuvinte din document"
        case .nameOrContent: return "CUI, nume firmă"
        }
    }

    /// Condițiile ieftine se verifică primele, ca să nu citim conținutul degeaba.
    var cost: Int {
        switch self {
        case .ext: return 0
        case .name: return 1
        case .nameOrContent: return 2
        case .content: return 3
        }
    }
}

struct RuleCondition: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var field: ConditionField
    var keywords: String

    var keywordList: [String] {
        keywords
            .split(whereSeparator: { $0 == "," || $0 == ";" || $0 == "\n" })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

enum MatchMode: String, Codable, CaseIterable, Identifiable {
    case all
    case any

    var id: String { rawValue }
    var label: String { self == .all ? "Toate condițiile" : "Oricare condiție" }
}

struct SortRule: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var enabled: Bool
    var matchMode: MatchMode
    var conditions: [RuleCondition]
    /// Relativ la folderul urmărit, sau cale absolută (/… sau ~/…). Gol = fișierul rămâne pe loc.
    var destination: String
    /// Redenumește documentele mutate: Tip Număr – Partener – Dată.
    var rename: Bool

    init(id: UUID = UUID(),
         name: String,
         enabled: Bool = true,
         matchMode: MatchMode = .all,
         conditions: [RuleCondition],
         destination: String,
         rename: Bool = false) {
        self.id = id
        self.name = name
        self.enabled = enabled
        self.matchMode = matchMode
        self.conditions = conditions
        self.destination = destination
        self.rename = rename
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        matchMode = try c.decodeIfPresent(MatchMode.self, forKey: .matchMode) ?? .all
        conditions = try c.decodeIfPresent([RuleCondition].self, forKey: .conditions) ?? []
        destination = try c.decodeIfPresent(String.self, forKey: .destination) ?? ""
        rename = try c.decodeIfPresent(Bool.self, forKey: .rename) ?? false
    }

    /// Regula pune documentul după tipul lui ({tipdoc}), deci se aplică doar documentelor recunoscute
    /// (factură, contract…). Altfel o arhivă oarecare cu numele firmei în ea ar ajunge la firmă.
    var needsDocumentType: Bool {
        destination.contains("{tipdoc}")
    }

    /// Destinația folosește date din document ({firma}, {tipdoc}, {partener}).
    var usesDocumentFields: Bool {
        destination.contains("{firma}") || destination.contains("{tipdoc}") || destination.contains("{partener}")
    }
}

/// Firmele tale: se folosesc pentru numele fișierului (Firmă) și ca să știm cine e partenerul.
struct CompanyProfile: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    /// CUI-uri și nume după care e recunoscută, separate prin virgulă.
    var keywords: String

    var keywordList: [String] {
        keywords
            .split(whereSeparator: { $0 == "," || $0 == ";" || $0 == "\n" })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

// MARK: - Setări

struct AppSettings: Codable, Hashable {
    var paused: Bool = false
    var delaySeconds: Double = 3
    var readPDFText: Bool = true
    var ocrScannedPDFs: Bool = true
    var ocrImages: Bool = true
    var readOfficeFiles: Bool = true
    var readArchives: Bool = true
    var maxPages: Int = 3
    var renameDocuments: Bool = true
    var useAppleAI: Bool = true
    var autoDuplicateScan: Bool = true
    var askAboutInstallers: Bool = true
    var installerDays: Int = 30
    /// iCloud: după sortare, copia locală se șterge (fișierul rămâne în iCloud).
    var freeSpaceAfterSorting: Bool = true
    /// iCloud: documentele care trebuie citite se descarcă pe rând, apoi se eliberează.
    var downloadDocumentsToRead: Bool = true
    /// Notificare „Ai instalat X. Ștergi installerul?”.
    var notifyAfterInstall: Bool = true
    /// Câte zile stă un folder nou în modul de probă (0 = fără probă).
    var trialDays: Int = 3
    /// Versiuni vechi ale aceluiași fișier (tema-v21, tema-v54): arată-le pe cele depășite.
    var findOldVersions: Bool = true
    /// Capturi de ecran mai vechi de `screenshotDays` zile: propune mutarea la coș.
    var findOldScreenshots: Bool = true
    var screenshotDays: Int = 30
    /// Rezumatul de seară (notificare).
    var dailySummary: Bool = true
    var summaryHour: Int = 20

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = AppSettings()
        renameDocuments = try c.decodeIfPresent(Bool.self, forKey: .renameDocuments) ?? d.renameDocuments
        useAppleAI = try c.decodeIfPresent(Bool.self, forKey: .useAppleAI) ?? d.useAppleAI
        autoDuplicateScan = try c.decodeIfPresent(Bool.self, forKey: .autoDuplicateScan) ?? d.autoDuplicateScan
        askAboutInstallers = try c.decodeIfPresent(Bool.self, forKey: .askAboutInstallers) ?? d.askAboutInstallers
        installerDays = try c.decodeIfPresent(Int.self, forKey: .installerDays) ?? d.installerDays
        freeSpaceAfterSorting = try c.decodeIfPresent(Bool.self, forKey: .freeSpaceAfterSorting) ?? d.freeSpaceAfterSorting
        downloadDocumentsToRead = try c.decodeIfPresent(Bool.self, forKey: .downloadDocumentsToRead) ?? d.downloadDocumentsToRead
        notifyAfterInstall = try c.decodeIfPresent(Bool.self, forKey: .notifyAfterInstall) ?? d.notifyAfterInstall
        trialDays = try c.decodeIfPresent(Int.self, forKey: .trialDays) ?? d.trialDays
        findOldVersions = try c.decodeIfPresent(Bool.self, forKey: .findOldVersions) ?? d.findOldVersions
        findOldScreenshots = try c.decodeIfPresent(Bool.self, forKey: .findOldScreenshots) ?? d.findOldScreenshots
        screenshotDays = try c.decodeIfPresent(Int.self, forKey: .screenshotDays) ?? d.screenshotDays
        dailySummary = try c.decodeIfPresent(Bool.self, forKey: .dailySummary) ?? d.dailySummary
        summaryHour = try c.decodeIfPresent(Int.self, forKey: .summaryHour) ?? d.summaryHour
        paused = try c.decodeIfPresent(Bool.self, forKey: .paused) ?? d.paused
        delaySeconds = try c.decodeIfPresent(Double.self, forKey: .delaySeconds) ?? d.delaySeconds
        readPDFText = try c.decodeIfPresent(Bool.self, forKey: .readPDFText) ?? d.readPDFText
        ocrScannedPDFs = try c.decodeIfPresent(Bool.self, forKey: .ocrScannedPDFs) ?? d.ocrScannedPDFs
        ocrImages = try c.decodeIfPresent(Bool.self, forKey: .ocrImages) ?? d.ocrImages
        readOfficeFiles = try c.decodeIfPresent(Bool.self, forKey: .readOfficeFiles) ?? d.readOfficeFiles
        readArchives = try c.decodeIfPresent(Bool.self, forKey: .readArchives) ?? d.readArchives
        maxPages = try c.decodeIfPresent(Int.self, forKey: .maxPages) ?? d.maxPages
    }
}

struct AppConfig: Codable {
    var folders: [WatchedFolder] = []
    var rules: [SortRule] = DefaultRules.all
    var settings: AppSettings = AppSettings()
    /// Foldere pe care aplicația nu le atinge niciodată: nu ia fișiere din ele și nu pune fișiere în ele.
    var excludedFolders: [String] = AppConfig.defaultExcludedFolders
    var companies: [CompanyProfile] = DefaultRules.companies
    /// 1 = prima versiune; 2 = redenumire + tip document; 3 = structura în engleză (Firme/<firmă>/<an>/<tip>);
    /// 4 = Screenshots separat + mod de probă.
    var version: Int = AppConfig.currentVersion

    static let currentVersion = 4

    static let defaultExcludedFolders: [String] = [
        "/Applications",
        "~/Applications",
        "/System",
        "/Library",
        "~/Library"
    ]

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        folders = try c.decodeIfPresent([WatchedFolder].self, forKey: .folders) ?? []
        rules = try c.decodeIfPresent([SortRule].self, forKey: .rules) ?? DefaultRules.all
        settings = try c.decodeIfPresent(AppSettings.self, forKey: .settings) ?? AppSettings()
        excludedFolders = try c.decodeIfPresent([String].self, forKey: .excludedFolders) ?? AppConfig.defaultExcludedFolders
        companies = try c.decodeIfPresent([CompanyProfile].self, forKey: .companies) ?? []
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 1
    }

    /// Aduce o configurație veche la versiunea curentă, fără să piardă ce ai modificat.
    static func migrate(_ old: AppConfig) -> (AppConfig, Bool) {
        var c = old
        guard c.version < currentVersion else { return (c, false) }
        if c.version < 2 {
            for index in c.rules.indices {
                let destination = c.rules[index].destination
                if destination.hasPrefix("Firme/") && !destination.contains("{") {
                    c.rules[index].destination = destination + "/{tipdoc}"
                    c.rules[index].rename = true
                }
                if c.rules[index].name == "Documente" {
                    c.rules[index].rename = true
                }
            }
            if c.companies.isEmpty {
                // Firmele se deduc din regulile tale existente de tip „Firme/…”.
                c.companies = c.rules
                    .filter { $0.destination.hasPrefix("Firme/") }
                    .map { rule in
                        let keywords = rule.conditions
                            .filter { $0.field != .ext }
                            .map { $0.keywords }
                            .joined(separator: ", ")
                        return CompanyProfile(name: rule.name, keywords: keywords)
                    }
            }
        }
        if c.version < 3 {
            // Regulile inițiale pe tipuri (în română) se înlocuiesc cu cele noi, în engleză.
            let legacyTypeRules = DefaultRules.legacyTypeRuleNames
            c.rules.removeAll { rule in
                legacyTypeRules.contains(rule.name) && rule.destination == rule.name
            }
            let existingNames = Set(c.rules.map { $0.name })
            c.rules += DefaultRules.typeRules.filter { !existingNames.contains($0.name) }
            // Firmele: Firme/<firmă>/{tipdoc} → Firme/<firmă>/{an}/{tipdoc}.
            for index in c.rules.indices {
                let destination = c.rules[index].destination
                if destination.hasPrefix("Firme/") && destination.hasSuffix("/{tipdoc}") && !destination.contains("{an}") {
                    c.rules[index].destination = String(destination.dropLast("/{tipdoc}".count)) + "/{an}/{tipdoc}"
                }
            }
        }
        if c.version < 4 {
            // Capturile de ecran în Images/Screenshots: regula stă înaintea celei pentru Images.
            if !c.rules.contains(where: { $0.name == DefaultRules.screenshotsRuleName }) {
                let index = c.rules.firstIndex(where: { $0.name == "Images" }) ?? c.rules.count
                c.rules.insert(DefaultRules.screenshots, at: index)
            }
            // După sortarea greșită din 25 noiembrie: folderele existente pornesc în modul de probă.
            let until = Date().addingTimeInterval(Double(max(1, c.settings.trialDays)) * 86_400)
            for index in c.folders.indices where c.folders[index].enabled {
                c.folders[index].trialUntil = until
            }
        }
        c.version = currentVersion
        return (c, true)
    }
}

enum Exclusions {
    static func expand(_ path: String) -> String {
        let expanded = (path as NSString).expandingTildeInPath
        return URL(fileURLWithPath: expanded).standardizedFileURL.path
    }

    /// Adevărat dacă `path` este unul dintre folderele excluse sau se află în interiorul lor.
    static func isExcluded(_ path: String, excluded: [String]) -> Bool {
        let p = URL(fileURLWithPath: path).standardizedFileURL.path
        let inICloud = ICloud.isInDrive(p)
        for item in excluded {
            let e = expand(item)
            if e.isEmpty || e == "/" { continue }
            // „~/Library” nu blochează iCloud Drive (care stă în ~/Library/Mobile Documents).
            if inICloud && ICloud.drivePath.hasPrefix(e + "/") { continue }
            if p == e || p.hasPrefix(e + "/") { return true }
        }
        return false
    }

    /// Fișiere sau foldere care arată a aplicații sau pachete (nu se mută niciodată).
    static let protectedExtensions: Set<String> = ["app", "appex", "framework", "bundle", "kext", "plugin", "prefpane", "xpc", "photoslibrary", "musiclibrary", "fcpbundle"]
}

/// Folosit la import: acceptă un fișier care are cheia "rules".
struct RulesOnly: Decodable {
    let rules: [SortRule]
}

// MARK: - Istoric și rezultate

struct HistoryEntry: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var date: Date
    var fileName: String
    var fromPath: String
    var toPath: String
    var ruleName: String
    var undone: Bool = false
}

/// O mutare propusă în modul de probă: așteaptă aprobarea ta.
struct ProposedMove: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var date: Date
    var sourcePath: String
    var destinationFolderPath: String
    var newName: String
    var ruleName: String

    var fileName: String { URL(fileURLWithPath: sourcePath).lastPathComponent }

    var planned: PlannedMove {
        PlannedMove(source: URL(fileURLWithPath: sourcePath),
                    destinationFolder: URL(fileURLWithPath: destinationFolderPath, isDirectory: true),
                    newName: newName,
                    ruleName: ruleName)
    }
}

struct PlannedMove: Identifiable, Hashable {
    let id = UUID()
    let source: URL
    let destinationFolder: URL
    let newName: String
    let ruleName: String
}

struct TestResult {
    var fileName: String
    var ruleName: String?
    var destination: String?
    var textMethod: String
    var textSnippet: String
    var ruleReport: [String]
    var documentType: String
    var company: String
    var partner: String
    var number: String
    var dateText: String
    var proposedName: String
}

// MARK: - Curățenie

struct DuplicateFile: Identifiable, Hashable {
    var id: String { url.path }
    let url: URL
    let size: Int64
    let added: Date
}

struct DuplicateGroup: Identifiable, Hashable {
    let id = UUID()
    let size: Int64
    /// Sortate de la cel mai vechi la cel mai nou.
    let files: [DuplicateFile]
}

struct OldInstaller: Identifiable, Hashable {
    var id: String { url.path }
    let url: URL
    let size: Int64
    let added: Date
}

/// Un fișier vechi propus pentru coș (ex. o captură de ecran).
struct OldFile: Identifiable, Hashable {
    var id: String { url.path }
    let url: URL
    let size: Int64
    let added: Date
}

/// Versiunile aceluiași fișier (ex. tema-v21 … tema-v54). Prima e cea mai nouă și rămâne.
struct VersionGroup: Identifiable, Hashable {
    var id: String { key }
    let key: String
    let files: [VersionFile]
}

struct VersionFile: Identifiable, Hashable {
    var id: String { url.path }
    let url: URL
    let version: Int
    let size: Int64
    let modified: Date
}

struct EngineError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

final class CancelToken {
    private let lock = NSLock()
    private var cancelled = false

    var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelled
    }

    func cancel() {
        lock.lock()
        cancelled = true
        lock.unlock()
    }
}

// MARK: - Firme găsite în documente

struct DiscoveredCompany: Codable, Identifiable, Hashable {
    var id: String { cui }
    var cui: String
    var name: String
    var documents: Int = 0
    var asCustomer: Int = 0
    var asSupplier: Int = 0
    var lastSeen: Date = Date()
    /// Ai spus „Nu e firma mea”.
    var dismissed: Bool = false
}

struct DiscoveryStore: Codable {
    var companies: [DiscoveredCompany] = []
    /// Documentele deja numărate (cale|mărime), ca să nu numărăm același fișier de două ori.
    var countedDocuments: [String] = []
    var totalDocuments: Int = 0
}
