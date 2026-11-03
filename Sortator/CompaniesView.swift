import SwiftUI

struct CompaniesView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                suggestionsSection
                ownSection
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: Găsite în documente

    private var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Firme găsite în documente")
                .font(.title2.weight(.semibold))
            Text("Sortator citește CUI-urile (verificate cu cifra de control) și numele firmelor din facturi, contracte și e-Factura. Firmele tale apar pe aproape toate documentele, mai ales ca client. Confirmă-le cu „E firma mea” și se creează singură regula: Firme/<firmă>/<tip document>.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                if state.companyScanRunning {
                    ProgressView().controlSize(.small)
                    Text(state.companyScanProgress).foregroundStyle(.secondary)
                    Button("Oprește") { state.stopCompanyScan() }
                } else {
                    Button {
                        state.scanCompaniesNow()
                    } label: {
                        Label("Caută în documentele existente", systemImage: "doc.text.magnifyingglass")
                    }
                }
                Spacer()
                Text("\(RO.count(state.discovery.totalDocuments, "document citit", "documente citite"))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            let suggestions = state.companySuggestions
            if suggestions.isEmpty {
                Text(state.discovery.totalDocuments == 0
                     ? "Încă nu a citit niciun document. Apasă „Caută în documentele existente” sau așteaptă să vină documente noi."
                     : "Nicio firmă nouă de confirmat.")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 6)
            } else {
                VStack(spacing: 0) {
                    ForEach(suggestions) { company in
                        SuggestionRow(company: company, likelyOwn: state.looksLikeOwn(company))
                        if company.id != suggestions.last?.id {
                            Divider()
                        }
                    }
                }
                .padding(.horizontal, 12)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor)))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(nsColor: .separatorColor)))
            }

            if state.discovery.companies.contains(where: { $0.dismissed }) {
                Button("Arată din nou firmele respinse") {
                    state.restoreDismissedCompanies()
                }
                .buttonStyle(.link)
            }
        }
    }

    // MARK: Firmele mele

    private var ownSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Firmele mele")
                .font(.title2.weight(.semibold))
            Text("Se folosesc pentru „Firmă” din numele fișierului și ca să știe care e partenerul de pe document. „Recunoscută după” = CUI și nume, separate prin virgulă.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 0) {
                if state.config.companies.isEmpty {
                    Text("Nicio firmă încă.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 10)
                }
                ForEach(state.config.companies) { company in
                    CompanyRow(company: state.companyBinding(company.id)) {
                        state.removeCompany(company.id)
                    }
                    .padding(.vertical, 6)
                    if company.id != state.config.companies.last?.id {
                        Divider()
                    }
                }
            }
            .padding(.horizontal, 12)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor)))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(nsColor: .separatorColor)))

            Button {
                state.addCompany()
            } label: {
                Label("Adaugă o firmă manual", systemImage: "plus")
            }
        }
    }
}

struct SuggestionRow: View {
    @EnvironmentObject var state: AppState
    let company: DiscoveredCompany
    let likelyOwn: Bool
    @State private var name: String = ""

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    TextField("Nume", text: $name)
                        .textFieldStyle(.plain)
                        .font(.headline)
                    if likelyOwn {
                        Text("pare a ta")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.green.opacity(0.18)))
                            .foregroundStyle(.green)
                    }
                }
                Text("CUI \(company.cui) · în \(RO.count(company.documents, "document", "documente")) · client în \(company.asCustomer), furnizor în \(company.asSupplier)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Nu e a mea") {
                state.dismissCompany(company)
            }
            Button("E firma mea") {
                state.adoptCompany(company, name: name)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.vertical, 8)
        .onAppear {
            if name.isEmpty { name = company.name }
        }
    }
}
