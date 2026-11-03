import Foundation

enum TextNormalizer {
    private static let locale = Locale(identifier: "ro_RO")
    private static let space: Unicode.Scalar = " "

    /// Fără majuscule și fără diacritice (ș → s, ț → t, ă → a).
    static func fold(_ s: String) -> String {
        s.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: locale)
    }

    /// Text comparabil: fără majuscule/diacritice, orice semn de punctuație devine un singur spațiu,
    /// cu spațiu la început și la sfârșit (ca să putem căuta cuvinte întregi).
    static func normalize(_ s: String) -> String {
        let folded = fold(s)
        var out = String.UnicodeScalarView()
        out.append(space)
        var lastWasSpace = true
        for scalar in folded.unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) {
                out.append(scalar)
                lastWasSpace = false
            } else if !lastWasSpace {
                out.append(space)
                lastWasSpace = true
            }
        }
        if !lastWasSpace { out.append(space) }
        return String(out)
    }
}

/// Un cuvânt cheie scris de utilizator.
/// - `factura`   → cuvânt întreg
/// - `factur*`   → începe cu (factura, facturi, facturare)
/// - `*factura`  → se termină cu
/// - `*fact*`    → oriunde
/// - `12345678`  → număr (îl găsește și în RO12345678, dar nu în 912345678)
struct KeywordPattern {
    enum Kind { case word, prefix, suffix, anywhere, number }

    let kind: Kind
    let core: String

    init?(_ raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let starAtStart = trimmed.hasPrefix("*")
        let starAtEnd = trimmed.hasSuffix("*")
        let inner = trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "*"))
        let normalized = TextNormalizer.normalize(inner).trimmingCharacters(in: .whitespaces)
        guard !normalized.isEmpty else { return nil }
        core = normalized
        let onlyDigits = normalized.unicodeScalars.allSatisfy { CharacterSet.decimalDigits.contains($0) }
        if onlyDigits && !starAtStart && !starAtEnd {
            kind = .number
        } else if starAtStart && starAtEnd {
            kind = .anywhere
        } else if starAtEnd {
            kind = .prefix
        } else if starAtStart {
            kind = .suffix
        } else {
            kind = .word
        }
    }

    /// `text` trebuie să fie trecut prin TextNormalizer.normalize.
    func matches(_ text: String) -> Bool {
        switch kind {
        case .word: return text.contains(" " + core + " ")
        case .prefix: return text.contains(" " + core)
        case .suffix: return text.contains(core + " ")
        case .anywhere: return text.contains(core)
        case .number: return text.range(of: "(?<![0-9])" + core + "(?![0-9])", options: .regularExpression) != nil
        }
    }
}

/// Informațiile despre un fișier, cu conținutul citit doar când o regulă chiar are nevoie de el.
final class FileContext {
    static let imageExtensions: Set<String> = ["jpg", "jpeg", "png", "heic", "heif", "tif", "tiff", "bmp", "gif", "webp"]

    let url: URL
    let ext: String
    let normalizedName: String
    /// Când a apărut fișierul în folder (data descărcării).
    let addedDate: Date
    var isImage: Bool { Self.imageExtensions.contains(ext) }
    private let extractor: ContentExtractor
    private var loaded = false
    private var normalizedText = ""
    private(set) var extracted = ExtractedText()
    private var cachedInfo: DocumentInfo?

    init(url: URL, extractor: ContentExtractor) {
        self.url = url
        self.ext = url.pathExtension.lowercased()
        self.normalizedName = TextNormalizer.normalize(url.deletingPathExtension().lastPathComponent)
        self.extractor = extractor
        let values = try? url.resourceValues(forKeys: [.addedToDirectoryDateKey, .creationDateKey])
        self.addedDate = values?.addedToDirectoryDate ?? values?.creationDate ?? Date()
    }

    /// Tipul documentului, firma, partenerul și data (calculate o singură dată).
    func documentInfo(companies: [CompanyProfile], settings: AppSettings) -> DocumentInfo {
        if let cachedInfo { return cachedInfo }
        let info = DocumentAnalyzer.analyze(self, companies: companies, settings: settings)
        cachedInfo = info
        return info
    }

    func normalizedContent() -> String {
        if !loaded {
            loaded = true
            extracted = extractor.extract(url)
            normalizedText = TextNormalizer.normalize(extracted.text)
        }
        return normalizedText
    }
}

enum RuleMatcher {
    static func anyKeyword(_ keywords: [String], in text: String) -> Bool {
        for keyword in keywords {
            if let pattern = KeywordPattern(keyword), pattern.matches(text) { return true }
        }
        return false
    }

    static func conditionMatches(_ condition: RuleCondition, _ file: FileContext) -> Bool {
        let keywords = condition.keywordList
        guard !keywords.isEmpty else { return false }
        switch condition.field {
        case .ext:
            let extensions = keywords.map { $0.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ". *")) }
            return keywords.contains("*") || extensions.contains(file.ext)
        case .name:
            return anyKeyword(keywords, in: file.normalizedName)
        case .content:
            return anyKeyword(keywords, in: file.normalizedContent())
        case .nameOrContent:
            return anyKeyword(keywords, in: file.normalizedName) || anyKeyword(keywords, in: file.normalizedContent())
        }
    }

    static func ruleMatches(_ rule: SortRule, _ file: FileContext) -> Bool {
        guard rule.enabled else { return false }
        let conditions = rule.conditions
            .filter { !$0.keywordList.isEmpty }
            .sorted { $0.field.cost < $1.field.cost }
        guard !conditions.isEmpty else { return false }
        switch rule.matchMode {
        case .all: return conditions.allSatisfy { conditionMatches($0, file) }
        case .any: return conditions.contains { conditionMatches($0, file) }
        }
    }

    static func firstMatch(_ rules: [SortRule], _ file: FileContext) -> SortRule? {
        rules.first { ruleMatches($0, file) }
    }
}
