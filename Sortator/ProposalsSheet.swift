import SwiftUI
import AppKit

/// Mod de probă: mutările pe care Sortator le-ar fi făcut. Muți doar ce aprobi.
struct ProposalsSheet: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var unchecked: Set<UUID> = []
    @State private var moving = false
    @State private var resultText = ""

    private var checked: Set<UUID> {
        Set(state.proposals.map { $0.id }).subtracting(unchecked)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Propuneri din modul de probă")
                .font(.title3.weight(.semibold))
            Text("În modul de probă Sortator nu mută nimic singur: notează aici unde ar duce fiecare fișier nou. Bifează ce e corect și apasă Mută; ce respingi rămâne pe loc și nu mai e propus.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if state.proposals.isEmpty {
                Spacer()
                Text(resultText.isEmpty ? "Nicio propunere de aprobat." : resultText)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                Spacer()
            } else {
                HStack {
                    Button("Bifează tot") { unchecked = [] }
                    Button("Debifează tot") { unchecked = Set(state.proposals.map { $0.id }) }
                    Spacer()
                    Text("\(checked.count) din \(state.proposals.count) bifate")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.link)
                List(state.proposals) { proposal in
                    HStack(spacing: 8) {
                        Toggle(isOn: binding(proposal.id)) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(proposal.fileName)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Text(subtitle(proposal))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                        }
                        Spacer()
                        Button {
                            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: proposal.sourcePath)])
                        } label: {
                            Image(systemName: "magnifyingglass")
                        }
                        .buttonStyle(.borderless)
                        .help("Arată în Finder")
                    }
                }
                .listStyle(.inset)
                if !resultText.isEmpty {
                    Text(resultText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                if moving {
                    ProgressView().controlSize(.small)
                }
                Spacer()
                Button("Închide") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Respinge bifate") {
                    state.rejectProposals(checked)
                    unchecked = []
                }
                .disabled(checked.isEmpty || moving)
                Button("Mută bifate (\(checked.count))") {
                    move()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(checked.isEmpty || moving)
            }
        }
        .padding(20)
        .frame(width: 760, height: 560)
        .onAppear {
            state.pruneProposals()
        }
    }

    private func subtitle(_ proposal: ProposedMove) -> String {
        let folder = PathDisplay.short(proposal.destinationFolderPath)
        let renamed = proposal.newName != proposal.fileName ? "/\(proposal.newName)" : ""
        return "→ \(folder)\(renamed)   ·   \(proposal.ruleName)"
    }

    private func binding(_ id: UUID) -> Binding<Bool> {
        Binding(
            get: { !unchecked.contains(id) },
            set: { on in
                if on { unchecked.remove(id) } else { unchecked.insert(id) }
            }
        )
    }

    private func move() {
        let ids = checked
        moving = true
        state.approveProposals(ids) { count, errors in
            moving = false
            unchecked = []
            resultText = "Mutate: \(RO.count(count, "fișier", "fișiere"))."
                + (errors.isEmpty ? "" : " Nu s-au putut muta: " + errors.prefix(5).joined(separator: "; "))
        }
    }
}
