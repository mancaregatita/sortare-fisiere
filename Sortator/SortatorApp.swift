import SwiftUI
import AppKit

@main
struct SortatorApp: App {
    @StateObject private var state = AppState.shared

    var body: some Scene {
        MenuBarExtra {
            MenuContent()
                .environmentObject(state)
        } label: {
            Image(systemName: state.config.settings.paused ? "pause.circle" : "tray.and.arrow.down")
        }
        .menuBarExtraStyle(.menu)
    }
}

struct MenuContent: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        Text(headline)
        Text(shortStatus)
        Divider()
        if !state.history.isEmpty {
            Text("Ultimele mutări")
            ForEach(Array(state.history.prefix(5))) { entry in
                Button(menuTitle(entry)) {
                    state.reveal(entry)
                }
            }
            Divider()
        }
        if !state.companySuggestions.isEmpty {
            Button("Firme de confirmat: \(state.companySuggestions.count)…") {
                state.showMainWindow(tab: .companies)
            }
        }
        if !state.duplicateGroups.isEmpty {
            Button("Dubluri găsite: \(state.duplicateGroups.count)…") {
                state.showMainWindow(tab: .cleanup)
            }
        }
        if !state.oldInstallers.isEmpty {
            Button("Installere vechi: \(state.oldInstallers.count)…") {
                state.showMainWindow(tab: .cleanup)
            }
        }
        if !state.companySuggestions.isEmpty || !state.duplicateGroups.isEmpty || !state.oldInstallers.isEmpty {
            Divider()
        }
        Button(state.config.settings.paused ? "Repornește sortarea" : "Pune pe pauză") {
            state.config.settings.paused.toggle()
        }
        Button("Deschide Sortator…") {
            state.showMainWindow()
        }
        .keyboardShortcut(",")
        Button("Istoric mutări…") {
            state.showMainWindow(tab: .history)
        }
        Divider()
        Button("Ieșire din Sortator") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }

    private var headline: String {
        if state.config.settings.paused { return "Sortator e în pauză" }
        let active = state.config.folders.filter { $0.enabled && !state.isFolderExcluded($0) }.count
        return "Sortator urmărește \(RO.count(active, "folder", "foldere"))"
    }

    private var shortStatus: String {
        let s = state.statusMessage
        return s.count > 70 ? String(s.prefix(67)) + "…" : s
    }

    private func menuTitle(_ entry: HistoryEntry) -> String {
        let folder = URL(fileURLWithPath: entry.toPath).deletingLastPathComponent().lastPathComponent
        var name = entry.undone ? entry.fileName : URL(fileURLWithPath: entry.toPath).lastPathComponent
        if name.count > 40 {
            name = String(name.prefix(37)) + "…"
        }
        return entry.undone ? "↩︎ \(name)" : "\(name) → \(folder)"
    }
}
