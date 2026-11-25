import Foundation

/// Traduce numele fișierelor redenumite de versiunile vechi, fără să le deschidă (nu descarcă nimic din iCloud):
/// - „Factură 1234 – Metro – 2026-11-03.pdf”        → „Invoice 1234 – Metro – 2026-11-03.pdf”
/// - „2026-11-03 – Firma Mea – Factură – Metro.pdf” → „Invoice – Metro – 2026-11-03.pdf”
enum LegacyNames {
    struct Translation: Equatable {
        let name: String
        /// Anul din dată (pentru Firme/<firmă>/<an>/…).
        let year: String?
    }

    private static let separator = " – "

    private static func isISODate(_ s: String) -> Bool {
        s.range(of: "^[0-9]{4}-[0-9]{2}-[0-9]{2}$", options: .regularExpression) != nil
    }

    /// Tipurile, cu numele vechi și cel nou, cele mai lungi primele („Act adițional” înaintea „Act”).
    private static let typesByLength: [(label: String, type: DocType)] = {
        var list: [(label: String, type: DocType)] = []
        for type in DocTypes.all {
            list.append((label: type.legacyName, type: type))
            list.append((label: type.name, type: type))
        }
        return list.sorted { $0.label.count > $1.label.count }
    }()

    /// „Factură 1234” → (Invoice, „1234”); „Factură” → (Invoice, nil).
    private static func typePrefix(_ part: String) -> (DocType, String?)? {
        let folded = TextNormalizer.fold(part)
        for (label, type) in typesByLength {
            let foldedLabel = TextNormalizer.fold(label)
            if folded == foldedLabel { return (type, nil) }
            if folded.hasPrefix(foldedLabel + " ") {
                let rest = String(part.dropFirst(label.count)).trimmingCharacters(in: .whitespaces)
                return (type, rest.isEmpty ? nil : rest)
            }
        }
        return nil
    }

    private static func exactType(_ part: String) -> DocType? {
        let folded = TextNormalizer.fold(part)
        return typesByLength.first { TextNormalizer.fold($0.label) == folded }?.type
    }

    static func translate(_ fileName: String) -> Translation? {
        let ext = (fileName as NSString).pathExtension
        let base = (fileName as NSString).deletingPathExtension
        let parts = base.components(separatedBy: separator).map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count >= 2 else { return nil }

        var type: DocType?
        var number: String?
        var partner: String?
        var date: String?

        if isISODate(parts[0]) {
            // Formatul vechi: Dată – Firmă – Tip – Partener
            for index in 1..<parts.count {
                if let found = exactType(parts[index]) {
                    type = found
                    let rest = parts[(index + 1)...].joined(separator: separator)
                    partner = rest.isEmpty ? nil : rest
                    date = parts[0]
                    break
                }
            }
        } else if let match = typePrefix(parts[0]) {
            // Formatul de după 19 noiembrie: Tip Număr – Partener – Dată
            type = match.0
            number = match.1
            var middle = Array(parts.dropFirst())
            if let last = middle.last, isISODate(last) {
                date = last
                middle.removeLast()
            }
            let rest = middle.joined(separator: separator)
            partner = rest.isEmpty ? nil : rest
        }

        guard let type else { return nil }
        var first = type.name
        if let number { first += " " + number }
        var pieces = [first]
        if let partner { pieces.append(partner) }
        if let date { pieces.append(date) }
        let newBase = Names.withoutDiacritics(Names.safeFileName(pieces.joined(separator: separator)))
        let name = ext.isEmpty ? newBase : newBase + "." + ext
        return Translation(name: name, year: date.map { String($0.prefix(4)) })
    }
}
