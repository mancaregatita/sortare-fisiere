import SwiftUI
import AppKit

struct FoldersView: View {
    @EnvironmentObject var state: AppState
    @State private var sortTarget: WatchedFolder?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                watchedSection
                excludedSection
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .sheet(item: $sortTarget) { folder in
            SortExistingSheet(folder: folder)
                .environmentObject(state)
        }
    }

    private var watchedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Foldere urmărite")
                .font(.title2.weight(.semibold))
            Text("Fișierele noi care apar aici sunt mutate automat în subfoldere, după reguli. Ce exista deja în folder rămâne neatins până apeși „Sortează ce există”. Subfolderele și aplicațiile (.app) nu sunt mutate niciodată.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if state.config.folders.isEmpty {
                Text("Niciun folder urmărit încă.")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 12)
            } else {
                VStack(spacing: 0) {
                    ForEach(state.config.folders) { folder in
                        FolderRow(folder: folder) {
                            sortTarget = folder
                        }
                        if folder.id != state.config.folders.last?.id {
                            Divider()
                        }
                    }
                }
                .padding(.horizontal, 12)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor)))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(nsColor: .separatorColor)))
            }

            HStack {
                Button {
                    state.addFolders()
                } label: {
                    Label("Adaugă folder…", systemImage: "plus")
                }
                if !state.hasDownloadsFolder {
                    Button("Adaugă Descărcări") {
                        state.addDownloads()
                    }
                }
            }
        }
    }

    private var excludedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Foldere excluse")
                .font(.title2.weight(.semibold))
            Text("Sortator nu atinge niciodată aceste foldere și nimic din interiorul lor: nu ia fișiere de aici și nu pune fișiere aici, chiar dacă o regulă ar trimite acolo.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 0) {
                if state.config.excludedFolders.isEmpty {
                    Text("Niciun folder exclus.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 10)
                }
                ForEach(state.config.excludedFolders, id: \.self) { path in
                    HStack(spacing: 10) {
                        Image(systemName: "nosign")
                            .foregroundStyle(.secondary)
                        Text(path)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Button {
                            state.removeExcludedFolder(path)
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.borderless)
                        .help("Scoate din excluderi")
                    }
                    .padding(.vertical, 7)
                    if path != state.config.excludedFolders.last {
                        Divider()
                    }
                }
            }
            .padding(.horizontal, 12)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor)))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(nsColor: .separatorColor)))

            HStack {
                Button {
                    state.addExcludedFolders()
                } label: {
                    Label("Exclude un folder…", systemImage: "nosign")
                }
                if AppConfig.defaultExcludedFolders.contains(where: { !state.config.excludedFolders.contains($0) }) {
                    Button("Pune la loc excluderile inițiale") {
                        state.restoreDefaultExclusions()
                    }
                }
            }
        }
    }
}

struct FolderRow: View {
    @EnvironmentObject var state: AppState
    let folder: WatchedFolder
    let onSortExisting: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: folder.path))
                .resizable()
                .frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(folder.displayName)
                    .font(.headline)
                Text(folder.shortPath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if !FileManager.default.fileExists(atPath: folder.path) {
                    Text("Folderul nu mai există")
                        .font(.caption)
                        .foregroundStyle(.red)
                } else if state.isFolderExcluded(folder) {
                    Text("Este în lista de excluderi — nu e urmărit")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            Spacer()
            Toggle("Activ", isOn: state.folderEnabledBinding(folder.id))
                .toggleStyle(.switch)
            Button("Sortează ce există…", action: onSortExisting)
                .disabled(state.isFolderExcluded(folder))
            Button {
                state.openInFinder(folder.path)
            } label: {
                Image(systemName: "arrow.up.forward.app")
            }
            .buttonStyle(.borderless)
            .help("Deschide în Finder")
            Button {
                state.removeFolder(folder.id)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("Nu mai urmări acest folder")
        }
        .padding(.vertical, 8)
    }
}
