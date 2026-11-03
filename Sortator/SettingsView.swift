import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        Form {
            Section("Funcționare") {
                Toggle("Pauză — nu mută nimic (fișierele venite între timp se sortează după ce repornești)", isOn: $state.config.settings.paused)
                Stepper(value: $state.config.settings.delaySeconds, in: 1...60, step: 1) {
                    Text("Așteaptă \(Int(state.config.settings.delaySeconds)) secunde după ce un fișier nu se mai schimbă")
                }
            }

            Section("Citirea conținutului (pentru condițiile „Conținutul conține”)") {
                Toggle("Citește textul din PDF-uri", isOn: $state.config.settings.readPDFText)
                Toggle("OCR pe PDF-urile scanate (fără text)", isOn: $state.config.settings.ocrScannedPDFs)
                    .disabled(!state.config.settings.readPDFText)
                Toggle("OCR pe poze și capturi de ecran", isOn: $state.config.settings.ocrImages)
                Toggle("Citește documente Word, Excel, PowerPoint și OpenOffice", isOn: $state.config.settings.readOfficeFiles)
                Toggle("Citește XML-urile din arhive .zip (ex. e-Factura din SPV)", isOn: $state.config.settings.readArchives)
                Stepper(value: $state.config.settings.maxPages, in: 1...20) {
                    Text("Pagini citite din fiecare PDF: \(state.config.settings.maxPages)")
                }
            }

            Section("Redenumire și tipul documentului") {
                Toggle("Redenumește documentele mutate (la regulile care au redenumirea bifată)", isOn: $state.config.settings.renameDocuments)
                Toggle("Folosește AI-ul Apple de pe Mac când nu recunoaște tipul documentului", isOn: $state.config.settings.useAppleAI)
                Text("AI-ul Apple: \(AppleAI.statusText) Rulează local, fără internet. Româna nu e oficial suportată, așa că e doar o rezervă; recunoașterea principală merge pe orice Mac.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section("Curățenie") {
                Toggle("Caută dubluri automat (de două ori pe zi)", isOn: $state.config.settings.autoDuplicateScan)
                Toggle("Întreabă-mă de installerele vechi (.dmg, .pkg)", isOn: $state.config.settings.askAboutInstallers)
                Stepper(value: $state.config.settings.installerDays, in: 7...180, step: 1) {
                    Text("Installer vechi = mai vechi de \(state.config.settings.installerDays) de zile")
                }
                .disabled(!state.config.settings.askAboutInstallers)
            }

            Section("Pornire") {
                Toggle("Pornește automat la deschiderea Mac-ului", isOn: Binding(
                    get: { state.launchAtLogin },
                    set: { state.setLaunchAtLogin($0) }
                ))
                .disabled(!state.isInstalledInApplications)

                if state.isInstalledInApplications {
                    Text("Instalată în \(Bundle.main.bundleURL.path)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    HStack {
                        Text("Aplicația rulează acum din folderul de build al Xcode. Mut-o în Aplicații ca să rămână instalată și să poată porni singură.")
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer()
                        Button("Mută în Aplicații") {
                            state.installInApplications()
                        }
                    }
                }
            }

            Section("Actualizări") {
                HStack {
                    Text("\(Updates.shared.versionText). Versiunile noi se instalează singure, în fundal.")
                    Spacer()
                    Button("Caută acum") {
                        Updates.shared.checkNow()
                    }
                }
            }

            Section("Date") {
                HStack {
                    Text("Setările, regulile și istoricul sunt în Application Support/Sortator.")
                    Spacer()
                    Button("Deschide") {
                        state.openInFinder(Storage.directory.path)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}

struct CompanyRow: View {
    @Binding var company: CompanyProfile
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            TextField("Nume", text: $company.name, prompt: Text("Nume firmă"))
                .labelsHidden()
                .frame(width: 180)
            TextField("Recunoscută după", text: $company.keywords, prompt: Text("CUI, nume"))
                .labelsHidden()
            Button(action: onDelete) {
                Image(systemName: "minus.circle")
            }
            .buttonStyle(.borderless)
            .help("Șterge firma din listă")
        }
    }
}
