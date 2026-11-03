import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Răspunsul AI-ului Apple: tip document, partener, dată.
struct AIGuess {
    var type: String
    var partner: String
    var date: String
}

/// AI-ul Apple care rulează local pe Mac (macOS 26, Apple Intelligence pornit).
/// Se folosește doar ca rezervă, când regulile nu au recunoscut tipul documentului.
enum AppleAI {
    static var statusText: String {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                return "Disponibil pe acest Mac."
            case .unavailable(.deviceNotEligible):
                return "Mac-ul acesta nu suportă Apple Intelligence."
            case .unavailable(.appleIntelligenceNotEnabled):
                return "Apple Intelligence e oprit (System Settings → Apple Intelligence & Siri)."
            case .unavailable(.modelNotReady):
                return "Modelul Apple încă se descarcă."
            default:
                return "Nu este disponibil acum."
            }
        }
        return "Necesită macOS 26 sau mai nou."
        #else
        return "Necesită Xcode 26 și macOS 26."
        #endif
    }

    static func guess(text: String) -> AIGuess? {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            return AppleAIModern.guess(text: text)
        }
        #endif
        return nil
    }
}

#if canImport(FoundationModels)
@available(macOS 26.0, *)
@Generable
struct DocumentGuess {
    @Guide(description: "The document type", .anyOf(["Factură", "Proformă", "Chitanță", "Bon fiscal", "Aviz", "NIR", "Act adițional", "Contract", "Extras de cont", "Ordin de plată", "Ofertă", "Comandă", "Somație", "Decizie", "Proces-verbal", "Notificare", "Declarație", "Certificat", "Autorizație", "Adeverință", "Stat de plată", "Cerere", "Altul"]))
    let type: String

    @Guide(description: "Name of the other company or person on the document (supplier, client or contract party), without legal form like SRL or SA. Empty if unknown.")
    let partner: String

    @Guide(description: "Main date of the document as YYYY-MM-DD. For contracts use the start date. Empty if unknown.")
    let date: String
}

@available(macOS 26.0, *)
enum AppleAIModern {
    final class Box: @unchecked Sendable {
        var value: AIGuess?
    }

    static func guess(text: String) -> AIGuess? {
        guard case .available = SystemLanguageModel.default.availability else { return nil }
        let snippet = String(text.prefix(2500))
        let prompt = """
        You classify Romanian business documents. Read the document text and fill in the type, \
        the partner (the other party, not the company that received or issued it) and the main date.

        Document text:
        \(snippet)
        """
        let box = Box()
        let semaphore = DispatchSemaphore(value: 0)
        Task.detached {
            defer { semaphore.signal() }
            do {
                let session = LanguageModelSession()
                let response = try await session.respond(to: prompt, generating: DocumentGuess.self)
                let content = response.content
                box.value = AIGuess(type: content.type, partner: content.partner, date: content.date)
            } catch {
                box.value = nil
            }
        }
        _ = semaphore.wait(timeout: .now() + 25)
        return box.value
    }
}
#endif
