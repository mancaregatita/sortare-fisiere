import Foundation

// MARK: - Tipuri de documente

struct DocType: Hashable {
    /// Cum apare în numele fișierului (singular).
    let name: String
    /// Folderul folosit pentru {tipdoc} (plural).
    let folder: String
    /// Expresii căutate (fără diacritice, litere mici). Prima e cea mai sigură.
    let phrases: [String]
}

enum DocTypes {
    static let invoice = DocType(name: "Factură", folder: "Facturi", phrases: ["factura fiscala", "factura", "invoice", "e factura"])

    /// Ordinea contează la egalitate: cele mai specifice sunt primele.
    static let all: [DocType] = [
        DocType(name: "Proformă", folder: "Proforme", phrases: ["factura proforma", "proforma"]),
        invoice,
        DocType(name: "Chitanță", folder: "Chitanțe", phrases: ["chitanta"]),
        DocType(name: "Bon fiscal", folder: "Bonuri", phrases: ["bon fiscal"]),
        DocType(name: "Aviz", folder: "Avize", phrases: ["aviz de insotire a marfii", "aviz de insotire"]),
        DocType(name: "NIR", folder: "NIR", phrases: ["nota de receptie si constatare de diferente", "nota de receptie"]),
        DocType(name: "Act adițional", folder: "Contracte", phrases: ["act aditional", "actul aditional"]),
        DocType(name: "Contract", folder: "Contracte", phrases: ["contract de", "partile contractante", "obiectul contractului", "contractul", "contract"]),
        DocType(name: "Extras de cont", folder: "Bancă", phrases: ["extras de cont", "sold initial", "sold final", "account statement"]),
        DocType(name: "Ordin de plată", folder: "Bancă", phrases: ["ordin de plata"]),
        DocType(name: "Ofertă", folder: "Oferte", phrases: ["oferta de pret", "oferta comerciala", "cotatie de pret", "oferta"]),
        DocType(name: "Comandă", folder: "Comenzi", phrases: ["nota de comanda", "comanda de achizitie", "purchase order", "comanda"]),
        DocType(name: "Somație", folder: "Somații", phrases: ["somatie", "somatia"]),
        DocType(name: "Decizie", folder: "Decizii", phrases: ["decizie", "decizia"]),
        DocType(name: "Proces-verbal", folder: "Procese-verbale", phrases: ["proces verbal", "procesul verbal"]),
        DocType(name: "Notificare", folder: "Notificări", phrases: ["notificare", "instiintare"]),
        DocType(name: "Declarație", folder: "Declarații", phrases: ["declaratie", "declaratia"]),
        DocType(name: "Certificat", folder: "Certificate", phrases: ["certificat", "certificatul"]),
        DocType(name: "Autorizație", folder: "Autorizații", phrases: ["autorizatie", "autorizatia"]),
        DocType(name: "Adeverință", folder: "Adeverințe", phrases: ["adeverinta"]),
        DocType(name: "Stat de plată", folder: "Salarii", phrases: ["stat de plata", "fluturas de salariu", "fluturas"]),
        DocType(name: "Cerere", folder: "Cereri", phrases: ["cerere", "cererea"])
    ]

    static func named(_ name: String) -> DocType? {
        let wanted = TextNormalizer.fold(name).trimmingCharacters(in: .whitespacesAndNewlines)
        return all.first { TextNormalizer.fold($0.name) == wanted }
    }

    /// Numele, începutul documentului și restul textului sunt deja normalizate (TextNormalizer.normalize).
    static func detect(name: String, title: String, body: String) -> DocType? {
        var best: DocType?
        var bestScore = 0
        for type in all {
            var score = 0
            for (index, phrase) in type.phrases.enumerated() {
                let needle = " " + phrase + " "
                let weight = index == 0 ? 2 : 1
                if name.contains(needle) { score += 6 * weight }
                if title.contains(needle) { score += 4 * weight }
                if body.contains(needle) { score += weight }
            }
            if score > bestScore {
                bestScore = score
                best = type
            }
        }
        return bestScore >= 4 ? best : nil
    }
}

// MARK: - Rezultatul analizei

struct DocumentInfo {
    var type: DocType?
    var company: String?
    var partner: String?
    var date: Date
    var dateSource: String
    var usedAI: Bool = false

    static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    var dateString: String { Self.dayFormatter.string(from: date) }

    /// Dată – Firmă – Tip – Partener.ext (doar dacă știm tipul documentului).
    func fileName(extension ext: String) -> String? {
        guard let type else { return nil }
        var parts = [dateString]
        if let company, !company.isEmpty { parts.append(company) }
        parts.append(type.name)
        if let partner, !partner.isEmpty,
           TextNormalizer.fold(partner) != TextNormalizer.fold(company ?? "") {
            parts.append(partner)
        }
        var base = Names.safeFileName(parts.joined(separator: " – "))
        if base.count > 150 { base = String(base.prefix(150)).trimmingCharacters(in: .whitespaces) }
        return ext.isEmpty ? base : base + "." + ext
    }
}

// MARK: - Analiza

enum DocumentAnalyzer {
    static func analyze(_ file: FileContext, companies: [CompanyProfile], settings: AppSettings) -> DocumentInfo {
        let normalizedText = file.normalizedContent()
        let text = file.extracted.text
        let title = String(normalizedText.prefix(700))

        var type: DocType?
        var company: String?
        var partner: String?
        var date: Date?
        var source = ""
        var usedAI = false

        // e-Factura: datele sunt structurate, deci sigure.
        if let raw = file.extracted.raw, let invoice = EFactura.parse(raw, companies: companies) {
            type = DocTypes.invoice
            company = invoice.company
            partner = invoice.partner
            if let issue = invoice.issueDate {
                date = issue
                source = "data facturii (e-Factura)"
            }
        }

        if type == nil {
            type = DocTypes.detect(name: file.normalizedName, title: title, body: normalizedText)
        }
        if company == nil {
            company = ownCompany(in: [file.normalizedName, normalizedText], companies: companies)
        }
        if partner == nil, type != nil {
            partner = partnerFromText(text, companies: companies)
        }

        // AI-ul Apple, doar ca rezervă, când regulile nu au recunoscut tipul.
        if type == nil, settings.useAppleAI,
           text.trimmingCharacters(in: .whitespacesAndNewlines).count >= 40,
           let guess = AppleAI.guess(text: text) {
            if let guessed = DocTypes.named(guess.type) {
                type = guessed
                usedAI = true
            }
            if partner == nil, let cleaned = Names.clean(guess.partner),
               !isOwn(TextNormalizer.normalize(cleaned), companies: companies) {
                partner = cleaned
            }
            if date == nil, !file.isImage, let parsed = DateFinder.parseISO(guess.date) {
                date = parsed
                source = "data din document (AI)"
            }
        }

        if date == nil {
            if file.isImage {
                date = file.addedDate
                source = "data descărcării (poză)"
            } else if let found = DateFinder.findDate(type: type, text: text) {
                date = found
                source = type?.folder == "Contracte" ? "data de început din contract" : "data din document"
            } else {
                date = file.addedDate
                source = "data descărcării (nu am găsit o dată în document)"
            }
        }

        return DocumentInfo(
            type: type,
            company: company,
            partner: partner,
            date: date ?? file.addedDate,
            dateSource: source,
            usedAI: usedAI
        )
    }

    static func isOwn(_ normalized: String, companies: [CompanyProfile]) -> Bool {
        ownCompany(in: [normalized], companies: companies) != nil
    }

    static func ownCompany(in normalizedTexts: [String], companies: [CompanyProfile]) -> String? {
        for company in companies {
            for text in normalizedTexts where RuleMatcher.anyKeyword(company.keywordList, in: text) {
                return company.name
            }
        }
        return nil
    }

    private static let partyLabels = [
        "furnizor", "vanzator", "prestator", "emitent", "cumparator", "client", "beneficiar",
        "achizitor", "locator", "locatar", "comodant", "comodatar", "partener", "executant"
    ]

    /// Caută „Furnizor: …”, „Client: …” etc. și alege firma care nu e a ta.
    static func partnerFromText(_ text: String, companies: [CompanyProfile]) -> String? {
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let head = Array(lines.prefix(150))
        var candidates: [String] = []

        for (index, line) in head.enumerated() {
            let folded = TextNormalizer.fold(line)
            guard let label = partyLabels.first(where: { folded.hasPrefix($0) }) else { continue }
            var rest = String(line.dropFirst(label.count).drop(while: { $0.isLetter }))
            rest = rest.trimmingCharacters(in: CharacterSet(charactersIn: " :-–\t"))
            if rest.filter({ $0.isLetter }).count < 3, index + 1 < head.count {
                rest = head[index + 1]
            }
            candidates.append(rest)
        }

        let legalForm = "(?i)(\\bS\\.?R\\.?L\\b|\\bS\\.A\\.|\\bP\\.?F\\.?A\\b|\\bSRL\\b)"
        for line in head where line.range(of: legalForm, options: .regularExpression) != nil {
            candidates.append(line)
        }

        for candidate in candidates {
            guard let cleaned = Names.clean(candidate) else { continue }
            if isOwn(TextNormalizer.normalize(candidate), companies: companies) { continue }
            if isOwn(TextNormalizer.normalize(cleaned), companies: companies) { continue }
            return cleaned
        }
        return nil
    }
}

// MARK: - e-Factura (XML UBL din SPV)

enum EFactura {
    struct Result {
        var company: String?
        var partner: String?
        var issueDate: Date?
    }

    static func parse(_ raw: String, companies: [CompanyProfile]) -> Result? {
        guard raw.contains("AccountingSupplierParty"),
              raw.contains("Invoice") || raw.contains("CreditNote") else { return nil }

        let supplier = block(raw, tag: "AccountingSupplierParty")
        let customer = block(raw, tag: "AccountingCustomerParty")
        let supplierName = supplier.flatMap { value($0, tag: "RegistrationName") ?? value($0, tag: "Name") }
        let customerName = customer.flatMap { value($0, tag: "RegistrationName") ?? value($0, tag: "Name") }
        let supplierID = supplier.flatMap { value($0, tag: "CompanyID") }
        let customerID = customer.flatMap { value($0, tag: "CompanyID") }

        let supplierOwn = own(name: supplierName, id: supplierID, companies: companies)
        let customerOwn = own(name: customerName, id: customerID, companies: companies)

        var result = Result()
        if let ownName = supplierOwn {
            result.company = ownName
            result.partner = customerName
        } else if let ownName = customerOwn {
            result.company = ownName
            result.partner = supplierName
        } else {
            result.partner = supplierName
        }
        result.partner = result.partner.flatMap { Names.clean($0) }
        if let issue = value(raw, tag: "IssueDate") {
            result.issueDate = DateFinder.parseISO(issue)
        }
        return result
    }

    private static func own(name: String?, id: String?, companies: [CompanyProfile]) -> String? {
        let normalized = TextNormalizer.normalize((name ?? "") + " " + (id ?? ""))
        return DocumentAnalyzer.ownCompany(in: [normalized], companies: companies)
    }

    static func blockPublic(_ s: String, tag: String) -> String? { block(s, tag: tag) }
    static func valuePublic(_ s: String, tag: String) -> String? { value(s, tag: tag) }

    private static func block(_ s: String, tag: String) -> String? {
        let pattern = "<(?:[A-Za-z0-9]+:)?\(tag)[\\s>].*?</(?:[A-Za-z0-9]+:)?\(tag)>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else { return nil }
        let ns = s as NSString
        guard let match = regex.firstMatch(in: s, range: NSRange(location: 0, length: ns.length)) else { return nil }
        return ns.substring(with: match.range)
    }

    private static func value(_ s: String, tag: String) -> String? {
        let pattern = "<(?:[A-Za-z0-9]+:)?\(tag)(?:\\s[^>]*)?>([^<]*)</"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let ns = s as NSString
        guard let match = regex.firstMatch(in: s, range: NSRange(location: 0, length: ns.length)),
              match.numberOfRanges > 1 else { return nil }
        let text = ContentExtractor.decodeEntities(ns.substring(with: match.range(at: 1)))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }
}

// MARK: - Date

enum DateFinder {
    private struct Found {
        let date: Date
        let offset: Int
    }

    private static let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone.current
        return c
    }()

    private static let numeric = try? NSRegularExpression(pattern: "(?<![0-9])([0-3]?[0-9])[./-]([01]?[0-9])[./-]((?:19|20)[0-9]{2})(?![0-9])")
    private static let iso = try? NSRegularExpression(pattern: "(?<![0-9])((?:19|20)[0-9]{2})-([01][0-9])-([0-3][0-9])(?![0-9])")
    private static let words = try? NSRegularExpression(pattern: "(?<![0-9])([0-3]?[0-9])\\s+(ianuarie|februarie|martie|aprilie|mai|iunie|iulie|august|septembrie|octombrie|noiembrie|decembrie|ian|feb|mar|apr|iun|iul|aug|sept|sep|oct|noi|nov|dec)\\.?\\s+((?:19|20)[0-9]{2})(?![0-9])")

    private static let months: [String: Int] = [
        "ianuarie": 1, "ian": 1, "februarie": 2, "feb": 2, "martie": 3, "mar": 3,
        "aprilie": 4, "apr": 4, "mai": 5, "iunie": 6, "iun": 6, "iulie": 7, "iul": 7,
        "august": 8, "aug": 8, "septembrie": 9, "sept": 9, "sep": 9, "octombrie": 10, "oct": 10,
        "noiembrie": 11, "noi": 11, "nov": 11, "decembrie": 12, "dec": 12
    ]

    static func parseISO(_ s: String) -> Date? {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.prefix(10).split(separator: "-")
        guard parts.count == 3, let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2]) else { return nil }
        return make(y, m, d)
    }

    private static func make(_ year: Int, _ month: Int, _ day: Int) -> Date? {
        let currentYear = calendar.component(.year, from: Date())
        guard (1990...(currentYear + 5)).contains(year), (1...12).contains(month), (1...31).contains(day) else { return nil }
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        comps.hour = 12
        guard let date = calendar.date(from: comps) else { return nil }
        let check = calendar.dateComponents([.year, .month, .day], from: date)
        guard check.year == year, check.month == month, check.day == day else { return nil }
        return date
    }

    private static func allDates(in folded: String) -> [Found] {
        let ns = folded as NSString
        let range = NSRange(location: 0, length: ns.length)
        var found: [Found] = []
        if let regex = numeric {
            for m in regex.matches(in: folded, range: range) where m.numberOfRanges == 4 {
                if let d = Int(ns.substring(with: m.range(at: 1))),
                   let mo = Int(ns.substring(with: m.range(at: 2))),
                   let y = Int(ns.substring(with: m.range(at: 3))),
                   let date = make(y, mo, d) {
                    found.append(Found(date: date, offset: m.range.location))
                }
            }
        }
        if let regex = iso {
            for m in regex.matches(in: folded, range: range) where m.numberOfRanges == 4 {
                if let y = Int(ns.substring(with: m.range(at: 1))),
                   let mo = Int(ns.substring(with: m.range(at: 2))),
                   let d = Int(ns.substring(with: m.range(at: 3))),
                   let date = make(y, mo, d) {
                    found.append(Found(date: date, offset: m.range.location))
                }
            }
        }
        if let regex = words {
            for m in regex.matches(in: folded, range: range) where m.numberOfRanges == 4 {
                if let d = Int(ns.substring(with: m.range(at: 1))),
                   let mo = months[ns.substring(with: m.range(at: 2))],
                   let y = Int(ns.substring(with: m.range(at: 3))),
                   let date = make(y, mo, d) {
                    found.append(Found(date: date, offset: m.range.location))
                }
            }
        }
        return found.sorted { $0.offset < $1.offset }
    }

    /// Alege data potrivită tipului: la contracte data de început, la facturi data emiterii.
    static func findDate(type: DocType?, text: String) -> Date? {
        let folded = TextNormalizer.fold(String(text.prefix(30_000)))
        let found = allDates(in: folded)
        guard !found.isEmpty else { return nil }

        let anchors: [String]
        switch type?.folder {
        case "Contracte":
            anchors = ["incepand cu data de", "incepand cu data", "incepand cu", "intra in vigoare", "data intrarii in vigoare",
                       "valabil incepand", "valabil de la", "de la data de", "data inceperii", "pe perioada", "pe o perioada"]
        case "Facturi", "Proforme", "Chitanțe", "Avize", "Bonuri", "NIR":
            anchors = ["data emiterii", "data emitere", "data facturii", "data factura", "data documentului", "din data", "data:", "data "]
        case "Bancă":
            anchors = ["perioada", "de la", "data extras", "data:"]
        default:
            anchors = ["data:", "din data", "data "]
        }

        let ns = folded as NSString
        for anchor in anchors {
            var searchStart = 0
            while searchStart < ns.length {
                let r = ns.range(of: anchor, options: [], range: NSRange(location: searchStart, length: ns.length - searchStart))
                if r.location == NSNotFound { break }
                let end = r.location + r.length
                if let hit = found.first(where: { $0.offset >= end && $0.offset - end <= 60 }) {
                    return hit.date
                }
                searchStart = end
            }
        }
        return (found.first(where: { $0.offset < 3000 }) ?? found.first)?.date
    }
}

// MARK: - Nume

enum Names {
    private static let locale = Locale(identifier: "ro_RO")

    /// „S.C. EXEMPLU DISTRIBUTIE S.R.L., CUI RO1234” → „Exemplu Distributie”
    static func clean(_ raw: String) -> String? {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let cutMarkers = "(?i)[\\s,;]*(C\\.?U\\.?I\\b|C\\.?I\\.?F\\b|Cod fiscal|Cod de identificare|Nr\\.? ?Reg|Reg\\.? ?Com|J ?[0-9]{1,2} ?/|IBAN|Banca|Adresa|Sediu|Cump[ăa]r[ăa]tor|Client\\b|Beneficiar|Furnizor)"
        if let r = s.range(of: cutMarkers, options: .regularExpression) {
            s = String(s[..<r.lowerBound])
        }
        s = s.replacingOccurrences(of: "(?i)^S\\.?\\s?C\\.?\\s+", with: "", options: .regularExpression)
        for _ in 0..<2 {
            s = s.replacingOccurrences(of: "(?i)[\\s,]+(S\\.?R\\.?L\\.?(-D)?|S\\.A\\.?|SA|P\\.?F\\.?A\\.?|I\\.?I\\.?|I\\.?F\\.?)\\.?\\s*$", with: "", options: .regularExpression)
        }
        s = safeFileName(s)
        s = s.trimmingCharacters(in: CharacterSet(charactersIn: " .,;:-–\"'"))
        let letters = s.filter { $0.isLetter }.count
        let digits = s.filter { $0.isNumber }.count
        guard letters >= 2, digits <= letters else { return nil }
        if s.count > 40 {
            let cut = s.prefix(40)
            if let space = cut.lastIndex(of: " ") {
                s = String(cut[..<space])
            } else {
                s = String(cut)
            }
        }
        let upper = s.filter { $0.isUppercase }.count
        if letters > 0, Double(upper) / Double(letters) > 0.7 {
            s = s.split(separator: " ").map { word -> String in
                let w = String(word)
                if w.count <= 3 || w.contains(where: { $0.isNumber }) || w.contains(".") { return w }
                return w.lowercased(with: locale).capitalized(with: locale)
            }.joined(separator: " ")
        }
        return s.isEmpty ? nil : s
    }

    /// Scoate caracterele care nu au voie într-un nume de fișier pe Mac.
    static func safeFileName(_ s: String) -> String {
        var t = s.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
        t = t.replacingOccurrences(of: "[\\p{Cc}]", with: " ", options: .regularExpression)
        t = t.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return t.trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - Firmele găsite în documente

struct Party: Hashable {
    enum Role: String, Codable {
        case supplier, customer, unknown
    }

    /// Doar cifrele CUI-ului (fără RO).
    let cui: String
    let name: String
    let role: Role
}

enum PartyExtractor {
    /// Ce fișiere se citesc pentru a găsi firme (fără poze, ca să nu facem OCR la orice imagine).
    static let documentExtensions: Set<String> = ["pdf", "xml", "zip", "doc", "docx", "xls", "xlsx", "odt", "ods", "rtf", "txt"]

    private static let supplierLabels = ["furnizor", "vanzator", "prestator", "emitent", "executant", "locator", "comodant"]
    private static let customerLabels = ["cumparator", "client", "beneficiar", "achizitor", "locatar", "comodatar"]

    private static let labeledCUI = try? NSRegularExpression(
        pattern: "(?i)(?:\\bC\\.?\\s?U\\.?\\s?I\\.?|\\bC\\.?\\s?I\\.?\\s?F\\.?|cod\\s+fiscal|cod\\s+de\\s+identificare\\s+fiscal[aă]|cod\\s+unic\\s+de\\s+[iî]nregistrare)\\s*(?:/\\s*(?:CUI|CIF))?\\s*[:.\\-]?\\s*(?:RO\\s?)?([0-9]{2,10})(?![0-9])"
    )
    private static let prefixedCUI = try? NSRegularExpression(pattern: "(?<![A-Za-z0-9])RO\\s?([0-9]{4,10})(?![0-9])")

    /// Cifra de control a CUI-ului românesc (cheia 753217532).
    static func isValidCUI(_ digits: String) -> Bool {
        guard (2...10).contains(digits.count) else { return false }
        let numbers = digits.compactMap { $0.wholeNumberValue }
        guard numbers.count == digits.count, let control = numbers.last else { return false }
        var body = Array(numbers.dropLast())
        while body.count < 9 { body.insert(0, at: 0) }
        let key = [7, 5, 3, 2, 1, 7, 5, 3, 2]
        var sum = 0
        for index in 0..<9 {
            sum += body[index] * key[index]
        }
        var check = (sum * 10) % 11
        if check == 10 { check = 0 }
        return check == control
    }

    private static func cuis(in line: String) -> [(cui: String, location: Int)] {
        let ns = line as NSString
        let range = NSRange(location: 0, length: ns.length)
        var found: [(String, Int)] = []
        for regex in [labeledCUI, prefixedCUI].compactMap({ $0 }) {
            for match in regex.matches(in: line, range: range) where match.numberOfRanges > 1 {
                let digits = ns.substring(with: match.range(at: 1))
                if isValidCUI(digits), !found.contains(where: { $0.0 == digits }) {
                    found.append((digits, match.range.location))
                }
            }
        }
        return found.sorted { $0.1 < $1.1 }.map { (cui: $0.0, location: $0.1) }
    }

    private static func hasLegalForm(_ line: String) -> Bool {
        line.range(of: "(?i)(\\bS\\.?R\\.?L\\b|\\bS\\.A\\.|\\bP\\.?F\\.?A\\b|\\bSRL\\b)", options: .regularExpression) != nil
    }

    static func parties(text: String, raw: String?) -> [Party] {
        if let raw, let invoice = EFactura.parties(raw), !invoice.isEmpty {
            return invoice
        }
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .prefix(250)

        var result: [Party] = []
        var role: Party.Role = .unknown
        var lastName: String?
        var expectName = false

        for line in lines {
            let folded = TextNormalizer.fold(line)
            var label: String?
            if let found = supplierLabels.first(where: { folded.hasPrefix($0) }) {
                role = .supplier
                label = found
            } else if let found = customerLabels.first(where: { folded.hasPrefix($0) }) {
                role = .customer
                label = found
            }

            if let label {
                let rest = String(line.dropFirst(label.count).drop(while: { $0.isLetter }))
                    .trimmingCharacters(in: CharacterSet(charactersIn: " :-–\t"))
                lastName = Names.clean(rest)
                expectName = lastName == nil
            } else if expectName, line.filter({ $0.isLetter }).count >= 3, let name = Names.clean(line) {
                lastName = name
                expectName = false
            } else if hasLegalForm(line), let name = Names.clean(line) {
                lastName = name
            }

            for hit in cuis(in: line) {
                var name = lastName
                if name == nil {
                    let before = (line as NSString).substring(to: hit.location)
                    name = Names.clean(before)
                }
                result.append(Party(cui: hit.cui, name: name ?? "Firma cu CUI \(hit.cui)", role: role))
            }
        }

        var seen = Set<String>()
        return result.filter { seen.insert($0.cui).inserted }
    }
}

extension EFactura {
    /// Furnizorul și clientul din e-Factura, cu CUI-urile lor.
    static func parties(_ raw: String) -> [Party]? {
        guard raw.contains("AccountingSupplierParty"),
              raw.contains("Invoice") || raw.contains("CreditNote") else { return nil }
        var result: [Party] = []
        for (tag, role) in [("AccountingSupplierParty", Party.Role.supplier), ("AccountingCustomerParty", Party.Role.customer)] {
            guard let section = blockPublic(raw, tag: tag) else { continue }
            let name = valuePublic(section, tag: "RegistrationName") ?? valuePublic(section, tag: "Name") ?? ""
            let ids = [valuePublic(section, tag: "CompanyID"), valuePublic(section, tag: "EndpointID")].compactMap { $0 }
            for id in ids {
                let digits = id.filter { $0.isNumber }
                if PartyExtractor.isValidCUI(digits) {
                    result.append(Party(cui: digits, name: Names.clean(name) ?? "Firma cu CUI \(digits)", role: role))
                    break
                }
            }
        }
        return result
    }
}
