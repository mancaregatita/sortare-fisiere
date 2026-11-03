import SwiftUI

/// „Sortează ce există”: arată întâi ce s-ar muta, apoi mută doar ce rămâne bifat.
struct SortExistingSheet: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) private var dismiss
    let folder: WatchedFolder

    enum Phase: Equatable {
        case scanning, ready, moving, finished
    }

    @State private var phase: Phase = .scanning
    @State private var started = false
    @State private var done = 0
    @State private var total = 0
    @State private var moves: [PlannedMove] = []
    @State private var excluded: Set<UUID> = []
    @State private var resultText = ""
    @State private var token = CancelToken()

    private var selectedMoves: [PlannedMove] {
        moves.filter { !excluded.contains($0.id) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sortează ce există în „\(folder.displayName)”")
                .font(.title3.weight(.semibold))

            switch phase {
            case .scanning:
                VStack(alignment: .leading, spacing: 8) {
                    Text("Verific fișierele… \(done) din \(total)")
                    ProgressView(value: total > 0 ? Double(done) / Double(total) : 0)
                    Text("PDF-urile scanate și pozele trec prin OCR, așa că poate dura puțin.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            case .ready:
                if moves.isEmpty {
                    Text("Niciun fișier nu se potrivește cu regulile. Nu e nimic de mutat.")
                        .foregroundStyle(.secondary)
                    Spacer()
                } else {
                    Text("\(RO.count(moves.count, "fișier se potrivește", "fișiere se potrivesc")) cu regulile. Debifează ce vrei să rămână pe loc.")
                        .foregroundStyle(.secondary)
                    List(moves) { move in
                        Toggle(isOn: includeBinding(move.id)) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(move.source.lastPathComponent)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Text(move.newName == move.source.lastPathComponent
                                     ? "→ \(relative(move.destinationFolder))   ·   \(move.ruleName)"
                                     : "→ \(relative(move.destinationFolder))/\(move.newName)   ·   \(move.ruleName)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                        }
                    }
                }
            case .moving:
                ProgressView("Mut fișierele…")
                Spacer()
            case .finished:
                Text(resultText)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
            }

            HStack {
                Spacer()
                switch phase {
                case .scanning:
                    Button("Oprește") {
                        token.cancel()
                        dismiss()
                    }
                case .ready:
                    Button("Anulează") {
                        dismiss()
                    }
                    .keyboardShortcut(.cancelAction)
                    if !moves.isEmpty {
                        Button("Mută \(RO.count(selectedMoves.count, "fișier", "fișiere"))") {
                            runMoves()
                        }
                        .keyboardShortcut(.defaultAction)
                        .disabled(selectedMoves.isEmpty)
                    }
                case .moving:
                    EmptyView()
                case .finished:
                    Button("Gata") {
                        dismiss()
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(20)
        .frame(width: 660, height: 540)
        .onAppear {
            startPlan()
        }
    }

    private func startPlan() {
        guard !started else { return }
        started = true
        let currentToken = token
        state.engine.plan(folder: folder, token: currentToken, progress: { doneCount, totalCount in
            Task { @MainActor in
                done = doneCount
                total = totalCount
            }
        }, completion: { result in
            Task { @MainActor in
                if currentToken.isCancelled { return }
                moves = result
                phase = .ready
            }
        })
    }

    private func runMoves() {
        let list = selectedMoves
        phase = .moving
        state.engine.execute(list) { count, errors in
            Task { @MainActor in
                if errors.isEmpty {
                    resultText = "Am mutat \(RO.count(count, "fișier", "fișiere"))."
                } else {
                    resultText = "Am mutat \(RO.count(count, "fișier", "fișiere")). Nu am putut muta \(errors.count):\n"
                        + errors.prefix(10).joined(separator: "\n")
                }
                phase = .finished
            }
        }
    }

    private func includeBinding(_ id: UUID) -> Binding<Bool> {
        Binding(
            get: { !excluded.contains(id) },
            set: { include in
                if include {
                    excluded.remove(id)
                } else {
                    excluded.insert(id)
                }
            }
        )
    }

    private func relative(_ url: URL) -> String {
        let base = folder.url.standardizedFileURL.path + "/"
        let path = url.standardizedFileURL.path
        if path.hasPrefix(base) { return String(path.dropFirst(base.count)) }
        return PathDisplay.short(path)
    }
}
