import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var state: AppState
    @State private var filter = ""

    private var filtered: [HistoryEntry] {
        let text = filter.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return state.history }
        return state.history.filter {
            $0.fileName.localizedCaseInsensitiveContains(text)
                || $0.ruleName.localizedCaseInsensitiveContains(text)
                || $0.toPath.localizedCaseInsensitiveContains(text)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Istoric mutări")
                    .font(.title2.weight(.semibold))
                Spacer()
                TextField("Caută", text: $filter)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 220)
                Button("Golește") {
                    state.clearHistory()
                }
                .disabled(state.history.isEmpty)
            }
            Text("„Readu înapoi” pune fișierul unde era, iar Sortator nu îl mai mută automat.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if filtered.isEmpty {
                Spacer()
                Text(state.history.isEmpty ? "Nu s-a mutat încă niciun fișier." : "Nimic nu se potrivește căutării.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                Spacer()
            } else {
                List(filtered) { entry in
                    HistoryRow(entry: entry)
                }
                .listStyle(.inset)
            }
        }
        .padding(20)
    }
}

struct HistoryRow: View {
    @EnvironmentObject var state: AppState
    let entry: HistoryEntry

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: entry.undone ? "arrow.uturn.backward.circle" : "checkmark.circle.fill")
                .foregroundStyle(entry.undone ? Color.secondary : Color.green)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.fileName)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .strikethrough(entry.undone)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("Arată") {
                state.reveal(entry)
            }
            Button("Readu înapoi") {
                state.undo(entry)
            }
            .disabled(entry.undone)
        }
        .padding(.vertical, 3)
    }

    private var subtitle: String {
        if entry.undone {
            return "readus în \(PathDisplay.parentFolder(entry.fromPath))"
        }
        let newName = URL(fileURLWithPath: entry.toPath).lastPathComponent
        if newName != entry.fileName {
            return "\(entry.ruleName) → \(PathDisplay.parentFolder(entry.toPath))/\(newName)"
        }
        return "\(entry.ruleName) → \(PathDisplay.parentFolder(entry.toPath))"
    }
}
