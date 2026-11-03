import Foundation
import Sparkle

/// Actualizări automate (Sparkle): verifică la 6 ore, descarcă în fundal și instalează imediat ce e gata.
final class UpdaterDelegate: NSObject, SPUUpdaterDelegate {
    /// O aplicație din bara de meniu nu se închide aproape niciodată, așa că instalăm imediat,
    /// în loc să așteptăm închiderea (aplicația repornește singură în câteva secunde).
    func updater(_ updater: SPUUpdater,
                 willInstallUpdateOnQuit item: SUAppcastItem,
                 immediateInstallationBlock immediateInstallHandler: @escaping () -> Void) -> Bool {
        immediateInstallHandler()
        return true
    }
}

@MainActor
final class Updates {
    static let shared = Updates()

    private let delegate = UpdaterDelegate()
    let controller: SPUStandardUpdaterController

    private init() {
        controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: delegate, userDriverDelegate: nil)
    }

    func checkNow() {
        controller.checkForUpdates(nil)
    }

    var versionText: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "Versiunea \(version) (\(build))"
    }
}
