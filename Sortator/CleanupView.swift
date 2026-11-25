import SwiftUI
import AppKit

struct CleanupView: View {
    @EnvironmentObject var state: AppState
    /// Fișierele bifate pentru coș (dubluri). Implicit: toate copiile, mai puțin cea mai veche.
    @State private var selectedDuplicates: Set<String> = []
    @State private var selectedInstallers: Set<String> = []
    @State private var selectedVersions: Set<String> = []
    @State private var selectedScreenshots: Set<String> = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                duplicatesSection
                versionsSection
                screenshotsSection
                installersSection
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear {
            preselectDuplicates(state.duplicateGroups)
            preselectInstallers(state.oldInstallers)
            preselectVersions(state.versionGroups)
            selectedScreenshots = Set(state.oldScreenshots.map { $0.url.path })
            if state.oldInstallers.isEmpty {
                state.checkInstallers(ask: false)
            }
            if state.versionGroups.isEmpty && state.oldScreenshots.isEmpty {
                state.checkVersionsAndScreenshots(notify: false)
            }
        }
        .onChange(of: state.versionGroups) { _, groups in
            preselectVersions(groups)
        }
        .onChange(of: state.oldScreenshots) { _, list in
            selectedScreenshots = Set(list.map { $0.url.path })
        }
        .onChange(of: state.duplicateGroups) { _, groups in
            preselectDuplicates(groups)
        }
        .onChange(of: state.oldInstallers) { _, list in
            preselectInstallers(list)
        }
    }

    // MARK: Dubluri

    private var duplicatesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Dubluri")
                .font(.title2.weight(.semibold))
            Text("Fișiere cu exact același conținut, din folderele Sortator și din rădăcina folderelor urmărite (nu din folderele tale și nici din Keep). Nu se șterge nimic singur: bifezi ce vrei la coș, iar cel mai vechi exemplar rămâne debifat. Din Coș se pot recupera.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                if state.duplicateScanRunning {
                    ProgressView().controlSize(.small)
                    Text(state.duplicateScanProgress).foregroundStyle(.secondary)
                    Button("Oprește") { state.stopDuplicateScan() }
                } else {
                    Button {
                        state.scanDuplicates()
                    } label: {
                        Label("Caută dubluri acum", systemImage: "doc.on.doc")
                    }
                    if let last = state.lastDuplicateScan {
                        Text("Ultima căutare: \(last.formatted(date: .omitted, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if !selectedDuplicates.isEmpty {
                    Button("Mută la coș (\(selectedDuplicates.count))") {
                        trashDuplicates()
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }

            if state.duplicateGroups.isEmpty {
                if state.lastDuplicateScan != nil && !state.duplicateScanRunning {
                    Text("Nu am găsit dubluri.")
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 6)
                }
            } else {
                Text("\(RO.count(state.duplicateGroups.count, "fișier are dubluri", "fișiere au dubluri")) · se eliberează \(freedSpace) dacă muți la coș ce e bifat")
                    .font(.callout)
                ForEach(state.duplicateGroups) { group in
                    duplicateGroupView(group)
                }
            }
        }
    }

    private func duplicateGroupView(_ group: DuplicateGroup) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(group.files.first?.url.lastPathComponent ?? "")
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Text("\(group.files.count) exemplare · \(ByteCountFormatter.string(fromByteCount: group.size, countStyle: .file)) fiecare")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 8)
            ForEach(group.files) { file in
                Divider()
                HStack(spacing: 10) {
                    Toggle(isOn: duplicateBinding(file.url.path)) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(file.url.lastPathComponent)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Text("\(PathDisplay.parentFolder(file.url.path)) · \(file.added.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                    Spacer()
                    if !selectedDuplicates.contains(file.url.path) {
                        Text("rămâne")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting([file.url])
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                    .buttonStyle(.borderless)
                    .help("Arată în Finder")
                }
                .padding(.vertical, 6)
            }
        }
        .padding(.horizontal, 12)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(nsColor: .separatorColor)))
    }

    private var freedSpace: String {
        var total: Int64 = 0
        for group in state.duplicateGroups {
            for file in group.files where selectedDuplicates.contains(file.url.path) {
                total += file.size
            }
        }
        return ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
    }

    private func duplicateBinding(_ path: String) -> Binding<Bool> {
        Binding(
            get: { selectedDuplicates.contains(path) },
            set: { on in
                if on {
                    selectedDuplicates.insert(path)
                } else {
                    selectedDuplicates.remove(path)
                }
            }
        )
    }

    private func preselectDuplicates(_ groups: [DuplicateGroup]) {
        var selection = Set<String>()
        for group in groups {
            for file in group.files.dropFirst() {
                selection.insert(file.url.path)
            }
        }
        selectedDuplicates = selection
    }

    private func trashDuplicates() {
        // Siguranță: din fiecare grup rămâne cel puțin un exemplar.
        var urls: [URL] = []
        for group in state.duplicateGroups {
            let chosen = group.files.filter { selectedDuplicates.contains($0.url.path) }
            if chosen.count == group.files.count {
                urls += chosen.dropFirst().map { $0.url }
            } else {
                urls += chosen.map { $0.url }
            }
        }
        guard state.confirm("Muți la coș \(RO.count(urls.count, "fișier", "fișiere"))?",
                            "Din fiecare grup rămâne cel puțin un exemplar. Le poți recupera din Coș.",
                            ok: "Mută la coș") else { return }
        state.moveToTrash(urls)
    }

    // MARK: Versiuni vechi

    private var versionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Versiuni vechi")
                .font(.title2.weight(.semibold))
            Text("Același fișier în mai multe versiuni (ex. tema-v21 … tema-v54). Cea mai nouă versiune rămâne; celelalte sunt bifate pentru coș. Verifici, apoi Mută la coș.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Button {
                    state.checkVersionsAndScreenshots(notify: false)
                } label: {
                    Label("Verifică acum", systemImage: "square.stack.3d.up")
                }
                .disabled(state.versionScanRunning || state.screenshotScanRunning || !state.config.settings.findOldVersions)
                if state.versionScanRunning {
                    ProgressView().controlSize(.small)
                }
                Spacer()
                if !selectedVersions.isEmpty {
                    Button("Mută la coș (\(selectedVersions.count))") {
                        trashVersions()
                    }
                }
            }

            if !state.config.settings.findOldVersions {
                Text("Oprit din Setări → Curățenie.")
                    .foregroundStyle(.secondary)
            } else if state.versionGroups.isEmpty {
                Text("Nu sunt versiuni vechi.")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 6)
            } else {
                ForEach(state.versionGroups) { group in
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(group.files) { file in
                            if file.id != group.files.first?.id {
                                Divider()
                            }
                            HStack(spacing: 10) {
                                Toggle(isOn: selectionBinding(file.url.path, in: $selectedVersions)) {
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(file.url.lastPathComponent)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                        Text("v\(file.version) · \(PathDisplay.parentFolder(file.url.path)) · \(file.modified.formatted(date: .abbreviated, time: .shortened)) · \(ByteCountFormatter.string(fromByteCount: file.size, countStyle: .file))")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                    }
                                }
                                Spacer()
                                if file.id == group.files.first?.id {
                                    Text("cea mai nouă · rămâne")
                                        .font(.caption)
                                        .foregroundStyle(.green)
                                }
                                Button {
                                    NSWorkspace.shared.activateFileViewerSelecting([file.url])
                                } label: {
                                    Image(systemName: "magnifyingglass")
                                }
                                .buttonStyle(.borderless)
                                .help("Arată în Finder")
                            }
                            .padding(.vertical, 6)
                        }
                    }
                    .padding(.horizontal, 12)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor)))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(nsColor: .separatorColor)))
                }
            }
        }
    }

    private func preselectVersions(_ groups: [VersionGroup]) {
        var selection = Set<String>()
        for group in groups {
            for file in group.files.dropFirst() {
                selection.insert(file.url.path)
            }
        }
        selectedVersions = selection
    }

    private func trashVersions() {
        // Siguranță: din fiecare grup rămâne cel puțin o versiune (cea mai nouă).
        var urls: [URL] = []
        for group in state.versionGroups {
            let chosen = group.files.filter { selectedVersions.contains($0.url.path) }
            if chosen.count == group.files.count {
                urls += chosen.dropFirst().map { $0.url }
            } else {
                urls += chosen.map { $0.url }
            }
        }
        guard !urls.isEmpty,
              state.confirm("Muți la coș \(RO.count(urls.count, "versiune veche", "versiuni vechi"))?",
                            "Din fiecare fișier rămâne cel puțin o versiune. Le poți recupera din Coș.",
                            ok: "Mută la coș") else { return }
        state.moveToTrash(urls)
    }

    // MARK: Capturi de ecran

    private var screenshotsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Capturi de ecran vechi")
                .font(.title2.weight(.semibold))
            Text("Capturi de ecran mai vechi de \(state.config.settings.screenshotDays) de zile. Cele noi se sortează în Images/Screenshots.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                if state.screenshotScanRunning {
                    ProgressView().controlSize(.small)
                }
                Spacer()
                if !selectedScreenshots.isEmpty {
                    Button("Mută la coș (\(selectedScreenshots.count))") {
                        let urls = state.oldScreenshots.filter { selectedScreenshots.contains($0.url.path) }.map { $0.url }
                        guard state.confirm("Muți la coș \(RO.count(urls.count, "captură de ecran", "capturi de ecran"))?", "Le poți recupera din Coș.", ok: "Mută la coș") else { return }
                        state.moveToTrash(urls)
                    }
                }
            }

            if !state.config.settings.findOldScreenshots {
                Text("Oprit din Setări → Curățenie.")
                    .foregroundStyle(.secondary)
            } else if state.oldScreenshots.isEmpty {
                Text("Nu sunt capturi de ecran vechi.")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 6)
            } else {
                VStack(spacing: 0) {
                    ForEach(state.oldScreenshots) { item in
                        HStack(spacing: 10) {
                            Toggle(isOn: selectionBinding(item.url.path, in: $selectedScreenshots)) {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(item.url.lastPathComponent)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                    Text("\(PathDisplay.parentFolder(item.url.path)) · \(item.added.formatted(date: .abbreviated, time: .omitted)) · \(ByteCountFormatter.string(fromByteCount: item.size, countStyle: .file))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                            }
                            Spacer()
                            Button {
                                NSWorkspace.shared.open(item.url)
                            } label: {
                                Image(systemName: "eye")
                            }
                            .buttonStyle(.borderless)
                            .help("Deschide")
                        }
                        .padding(.vertical, 6)
                        if item.id != state.oldScreenshots.last?.id {
                            Divider()
                        }
                    }
                }
                .padding(.horizontal, 12)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor)))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(nsColor: .separatorColor)))
            }
        }
    }

    private func selectionBinding(_ path: String, in set: Binding<Set<String>>) -> Binding<Bool> {
        Binding(
            get: { set.wrappedValue.contains(path) },
            set: { on in
                if on {
                    set.wrappedValue.insert(path)
                } else {
                    set.wrappedValue.remove(path)
                }
            }
        )
    }

    // MARK: Installere

    private var installersSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Installere vechi")
                .font(.title2.weight(.semibold))
            Text("Fișiere .dmg și .pkg mai vechi de \(state.config.settings.installerDays) de zile. Aplicația te întreabă singură când apar; aici le vezi oricând.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Button {
                    state.checkInstallers(ask: false)
                } label: {
                    Label("Verifică acum", systemImage: "shippingbox")
                }
                .disabled(state.installerScanRunning)
                if state.installerScanRunning {
                    ProgressView().controlSize(.small)
                }
                Spacer()
                if !selectedInstallers.isEmpty {
                    Button("Mută la coș (\(selectedInstallers.count))") {
                        let urls = state.oldInstallers.filter { selectedInstallers.contains($0.url.path) }.map { $0.url }
                        guard state.confirm("Muți la coș \(RO.count(urls.count, "installer", "installere"))?", "Le poți recupera din Coș.", ok: "Mută la coș") else { return }
                        state.moveToTrash(urls)
                    }
                }
            }

            if state.oldInstallers.isEmpty {
                Text("Nu sunt installere vechi.")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 6)
            } else {
                VStack(spacing: 0) {
                    ForEach(state.oldInstallers) { item in
                        HStack(spacing: 10) {
                            Toggle(isOn: installerBinding(item.url.path)) {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(item.url.lastPathComponent)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                    Text("\(PathDisplay.parentFolder(item.url.path)) · descărcat \(item.added.formatted(date: .abbreviated, time: .omitted)) · \(ByteCountFormatter.string(fromByteCount: item.size, countStyle: .file))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                            }
                            Spacer()
                        }
                        .padding(.vertical, 6)
                        if item.id != state.oldInstallers.last?.id {
                            Divider()
                        }
                    }
                }
                .padding(.horizontal, 12)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor)))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(nsColor: .separatorColor)))
            }
        }
    }

    private func installerBinding(_ path: String) -> Binding<Bool> {
        Binding(
            get: { selectedInstallers.contains(path) },
            set: { on in
                if on {
                    selectedInstallers.insert(path)
                } else {
                    selectedInstallers.remove(path)
                }
            }
        )
    }

    private func preselectInstallers(_ list: [OldInstaller]) {
        selectedInstallers = Set(list.map { $0.url.path })
    }
}
