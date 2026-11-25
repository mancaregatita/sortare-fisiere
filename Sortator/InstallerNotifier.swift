import Foundation
import AppKit
import UserNotifications

/// Notificările Sortator: „Ai instalat X. Ștergi installerul?” (cu butoanele Șterge / Păstrează),
/// rezumatul de seară și anunțurile de curățenie (click = deschide tab-ul potrivit).
/// Dacă notificările nu sunt permise, întrebarea despre installer apare ca fereastră de dialog.
final class InstallerNotifier: NSObject, UNUserNotificationCenterDelegate {
    static let shared = InstallerNotifier()

    static let categoryID = "SORTATOR_INSTALLER"
    static let deleteAction = "SORTATOR_DELETE"
    static let keepAction = "SORTATOR_KEEP"
    static let pathKey = "path"
    static let tabKey = "tab"

    private let center = UNUserNotificationCenter.current()

    func setUp() {
        center.delegate = self
        let delete = UNNotificationAction(identifier: Self.deleteAction, title: "Șterge", options: [.destructive])
        let keep = UNNotificationAction(identifier: Self.keepAction, title: "Păstrează", options: [])
        let category = UNNotificationCategory(identifier: Self.categoryID, actions: [delete, keep], intentIdentifiers: [], options: [])
        center.setNotificationCategories([category])
    }

    /// Trimite notificările; `fallback` primește installerele pentru care notificările nu sunt permise.
    func notify(_ installers: [OpenedInstaller], fallback: @escaping @Sendable ([OpenedInstaller]) -> Void) {
        guard !installers.isEmpty else { return }
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else {
                fallback(installers)
                return
            }
            for installer in installers {
                let content = UNMutableNotificationContent()
                if let app = installer.installedApp {
                    content.title = "Ai instalat \(app)"
                } else {
                    content.title = "Ai deschis \(installer.url.lastPathComponent)"
                }
                content.body = "Ștergi installerul „\(installer.url.lastPathComponent)”? Se mută la coș."
                content.categoryIdentifier = Self.categoryID
                content.userInfo = [Self.pathKey: installer.url.path]
                let request = UNNotificationRequest(identifier: "installer-" + installer.url.path, content: content, trigger: nil)
                self.center.add(request, withCompletionHandler: nil)
            }
        }
    }

    /// O notificare simplă; click pe ea deschide tab-ul dat. `granted` spune dacă a putut fi trimisă.
    func notifyInfo(id: String, title: String, body: String, tab: MainTab, granted: (@Sendable (Bool) -> Void)? = nil) {
        center.requestAuthorization(options: [.alert, .sound]) { ok, _ in
            granted?(ok)
            guard ok else { return }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.userInfo = [Self.tabKey: Self.tabName(tab)]
            let request = UNNotificationRequest(identifier: id, content: content, trigger: nil)
            self.center.add(request, withCompletionHandler: nil)
        }
    }

    private static func tabName(_ tab: MainTab) -> String {
        switch tab {
        case .folders: return "folders"
        case .rules: return "rules"
        case .companies: return "companies"
        case .cleanup: return "cleanup"
        case .history: return "history"
        case .settings: return "settings"
        }
    }

    private static func tab(named name: String) -> MainTab {
        switch name {
        case "folders": return .folders
        case "rules": return .rules
        case "companies": return .companies
        case "history": return .history
        case "settings": return .settings
        default: return .cleanup
        }
    }

    // Notificările apar și când aplicația e în prim-plan.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let info = response.notification.request.content.userInfo
        let action = response.actionIdentifier
        if let tabName = info[Self.tabKey] as? String, action != UNNotificationDismissActionIdentifier {
            let tab = Self.tab(named: tabName)
            Task { @MainActor in
                AppState.shared.showMainWindow(tab: tab)
                if tab == .folders { AppState.shared.showProposals = true }
            }
        } else if let path = info[Self.pathKey] as? String {
            let url = URL(fileURLWithPath: path)
            Task { @MainActor in
                switch action {
                case InstallerNotifier.deleteAction:
                    AppState.shared.moveToTrash([url])
                case InstallerNotifier.keepAction, UNNotificationDismissActionIdentifier:
                    break
                default:
                    AppState.shared.showMainWindow(tab: .cleanup)
                }
            }
        }
        completionHandler()
    }
}
