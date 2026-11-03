import SwiftUI

struct RulesView: View {
    @EnvironmentObject var state: AppState
    @State private var selection: UUID?
    @State private var testTarget: TestTarget?

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                List(selection: $selection) {
                    ForEach(state.config.rules) { rule in
                        RuleRow(rule: rule, number: number(of: rule))
                    }
                    .onMove { source, destination in
                        state.config.rules.move(fromOffsets: source, toOffset: destination)
                    }
                }
                Divider()
                HStack(spacing: 6) {
                    Button {
                        selection = state.addRule()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .help("Regulă nouă")
                    Button {
                        deleteSelected()
                    } label: {
                        Image(systemName: "minus")
                    }
                    .help("Șterge regula selectată")
                    .disabled(selection == nil)
                    Button {
                        if let id = selection {
                            selection = state.duplicateRule(id)
                        }
                    } label: {
                        Image(systemName: "plus.square.on.square")
                    }
                    .help("Duplică regula")
                    .disabled(selection == nil)
                    Divider()
                        .frame(height: 16)
                    Button {
                        if let id = selection {
                            state.moveRule(id, by: -1)
                        }
                    } label: {
                        Image(systemName: "chevron.up")
                    }
                    .help("Mută mai sus (se verifică mai devreme)")
                    .disabled(selection == nil)
                    Button {
                        if let id = selection {
                            state.moveRule(id, by: 1)
                        }
                    } label: {
                        Image(systemName: "chevron.down")
                    }
                    .help("Mută mai jos")
                    .disabled(selection == nil)
                    Spacer()
                    Menu {
                        Button("Exportă regulile…") { state.exportRules() }
                        Button("Importă reguli…") { state.importRules() }
                        Divider()
                        Button("Revino la regulile inițiale…") {
                            selection = nil
                            state.resetRules()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }
                .buttonStyle(.borderless)
                .padding(8)
            }
            .frame(width: 300)

            Divider()

            VStack(spacing: 0) {
                if let id = selection, state.config.rules.contains(where: { $0.id == id }) {
                    RuleEditor(rule: state.ruleBinding(id))
                        .id(id)
                } else {
                    RulesHelp()
                }
                Divider()
                HStack {
                    Text("Regulile se verifică de sus în jos. Prima care se potrivește decide unde merge fișierul.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Testează un fișier…") {
                        if let url = state.pickFileToTest() {
                            testTarget = TestTarget(url: url)
                        }
                    }
                }
                .padding(10)
            }
        }
        .sheet(item: $testTarget) { target in
            TestFileSheet(target: target)
                .environmentObject(state)
        }
        .onAppear {
            if selection == nil {
                selection = state.config.rules.first?.id
            }
        }
    }

    private func number(of rule: SortRule) -> Int {
        (state.config.rules.firstIndex(where: { $0.id == rule.id }) ?? 0) + 1
    }

    private func deleteSelected() {
        guard let id = selection else { return }
        let name = state.config.rules.first(where: { $0.id == id })?.name ?? ""
        guard state.confirm("Ștergi regula „\(name)”?", "Fișierele deja mutate rămân unde sunt.", ok: "Șterge") else { return }
        let index = state.config.rules.firstIndex(where: { $0.id == id }) ?? 0
        selection = nil
        state.deleteRule(id)
        if !state.config.rules.isEmpty {
            selection = state.config.rules[min(index, state.config.rules.count - 1)].id
        }
    }
}

struct RuleRow: View {
    let rule: SortRule
    let number: Int

    var body: some View {
        HStack(spacing: 8) {
            Text("\(number)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 22, alignment: .trailing)
            VStack(alignment: .leading, spacing: 1) {
                Text(rule.name.isEmpty ? "Fără nume" : rule.name)
                    .lineLimit(1)
                    .foregroundStyle(rule.enabled ? Color.primary : Color.secondary)
                Text(rule.destination.isEmpty ? "rămâne pe loc" : rule.destination)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            if !rule.enabled {
                Text("oprită")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

struct RuleEditor: View {
    @EnvironmentObject var state: AppState
    @Binding var rule: SortRule

    var body: some View {
        Form {
            Section {
                TextField("Nume", text: $rule.name)
                Toggle("Regula este activă", isOn: $rule.enabled)
            }

            Section {
                Picker("Se aplică atunci când se potrivesc", selection: $rule.matchMode) {
                    ForEach(MatchMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                ForEach(rule.conditions) { condition in
                    ConditionRow(condition: conditionBinding(condition.id)) {
                        rule.conditions.removeAll { $0.id == condition.id }
                    }
                }
                Button {
                    rule.conditions.append(RuleCondition(field: .name, keywords: ""))
                } label: {
                    Label("Adaugă condiție", systemImage: "plus")
                }
            } header: {
                Text("Condiții")
            } footer: {
                Text("Separă cuvintele prin virgulă; ajunge să se găsească unul. Se caută cuvinte întregi, fără să conteze majusculele sau diacriticele. Pune * la final pentru orice continuare (factur* prinde factura, facturi). Numerele, ca un CUI, se găsesc și scrise cu RO în față.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                HStack {
                    TextField("Mută în", text: $rule.destination, prompt: Text("ex. Firme/{firma}/{tipdoc}"))
                    Button("Alege…") {
                        if let path = state.pickFolder() {
                            rule.destination = path
                        }
                    }
                }
                Toggle("Redenumește: Dată – Firmă – Tip – Partener", isOn: $rule.rename)
            } header: {
                Text("Destinație")
            } footer: {
                Text("Un subfolder al folderului urmărit sau o cale oriunde pe Mac (începe cu ~/ sau /). Poți folosi {tipdoc} (Facturi, Contracte, Bancă…), {firma}, {partener}, {an} și {luna} (din data documentului), {tip} (Imagini, Documente…) și {ext}. Redenumirea se face doar când aplicația recunoaște tipul documentului; altfel numele rămâne. Gol = fișierul rămâne pe loc: așa faci o excepție, pusă deasupra celorlalte reguli.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private func conditionBinding(_ id: UUID) -> Binding<RuleCondition> {
        Binding(
            get: {
                rule.conditions.first(where: { $0.id == id }) ?? RuleCondition(field: .name, keywords: "")
            },
            set: { newValue in
                if let index = rule.conditions.firstIndex(where: { $0.id == id }) {
                    rule.conditions[index] = newValue
                }
            }
        )
    }
}

struct ConditionRow: View {
    @Binding var condition: RuleCondition
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Picker("Condiție", selection: $condition.field) {
                ForEach(ConditionField.allCases) { field in
                    Text(field.label).tag(field)
                }
            }
            .labelsHidden()
            .frame(width: 230)
            TextField("Cuvinte", text: $condition.keywords, prompt: Text(condition.field.placeholder), axis: .vertical)
                .labelsHidden()
                .lineLimit(1...4)
            Button(action: onDelete) {
                Image(systemName: "minus.circle")
            }
            .buttonStyle(.borderless)
            .help("Șterge condiția")
        }
    }
}

struct RulesHelp: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Alege o regulă din stânga ca să o modifici.")
                .font(.headline)
            Text("Fiecare regulă are condiții (extensie, cuvinte în nume, cuvinte în conținut) și un folder de destinație. Când apare un fișier nou, Sortator verifică regulile de sus în jos și îl mută după prima care se potrivește. Dacă nu se potrivește niciuna, fișierul rămâne unde e.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("Regulile pentru firme sunt sus, ca o factură a unei firme să ajungă la firma ei, nu în Documente. Firmele le găsește aplicația în documente, în tab-ul Firme.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
