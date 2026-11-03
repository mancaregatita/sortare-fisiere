import Foundation

/// Regulile cu care pornește aplicația. Se pot modifica oricând din tab-ul Reguli.
enum DefaultRules {
    /// Tipurile de fișiere în care se caută firmele (documente, facturi, e-Factura, poze/scanări).
    static let documentExtensions = "pdf, xml, zip, doc, docx, xls, xlsx, odt, rtf, txt, jpg, jpeg, png, heic"

    static let typeGroups: [(name: String, extensions: String)] = [
        ("Imagini", "jpg, jpeg, png, gif, heic, heif, webp, svg, tif, tiff, bmp, raw, cr2, nef, arw, dng"),
        ("Video", "mp4, mov, m4v, avi, mkv, webm, wmv, mpg, mpeg, 3gp"),
        ("Audio", "mp3, wav, m4a, aac, flac, ogg, aiff, aif, opus, wma"),
        ("Documente", "pdf, doc, docx, odt, rtf, txt, pages, md, epub"),
        ("Tabele", "xls, xlsx, xlsm, csv, tsv, ods, numbers"),
        ("Prezentări", "ppt, pptx, odp, key"),
        ("XML", "xml, json"),
        ("Arhive", "zip, rar, 7z, tar, gz, tgz, bz2, xz"),
        ("Instalare", "dmg, pkg, iso, exe, msi"),
        ("Design", "psd, ai, eps, sketch, fig, indd, afdesign, afphoto"),
        ("Fonturi", "ttf, otf, woff, woff2")
    ]

    /// Firmele nu sunt scrise în cod: le găsește aplicația în documente (tab-ul Firme)
    /// sau le adaugi tu. Regulile inițiale sunt doar cele pe tipuri de fișiere.
    static var companies: [CompanyProfile] { [] }

    static var all: [SortRule] {
        typeGroups.map { type($0.name, $0.extensions) }
    }

    /// Unde se inserează regula unei firme noi: după celelalte reguli de firme, înaintea celor pe tipuri.
    static func insertionIndexForCompanyRule(in rules: [SortRule]) -> Int {
        if let lastCompany = rules.lastIndex(where: { $0.destination.hasPrefix("Firme/") }) {
            return lastCompany + 1
        }
        return 0
    }

    static func company(_ name: String, _ keywords: String) -> SortRule {
        SortRule(
            name: name,
            matchMode: .all,
            conditions: [
                RuleCondition(field: .ext, keywords: documentExtensions),
                RuleCondition(field: .nameOrContent, keywords: keywords)
            ],
            destination: "Firme/\(name)/{tipdoc}",
            rename: true
        )
    }

    static func type(_ name: String, _ extensions: String) -> SortRule {
        SortRule(
            name: name,
            matchMode: .all,
            conditions: [RuleCondition(field: .ext, keywords: extensions)],
            destination: name,
            rename: name == "Documente"
        )
    }

    /// Folosit pentru {tip} în destinație.
    static func category(forExtension ext: String) -> String {
        let e = ext.lowercased()
        for group in typeGroups {
            let list = group.extensions.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            if list.contains(e) { return group.name }
        }
        return "Altele"
    }
}
