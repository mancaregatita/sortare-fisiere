import SwiftUI

/// „Redenumește documentele sortate”: arată întâi numele noi, apoi redenumește doar ce rămâne bifat.
/// Caută doar în folderele în care Sortator pune documente redenumite (ex. Firme/<firmă>, Documente).
struct RenameExistingSheet: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) private var dismiss

    enum Phase: Equatable {
        case scanning, ready, renaming, finished
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
            Text("Redenumește documentele sortate")
                .font(.title3.weight(.semibold))

            switch phase {
            case .scanning:
                VStack(alignment: .leading, spacing: 8) {
                    Text("Citesc documentele… \(done) din \(total)")
                    ProgressView(value: total > 0 ? Double(done) / Double(total) : 0)
                    Text("Se citesc doar folderele regulilor cu redenumire (ex. Firme/…). PDF-urile scanate și pozele trec prin OCR, așa că poate dura.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            case .ready:
                if moves.isEmpty {
                    Text("Nu e nimic de redenumit: documentele au deja numele potrivit sau tipul lor nu a fost recunoscut.")
                        .foregroundStyle(.secondary)
                    Spacer()
                } else {
                    Text("\(RO.count(moves.count, "document primește", "documente primesc")) nume nou: Tip Număr – Partener – Dată. Debifează ce vrei să rămână cum e. Orice redenumire se poate anula din Istoric.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    List(moves) { move in
                        Toggle(isOn: includeBinding(move.id)) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(move.newName)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Text("acum: \(move.source.lastPathComponent)   ·   \(PathDisplay.short(move.destinationFolder.path))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                        }
                    }
                }
            case .renaming:
                ProgressView("Redenumesc…")
                Spacer()
            case .finished:
                Text(resultText)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
            }

            HStack {
                if phase == .ready && !moves.isEmpty {
                    Button(excluded.isEmpty ? "Debifează tot" : "Bifează tot") {
                        if excluded.isEmpty {
                            excluded = Set(moves.map { $0.id })
                        } else {
                            excluded = []
                        }
                    }
                }
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
                        Button("Redenumește \(RO.count(selectedMoves.count, "document", "documente"))") {
                            runRenames()
                        }
                        .keyboardShortcut(.defaultAction)
                        .disabled(selectedMoves.isEmpty)
                    }
                case .renaming:
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
        .frame(width: 720, height: 560)
        .onAppear {
            startPlan()
        }
    }

    private func startPlan() {
        guard !started else { return }
        started = true
        let currentToken = token
        state.engine.planRenames(token: currentToken, progress: { doneCount, totalCount in
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

    private func runRenames() {
        let list = selectedMoves
        phase = .renaming
        state.engine.execute(list) { count, errors in
            Task { @MainActor in
                if errors.isEmpty {
                    resultText = "Am redenumit \(RO.count(count, "document", "documente"))."
                } else {
                    resultText = "Am redenumit \(RO.count(count, "document", "documente")). Nu am putut redenumi \(errors.count):\n"
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
}
