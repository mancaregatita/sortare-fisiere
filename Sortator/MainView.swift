import SwiftUI

struct MainView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $state.selectedTab) {
                FoldersView()
                    .tabItem { Label("Foldere", systemImage: "folder") }
                    .tag(MainTab.folders)
                RulesView()
                    .tabItem { Label("Reguli", systemImage: "list.bullet.rectangle") }
                    .tag(MainTab.rules)
                CompaniesView()
                    .tabItem { Label("Firme", systemImage: "building.2") }
                    .tag(MainTab.companies)
                CleanupView()
                    .tabItem { Label("Curățenie", systemImage: "sparkles") }
                    .tag(MainTab.cleanup)
                HistoryView()
                    .tabItem { Label("Istoric", systemImage: "clock.arrow.circlepath") }
                    .tag(MainTab.history)
                SettingsView()
                    .tabItem { Label("Setări", systemImage: "gearshape") }
                    .tag(MainTab.settings)
            }
            .padding(.top, 8)
            Divider()
            StatusBar()
        }
        .frame(minWidth: 880, minHeight: 600)
    }
}

struct StatusBar: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(state.config.settings.paused ? Color.orange : Color.green)
                .frame(width: 8, height: 8)
            Text(state.config.settings.paused ? "În pauză" : "Activ")
                .fontWeight(.medium)
            Text("·").foregroundStyle(.secondary)
            Text(state.statusMessage)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            Toggle("Pauză", isOn: $state.config.settings.paused)
                .toggleStyle(.switch)
                .controlSize(.small)
        }
        .font(.callout)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}
