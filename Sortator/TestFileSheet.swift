import SwiftUI
import AppKit

/// Arată ce regulă s-ar aplica unui fișier și ce text a citit aplicația din el. Nu mută nimic.
struct TestFileSheet: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) private var dismiss
    let target: TestTarget

    @State private var result: TestResult?
    @State private var started = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Test: \(target.url.lastPathComponent)")
                .font(.title3.weight(.semibold))
                .lineLimit(1)
                .truncationMode(.middle)

            if let result {
                GroupBox {
                    VStack(alignment: .leading, spacing: 6) {
                        if let ruleName = result.ruleName {
                            Label("Se potrivește cu regula „\(ruleName)”", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Ar merge în: \(result.destination ?? "")")
                        } else {
                            Label("Nicio regulă nu se potrivește — fișierul ar rămâne pe loc", systemImage: "xmark.circle")
                                .foregroundStyle(.orange)
                            if let destination = result.destination {
                                Text(destination)
                            }
                        }
                        Text("Nume: \(result.proposedName)")
                            .textSelection(.enabled)
                        Text("Citire conținut: \(result.textMethod.isEmpty ? "nu a fost nevoie" : result.textMethod)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox {
                    Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 4) {
                        GridRow {
                            Text("Tip document").foregroundStyle(.secondary)
                            Text(result.documentType)
                        }
                        GridRow {
                            Text("Firmă").foregroundStyle(.secondary)
                            Text(result.company)
                        }
                        GridRow {
                            Text("Partener").foregroundStyle(.secondary)
                            Text(result.partner)
                        }
                        GridRow {
                            Text("Dată").foregroundStyle(.secondary)
                            Text(result.dateText)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Text("Reguli verificate, de sus în jos")
                    .font(.headline)
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(result.ruleReport.enumerated()), id: \.offset) { _, line in
                            Text(line)
                                .font(.system(.caption, design: .monospaced))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(6)
                }
                .frame(height: 120)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))

                Text("Text găsit în fișier")
                    .font(.headline)
                ScrollView {
                    Text(result.textSnippet.isEmpty ? "(niciun text)" : result.textSnippet)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(6)
                }
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                ProgressView("Citesc fișierul…")
                Spacer()
            }

            HStack {
                Spacer()
                Button("Închide") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 700, height: 680)
        .onAppear {
            guard !started else { return }
            started = true
            state.engine.test(target.url) { testResult in
                Task { @MainActor in
                    result = testResult
                }
            }
        }
    }
}
