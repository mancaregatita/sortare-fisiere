import Foundation

/// Regulile cu care pornește aplicația. Se pot modifica oricând din tab-ul Reguli.
enum DefaultRules {
    /// Tipurile de fișiere în care se caută firmele (documente, facturi, e-Factura, poze/scanări).
    static let documentExtensions = "pdf, xml, zip, doc, docx, xls, xlsx, odt, rtf, txt, jpg, jpeg, png, heic"

    /// Ordinea contează: prima grupă care conține extensia câștigă.
    static let typeGroups: [(name: String, extensions: String)] = [
        ("Images", "jpg, jpeg, png, gif, heic, heif, webp, svg, tif, tiff, bmp, raw, cr2, nef, arw, dng"),
        ("Videos", "mp4, mov, m4v, avi, mkv, webm, wmv, mpg, mpeg, 3gp"),
        ("Audio", "mp3, wav, m4a, aac, flac, ogg, aiff, aif, opus, wma"),
        ("Documents", "pdf, doc, docx, odt, rtf, rtfd, txt, md, epub, pages, xls, xlsx, xlsm, csv, tsv, ods, numbers, ppt, pptx, odp, key, xml, json"),
        ("Archives", "zip, rar, 7z, tar, gz, tgz, bz2, xz"),
        ("Installers", "dmg, pkg, mpkg, iso, exe, msi"),
        ("Ableton Projects", "als, alp"),
        ("Other", "psd, ai, eps, sketch, fig, indd, afdesign, afphoto, ttf, otf, woff, woff2")
    ]

    /// Numele regulilor inițiale din versiunile vechi (în română), înlocuite la actualizare.
    static let legacyTypeRuleNames: Set<String> = [
        "Imagini", "Video", "Audio", "Documente", "Tabele", "Prezentări", "XML", "Arhive", "Instalare", "Design", "Fonturi"
    ]

    /// Folderele vechi pe tipuri → folderele noi (pentru „Mută folderele vechi în structura nouă”).
    static let legacyTypeFolders: [String: String] = [
        "Imagini": "Images", "Video": "Videos", "Documente": "Documents", "Tabele": "Documents",
        "Prezentări": "Documents", "XML": "Documents", "Arhive": "Archives", "Instalare": "Installers",
        "Design": "Other", "Fonturi": "Other"
    ]

    static var typeRules: [SortRule] {
        typeGroups.map { type($0.name, $0.extensions) }
    }

    /// Firmele nu sunt scrise în cod: le găsește aplicația în documente (tab-ul Firme)
    /// sau le adaugi tu. Regulile inițiale sunt doar cele pe tipuri de fișiere.
    static var companies: [CompanyProfile] { [] }

    static var all: [SortRule] {
        typeRules
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
            destination: "Firme/\(name)/{an}/{tipdoc}",
            rename: true
        )
    }

    static func type(_ name: String, _ extensions: String) -> SortRule {
        SortRule(
            name: name,
            matchMode: .all,
            conditions: [RuleCondition(field: .ext, keywords: extensions)],
            destination: name,
            rename: name == "Documents"
        )
    }

    /// Folosit pentru {tip} în destinație.
    static func category(forExtension ext: String) -> String {
        let e = ext.lowercased()
        for group in typeGroups {
            let list = group.extensions.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            if list.contains(e) { return group.name }
        }
        return "Other"
    }
}
