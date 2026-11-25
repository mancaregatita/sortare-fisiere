import SwiftUI

/// „Mută folderele vechi în structura nouă”: Imagini → Images, Facturi → <an>/Invoices etc.
/// Arată lista întâi; mută doar ce rămâne bifat; folderele vechi rămase goale se șterg.
struct MigrateLegacySheet: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) private var dismiss

    enum Phase: Equatable {
        case scanning, ready, moving, finished
    }

    @State private var phase: Phase = .scanning
    @State private var started = false
    @State private var moves: [PlannedMove] = []
    @State private var oldFolders: [URL] = []
    @State private var excluded: Set<UUID> = []
    @State private var resultText = ""

    private var selectedMoves: [PlannedMove] {
        moves.filter { !excluded.contains($0.id) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Mută folderele vechi în structura nouă")
                .font(.title3.weight(.semibold))

            switch phase {
            case .scanning:
                ProgressView("Caut folderele vechi…")
                Spacer()
            case .ready:
                if moves.isEmpty {
                    Text("Nu am găsit foldere vechi (Imagini, Documente, Facturi, Bancă…). Totul e deja în structura nouă.")
                        .foregroundStyle(.secondary)
                    Spacer()
                } else {
                    Text("\(RO.count(moves.count, "element se mută", "elemente se mută")) în structura nouă (Images, Documents, Firme/<firmă>/<an>/Invoices…), cu numele traduse în engleză. Debifează ce vrei să rămână pe loc. Orice mutare se poate anula din Istoric.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    List(moves) { move in
                        Toggle(isOn: includeBinding(move.id)) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(PathDisplay.short(move.destinationFolder.path))/\(move.newName)")
                                    .lineLimit(1)
                                    .truncationMode(.head)
                                Text("acum: \(PathDisplay.short(move.source.path))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.head)
                            }
                        }
                    }
                }
            case .moving:
                ProgressView("Mut…")
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
                case .scanning, .moving:
                    EmptyView()
                case .ready:
                    Button("Anulează") {
                        dismiss()
                    }
                    .keyboardShortcut(.cancelAction)
                    if !moves.isEmpty {
                        Button("Mută \(RO.count(selectedMoves.count, "element", "elemente"))") {
                            run()
                        }
                        .keyboardShortcut(.defaultAction)
                        .disabled(selectedMoves.isEmpty)
                    }
                case .finished:
                    Button("Gata") {
                        dismiss()
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(20)
        .frame(width: 760, height: 580)
        .onAppear {
            guard !started else { return }
            started = true
            state.engine.planLegacyMigration { result, folders in
                Task { @MainActor in
                    moves = result
                    oldFolders = folders
                    phase = .ready
                }
            }
        }
    }

    private func run() {
        let list = selectedMoves
        let folders = oldFolders
        phase = .moving
        state.engine.executeMigration(list, oldFolders: folders) { count, errors in
            Task { @MainActor in
                if errors.isEmpty {
                    resultText = "Am mutat \(RO.count(count, "element", "elemente")). Folderele vechi rămase goale au fost șterse."
                } else {
                    resultText = "Am mutat \(RO.count(count, "element", "elemente")). Nu am putut muta \(errors.count):\n"
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
