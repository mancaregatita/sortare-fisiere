import Foundation
import AppKit
import PDFKit
import Vision
import ImageIO
import CoreGraphics

struct ExtractedText {
    var text: String = ""
    var method: String = ""
    /// XML-ul brut (fișiere .xml și XML-urile din arhive), pentru citirea e-Factura.
    var raw: String? = nil
}

/// Citește textul din fișiere: PDF (text sau OCR), poze (OCR), Word/Excel/PowerPoint/OpenOffice,
/// RTF/DOC, fișiere text/XML și XML-urile din arhive .zip (ex. e-Factura descărcată din SPV).
final class ContentExtractor {
    let settings: AppSettings

    private static let maxChars = 300_000
    private static let imageExtensions: Set<String> = ["jpg", "jpeg", "png", "heic", "heif", "tif", "tiff", "bmp", "gif", "webp"]
    private static let plainExtensions: Set<String> = ["txt", "csv", "tsv", "md", "json", "log", "eml", "xml", "html", "htm", "svg"]

    init(settings: AppSettings) {
        self.settings = settings
    }

    func extract(_ url: URL) -> ExtractedText {
        let ext = url.pathExtension.lowercased()
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0

        if ext == "pdf" { return pdf(url) }
        if Self.imageExtensions.contains(ext) { return image(url, size: size) }
        if Self.plainExtensions.contains(ext) { return plain(url, ext: ext) }

        switch ext {
        case "docx", "docm", "dotx":
            return office(url, entries: ["word/document.xml", "word/header*.xml", "word/footer*.xml"], label: "document Word")
        case "xlsx", "xlsm":
            return office(url, entries: ["xl/sharedStrings.xml", "xl/worksheets/sheet*.xml"], label: "tabel Excel")
        case "pptx":
            return office(url, entries: ["ppt/slides/slide*.xml"], label: "prezentare PowerPoint")
        case "odt", "ods", "odp":
            return office(url, entries: ["content.xml"], label: "document OpenOffice")
        case "doc":
            return richText(url, type: .docFormat)
        case "rtf":
            return richText(url, type: .rtf)
        case "zip":
            return archive(url, size: size)
        default:
            return ExtractedText(text: "", method: "tip de fișier fără citire de conținut")
        }
    }

    // MARK: PDF

    private func pdf(_ url: URL) -> ExtractedText {
        guard settings.readPDFText else {
            return ExtractedText(text: "", method: "citirea PDF-urilor e oprită în Setări")
        }
        let pages = max(1, settings.maxPages)
        var text = ""
        if let document = PDFDocument(url: url) {
            if document.isLocked {
                return ExtractedText(text: "", method: "PDF protejat cu parolă")
            }
            let count = min(document.pageCount, pages)
            for index in 0..<count {
                if let pageText = document.page(at: index)?.string {
                    text += pageText + "\n"
                }
            }
        }
        if text.trimmingCharacters(in: .whitespacesAndNewlines).count >= 20 {
            return ExtractedText(text: Self.clip(text), method: "text din PDF")
        }
        guard settings.ocrScannedPDFs else {
            return ExtractedText(text: text, method: "PDF fără text (OCR oprit în Setări)")
        }
        guard let cgDocument = CGPDFDocument(url as CFURL) else {
            return ExtractedText(text: text, method: "PDF necitit")
        }
        var recognized = ""
        let count = min(cgDocument.numberOfPages, pages)
        if count >= 1 {
            for number in 1...count {
                autoreleasepool {
                    if let page = cgDocument.page(at: number), let image = Self.render(page) {
                        recognized += OCR.recognize(image) + "\n"
                    }
                }
            }
        }
        return ExtractedText(text: Self.clip(text + "\n" + recognized), method: "OCR pe PDF scanat")
    }

    private static func render(_ page: CGPDFPage) -> CGImage? {
        let box = page.getBoxRect(.cropBox)
        guard box.width > 0, box.height > 0 else { return nil }
        let scale = min(3.0, 2200.0 / max(box.width, box.height))
        let width = Int(box.width * scale)
        let height = Int(box.height * scale)
        guard width > 0, height > 0,
              let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else { return nil }
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.scaleBy(x: scale, y: scale)
        context.translateBy(x: -box.origin.x, y: -box.origin.y)
        context.drawPDFPage(page)
        return context.makeImage()
    }

    // MARK: Imagini

    private func image(_ url: URL, size: Int) -> ExtractedText {
        guard settings.ocrImages else {
            return ExtractedText(text: "", method: "OCR pe imagini e oprit în Setări")
        }
        guard size <= 60_000_000 else {
            return ExtractedText(text: "", method: "imagine prea mare pentru OCR")
        }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return ExtractedText(text: "", method: "imagine necitită")
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 2800
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return ExtractedText(text: "", method: "imagine necitită")
        }
        if cgImage.width < 200 && cgImage.height < 200 {
            return ExtractedText(text: "", method: "imagine prea mică pentru OCR")
        }
        return ExtractedText(text: Self.clip(OCR.recognize(cgImage)), method: "OCR pe imagine")
    }

    // MARK: Office / text

    private func office(_ url: URL, entries: [String], label: String) -> ExtractedText {
        guard settings.readOfficeFiles else {
            return ExtractedText(text: "", method: "citirea documentelor Office e oprită în Setări")
        }
        guard let xml = Self.unzip(url, entries) else {
            return ExtractedText(text: "", method: "\(label) — nu s-a putut citi")
        }
        return ExtractedText(text: Self.clip(Self.officeXMLToText(xml)), method: label)
    }

    private func richText(_ url: URL, type: NSAttributedString.DocumentType) -> ExtractedText {
        guard settings.readOfficeFiles else {
            return ExtractedText(text: "", method: "citirea documentelor Office e oprită în Setări")
        }
        do {
            let attributed = try NSAttributedString(url: url, options: [.documentType: type], documentAttributes: nil)
            return ExtractedText(text: Self.clip(attributed.string), method: "document text")
        } catch {
            return ExtractedText(text: "", method: "document necitit")
        }
    }

    private func plain(_ url: URL, ext: String) -> ExtractedText {
        guard let handle = try? FileHandle(forReadingFrom: url) else {
            return ExtractedText(text: "", method: "fișier necitit")
        }
        defer { try? handle.close() }
        let data = (try? handle.read(upToCount: 4_000_000)) ?? Data()
        var text = String(decoding: data, as: UTF8.self)
        let raw: String? = ext == "xml" ? text : nil
        if ["xml", "html", "htm", "svg"].contains(ext) {
            text = Self.xmlToText(text)
        }
        return ExtractedText(text: Self.clip(text), method: "text", raw: raw)
    }

    private func archive(_ url: URL, size: Int) -> ExtractedText {
        guard settings.readArchives else {
            return ExtractedText(text: "", method: "citirea arhivelor e oprită în Setări")
        }
        guard size <= 30_000_000 else {
            return ExtractedText(text: "", method: "arhivă prea mare pentru citire")
        }
        guard let text = Self.unzip(url, ["*.xml", "*.txt", "*.csv", "*.json"]) else {
            return ExtractedText(text: "", method: "arhivă fără fișiere text")
        }
        return ExtractedText(text: Self.clip(Self.xmlToText(text)), method: "arhivă (XML/text din interior)", raw: text)
    }

    // MARK: Utilitare

    /// Extrage din arhivă fișierele cerute, folosind /usr/bin/unzip (inclus în macOS).
    static func unzip(_ url: URL, _ entries: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-p", url.path] + entries
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        process.standardInput = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return nil
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard !data.isEmpty else { return nil }
        return String(decoding: data.prefix(4_000_000), as: UTF8.self)
    }

    static func officeXMLToText(_ xml: String) -> String {
        var s = xml
        let breaks = ["</w:p>", "<w:tab/>", "<w:br/>", "</a:p>", "</text:p>", "</text:h>", "<text:tab/>", "</si>", "</c>", "</table:table-cell>"]
        for tag in breaks {
            s = s.replacingOccurrences(of: tag, with: " ")
        }
        s = s.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        return decodeEntities(s)
    }

    static func xmlToText(_ xml: String) -> String {
        decodeEntities(xml.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression))
    }

    static func decodeEntities(_ s: String) -> String {
        var t = s
        let entities: [(String, String)] = [
            ("&lt;", "<"), ("&gt;", ">"), ("&quot;", "\""), ("&apos;", "'"),
            ("&#39;", "'"), ("&nbsp;", " "), ("&#160;", " "), ("&amp;", "&")
        ]
        for (entity, value) in entities {
            t = t.replacingOccurrences(of: entity, with: value)
        }
        return t
    }

    static func clip(_ s: String) -> String {
        s.count > maxChars ? String(s.prefix(maxChars)) : s
    }
}

enum OCR {
    static func recognize(_ image: CGImage) -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.automaticallyDetectsLanguage = true
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return ""
        }
        guard let results = request.results else { return "" }
        return results
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n")
    }
}
