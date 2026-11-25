import Foundation
import AppKit
import UserNotifications

/// Notificarea „Ai instalat X. Ștergi installerul?”, cu butoanele Șterge / Păstrează.
/// Dacă notificările nu sunt permise, întrebarea apare ca fereastră de dialog.
final class InstallerNotifier: NSObject, UNUserNotificationCenterDelegate {
    static let shared = InstallerNotifier()

    static let categoryID = "SORTATOR_INSTALLER"
    static let deleteAction = "SORTATOR_DELETE"
    static let keepAction = "SORTATOR_KEEP"
    static let pathKey = "path"

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
        if let path = info[Self.pathKey] as? String {
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
