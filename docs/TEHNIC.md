# Sortator – documentație tehnică

Pentru programatorul care preia aplicația. Tot ce e scris aici e verificat în cod (commit `33dc182`). Unde codul nu lămurește ceva, scrie „neclar din cod”.

## Ce face

Aplicație macOS de bara de meniu (fără iconiță în Dock, `LSUIElement = true`), scrisă în Swift/SwiftUI. Urmărește folderele alese (implicit Descărcări) și mută fișierele noi în subfoldere, după reguli definite de utilizator:

- condiții pe extensie, cuvinte din nume, cuvinte din conținut;
- citirea conținutului: text din PDF, OCR (Vision) pe PDF-uri scanate și poze, Word/Excel/PowerPoint/OpenOffice, RTF/DOC, text/XML, XML-uri din arhive `.zip` (e-Factura din SPV);
- recunoaște tipul documentului (Factură, Contract, Extras de cont etc.), firma proprie, partenerul și data, numărul documentului, și poate redenumi fișierul `Tip Număr – Partener – Dată.ext`;
- găsește firme (CUI validat cu cifra de control) în documente și propune adăugarea lor ca „firmele mele”, cu regulă proprie;
- curățenie: dubluri (SHA-256) și installere vechi (.dmg/.pkg/.mpkg), mutate la Coș doar la cererea utilizatorului;
- istoric al mutărilor, cu anulare („Readu înapoi”).

Uz intern, rulează local pe Mac-ul Mihaelei. Nu are server, nu are cont, nu trimite date pe internet.

## Stack și găzduire

| Element | Valoare |
|---|---|
| Limbaj / UI | Swift 5 (`SWIFT_VERSION = 5.0`), SwiftUI + AppKit (`MenuBarExtra`, `NSWindow`, `NSAlert`, `NSOpenPanel`) |
| Țintă minimă | macOS 14.0 (`MACOSX_DEPLOYMENT_TARGET`) |
| Proiect Xcode | `Sortator.xcodeproj`, `objectVersion = 77`, grup sincronizat cu folderul `Sortator/` (`fileSystemSynchronizedGroups`) – orice fișier `.swift` pus în `Sortator/` intră automat în target. Necesită Xcode 16 sau mai nou |
| Bundle ID | `ro.mancaregatita.sortator` |
| Versiune | `MARKETING_VERSION = 1.0`, `CURRENT_PROJECT_VERSION = 1` |
| Semnare | ad-hoc (`CODE_SIGN_IDENTITY = "-"`, `CODE_SIGN_STYLE = Manual`, fără Team). Fără Developer ID, fără notarizare |
| Sandbox / Hardened Runtime | oprite (`ENABLE_APP_SANDBOX = NO`, `ENABLE_HARDENED_RUNTIME = NO`) |
| Dependențe externe | niciuna (fără Swift Packages, fără CocoaPods) |
| Framework-uri Apple | SwiftUI, AppKit, ServiceManagement (pornire la login), PDFKit, Vision (OCR), ImageIO, CoreGraphics, CryptoKit (SHA-256), UniformTypeIdentifiers, FoundationModels (AI Apple, opțional, doar dacă se compilează cu SDK-ul macOS 26) |
| Unelte de sistem | `/usr/bin/unzip` (citire .docx/.xlsx/.pptx/.odt și .zip) |
| Găzduire | locală, pe Mac. Aplicația se instalează în `/Applications/Sortator.app` |
| Date | fișiere JSON în `~/Library/Application Support/Sortator/` (fără bază de date) |
| Cod | GitHub `mancaregatita/sortare-fisiere` (public) |
| URL-uri | niciunul (aplicația nu face cereri de rețea) |

Schema `Sortator` rulează (Run, ⌘R) în configurația **Release**; Test și Analyze în Debug.

## Structura fișierelor

| Fișier | Rol |
|---|---|
| `Info.plist` | `LSUIElement` (fără Dock) și textele pentru cererile de permisiune macOS (Descărcări, Desktop, Documente, discuri externe, rețea). Restul cheilor sunt generate (`GENERATE_INFOPLIST_FILE = YES`) |
| `Sortator.xcodeproj/` | proiectul și schema partajată `Sortator.xcscheme` |
| `Sortator/SortatorApp.swift` | `@main`; `MenuBarExtra` cu meniul din bara de sus (stare, ultimele 5 mutări, alerte, pauză, deschidere fereastră, ieșire) |
| `Sortator/AppState.swift` | starea globală (`AppState.shared`, `@MainActor`): încărcare/salvare config, istoric, firme găsite, curățenie periodică, fereastra principală, import/export reguli, pornire la login, „Mută în Aplicații”, dialoguri |
| `Sortator/SortEngine.swift` | motorul de sortare pe o coadă proprie (`ro.mancaregatita.sortator.engine`): urmărire, așteptarea terminării descărcării, potrivire reguli, mutare, anulare, previzualizare „Sortează ce există”, test fișier, rezolvarea destinației |
| `Sortator/FolderWatcher.swift` | `DispatchSource` pe descriptorul folderului (evenimente write/rename/delete/extend/link) |
| `Sortator/RuleMatcher.swift` | normalizarea textului (fără diacritice/majuscule), sintaxa cuvintelor cheie, `FileContext` (conținut citit leneș), potrivirea regulilor |
| `Sortator/ContentExtractor.swift` | citirea textului din fișiere + OCR |
| `Sortator/DocumentAnalyzer.swift` | tipuri de documente, analiza (tip, firmă, partener, dată), parser e-Factura (UBL), găsirea datei, curățarea numelor de firmă, extragerea firmelor (CUI) |
| `Sortator/AppleAI.swift` | rezerva cu AI-ul Apple local (FoundationModels, macOS 26) pentru tipul documentului |
| `Sortator/CleanupScanner.swift` | dubluri, installere vechi, scanarea firmelor din documentele existente, mutare la Coș |
| `Sortator/DefaultRules.swift` | regulile inițiale (pe tipuri de fișiere), șablonul regulii de firmă, categoriile pentru `{tip}` |
| `Sortator/Models.swift` | modelele Codable: foldere, reguli, condiții, firme, setări, config + migrare, excluderi, istoric, curățenie, firme găsite |
| `Sortator/Storage.swift` | citire/scriere JSON în Application Support; afișarea căilor cu `~`; pluralul românesc (`RO.count`) |
| `Sortator/MainView.swift` | fereastra principală cu tab-uri + bara de stare |
| `Sortator/FoldersView.swift` | tab Foldere (urmărite + excluse) |
| `Sortator/RulesView.swift` | tab Reguli (listă, editor, ajutor) |
| `Sortator/CompaniesView.swift` | tab Firme (găsite în documente + firmele mele) |
| `Sortator/CleanupView.swift` | tab Curățenie (dubluri + installere vechi) |
| `Sortator/HistoryView.swift` | tab Istoric |
| `Sortator/SettingsView.swift` | tab Setări; conține și `CompanyRow` folosit în tab-ul Firme |
| `Sortator/SortExistingSheet.swift` | fereastra „Sortează ce există…” (previzualizare + mutare) |
| `Sortator/TestFileSheet.swift` | fereastra „Testează un fișier…” |
| `Sortator/AppIcon.icon/` | iconița în format Icon Composer (Xcode 26) |
| `Sortator/Assets.xcassets/AppIcon.appiconset/` | iconița clasică PNG (16–1024 px) |

## Ecrane

| Unde | Ce conține |
|---|---|
| Meniul din bara de sus | „Sortator urmărește N foldere” / „Sortator e în pauză”, ultimul mesaj de stare, ultimele 5 mutări (click = arată în Finder), „Firme de confirmat”, „Dubluri găsite”, „Installere vechi”, Pune pe pauză / Repornește sortarea, Deschide Sortator… (⌘,), Istoric mutări…, Ieșire (⌘Q). Iconița: `tray.and.arrow.down`, sau `pause.circle` în pauză |
| Tab Foldere | foldere urmărite (comutator Activ, „Sortează ce există…”, Deschide în Finder, scoate), Adaugă folder…, Adaugă Descărcări; foldere excluse (adaugă, scoate, „Pune la loc excluderile inițiale”) |
| Tab Reguli | listă numerotată (ordinea = prioritatea), +, −, duplică, sus/jos, drag & drop, meniu „…” cu Export/Import/„Revino la regulile inițiale…”; editor: nume, activă, mod potrivire, condiții, destinație, redenumire; buton „Testează un fișier…” |
| Tab Firme | „Firme găsite în documente” (E firma mea / Nu e a mea, „Caută în documentele existente”, „Arată din nou firmele respinse”); „Firmele mele” (nume + „Recunoscută după”) |
| Tab Curățenie | Dubluri (căutare, bifare, Mută la coș), Installere vechi (Verifică acum, bifare, Mută la coș) |
| Tab Istoric | listă cu căutare (nume fișier, regulă, destinație), Arată, Readu înapoi, Golește |
| Tab Setări | Funcționare, Citirea conținutului, Redenumire și tipul documentului, Curățenie, Pornire, Date |

Fereastra principală se deschide la prima pornire și din meniu. Cât e deschisă, aplicația apare în Dock (`setActivationPolicy(.regular)`); la închidere revine la `.accessory`.

## Fluxul de sortare automată (`SortEngine`)

1. La pornire se încarcă `engine-state.json` și se pornește un timer la 2 secunde pe coada motorului.
2. Pentru fiecare folder activ și neexclus există un `FolderWatcher`; orice eveniment marchează „dirty”. Pe lângă asta, la fiecare 30 de secunde se face o scanare completă (și se resincronizează watcher-ele).
3. Se citește doar primul nivel al folderului (`contentsOfDirectory`, fără fișiere ascunse). Subfolderele nu sunt parcurse și nu sunt mutate.
4. Un fișier e candidat doar dacă:
   - nu începe cu `.`, `~$` sau `Unconfirmed `; nu e `.DS_Store`, `.localized`, `Icon\r`;
   - extensia nu e temporară (`crdownload, download, part, partial, tmp, temp, opdownload, filepart, !ut, td, aria2, unconfirmed, dtapart`) și nu e pachet protejat (`app, appex, framework, bundle, kext, plugin, prefpane, xpc, photoslibrary, musiclibrary, fcpbundle`);
   - nu există lângă el un fișier cu același nume + `.part`/`.crdownload`/`.download`/`.opdownload`;
   - e fișier obișnuit;
   - data adăugării în folder (`addedToDirectoryDate`, altfel data creării) e după `activeSince` al folderului (momentul adăugării/reactivării folderului);
   - nu e în lista `ignored` (fișiere readuse cu „Readu înapoi”);
   - cheia `cale|mărime|dată modificare` nu a fost deja evaluată.
5. Așteptare: fișierul trebuie să nu-și schimbe mărimea/data timp de `delaySeconds` (implicit 3 s, minim 1 s); fișierele de 0 octeți așteaptă minim 30 s.
6. `process`: întâi se extrag firmele din document (pentru tab-ul Firme, doar extensiile `pdf, xml, zip, doc, docx, xls, xlsx, odt, ods, rtf, txt`), apoi prima regulă potrivită decide.
7. Nu se mută dacă: nicio regulă nu se potrivește; destinația e goală; destinația este chiar folderul în care stă fișierul; destinația e într-un folder exclus (mesaj în bara de stare).
8. Mutarea: se creează folderul destinație, iar la nume existent se adaugă ` (2)`, ` (3)` etc. Se scrie o intrare în istoric.
9. Erorile de mutare apar ca mesaj de stare; fișierul e marcat evaluat și nu se reîncearcă până nu se schimbă.

În pauză (`settings.paused`) watcher-ele se opresc și `tick` nu face nimic. Fișierele venite între timp se procesează după repornire (dacă au `addedToDirectoryDate` după `activeSince`).

## Reguli

### Model

`SortRule`: `name`, `enabled`, `matchMode` (`all` = toate condițiile / `any` = oricare), `conditions[]`, `destination`, `rename`.
`RuleCondition`: `field` (`ext`, `name`, `content`, `nameOrContent`) + `keywords` (separate prin virgulă, punct și virgulă sau rând nou).

- Regulile se verifică de sus în jos; prima care se potrivește câștigă (`RuleMatcher.firstMatch`).
- O regulă fără nicio condiție completată nu se potrivește niciodată.
- În interiorul unei reguli, condițiile se verifică de la cea mai ieftină (extensie → nume → nume sau conținut → conținut), ca să nu se citească conținutul degeaba. Conținutul se citește o singură dată per fișier (`FileContext`).
- Extensie: listă fără punct; `*` = orice extensie.

### Sintaxa cuvintelor cheie (`KeywordPattern`)

Textul și cuvântul sunt normalizate: fără majuscule, fără diacritice, orice semn de punctuație devine spațiu.

| Scris | Înseamnă |
|---|---|
| `factura` | cuvânt întreg |
| `factur*` | începe cu (factura, facturi, facturare) |
| `*factura` | se termină cu |
| `*fact*` | oriunde |
| `12345678` (doar cifre) | număr întreg; se găsește și în `RO12345678`, nu și în `912345678` |

Mai multe cuvinte în aceeași condiție = ajunge unul.

### Destinație

- Relativă la folderul urmărit (ex. `Documente`, `Firme/X/{tipdoc}`) sau absolută (începe cu `/` sau `~`). Componentele `.`/`..` sunt ignorate în căile relative.
- Gol = fișierul rămâne pe loc (se folosește pentru excepții, puse deasupra).
- Variabile (`SortEngine.resolveDestination`):

| Variabilă | Valoare | Dacă lipsește |
|---|---|---|
| `{tipdoc}` | folderul tipului de document (plural, ex. Facturi, Contracte, Bancă) | `Altele` |
| `{firma}` | firma ta recunoscută | `Fără firmă` |
| `{partener}` | partenerul de pe document | `Necunoscut` |
| `{an}`, `{luna}` | anul (4 cifre) și luna (2 cifre) din data documentului | data curentă (vezi riscuri) |
| `{tip}` | categoria extensiei din regulile inițiale (Imagini, Video, Documente…) | `Altele` |
| `{ext}` | extensia cu majuscule | `fara extensie` |

### Redenumire

Se face doar dacă regula are `rename = true`, setarea globală „Redenumește documentele mutate” e pornită și tipul documentului a fost recunoscut. Format: `Tip Număr – Partener – yyyy-MM-dd.ext` (numărul și partenerul doar dacă au fost găsite; partenerul nu apare dacă e identic cu firma proprie). Numărul: la e-Factura din `cbc:ID`; altfel din text (`NumberFinder`): „Seria X nr. Y” are prioritate, apoi „nr./număr/no.” lângă tipul documentului; se ignoră „nr.” precedat pe același rând de cuvinte de adresă, registru, telefon, cont etc. Numărul e scris cu majuscule, `/` devine `-`, maximum 20 de caractere.

**Redenumirea documentelor deja sortate** (`SortEngine.planRenames`, foaia `RenameExistingSheet`, din tab-ul Foldere sau din Setări): caută recursiv doar în partea fixă a destinațiilor regulilor active cu redenumire (ex. `Firme/<firmă>/{tipdoc}` → `Firme/<firmă>`, în fiecare folder urmărit), fără foldere excluse. Arată lista „nume nou / nume actual”, redenumește doar ce e bifat, cu `execute` (intră în Istoric cu regula „Redenumire”, deci se poate anula). Nu schimbă numele care diferă doar prin majuscule. Caracterele `/` și `:` devin `-`; numele e tăiat la 150 de caractere.

### Regulile inițiale (`DefaultRules.all`)

Câte o regulă pe tip de fișier, destinația = numele grupului (subfolder în folderul urmărit). Doar „Documente” are redenumirea pornită.

| Regulă / folder | Extensii |
|---|---|
| Imagini | jpg, jpeg, png, gif, heic, heif, webp, svg, tif, tiff, bmp, raw, cr2, nef, arw, dng |
| Video | mp4, mov, m4v, avi, mkv, webm, wmv, mpg, mpeg, 3gp |
| Audio | mp3, wav, m4a, aac, flac, ogg, aiff, aif, opus, wma |
| Documente | pdf, doc, docx, odt, rtf, txt, pages, md, epub |
| Tabele | xls, xlsx, xlsm, csv, tsv, ods, numbers |
| Prezentări | ppt, pptx, odp, key |
| XML | xml, json |
| Arhive | zip, rar, 7z, tar, gz, tgz, bz2, xz |
| Instalare | dmg, pkg, iso, exe, msi |
| Design | psd, ai, eps, sketch, fig, indd, afdesign, afphoto |
| Fonturi | ttf, otf, woff, woff2 |

### Regula unei firme

Creată la „E firma mea” (`DefaultRules.company`): mod `all`, condiții `Extensia este` = `pdf, xml, zip, doc, docx, xls, xlsx, odt, rtf, txt, jpg, jpeg, png, heic` și `Numele sau conținutul conține` = `CUI, nume normalizat`; destinație `Firme/<Nume>/{tipdoc}`; redenumire pornită. Se inserează după ultima regulă cu destinația `Firme/…` (sau prima, dacă nu există), deci deasupra regulilor pe tipuri. Numele și CUI-urile firmelor nu sunt în cod: se găsesc în documente sau se adaugă manual (cerință, repo-ul e public).

## Analiza documentelor (`DocumentAnalyzer`)

Rulează doar când regula cere redenumire sau folosește `{firma}`, `{tipdoc}`, `{partener}` (și în „Testează un fișier”).

1. **e-Factura**: dacă XML-ul brut (fișier .xml sau XML din .zip) conține `AccountingSupplierParty` și `Invoice`/`CreditNote`, tipul = Factură, firma și partenerul se iau din `AccountingSupplierParty` / `AccountingCustomerParty` (`RegistrationName`/`Name`, `CompanyID`), data din `IssueDate`.
2. **Tipul** (`DocTypes.detect`): scor pe expresii; în nume ×6, în primele 700 de caractere ×4, în rest ×1; prima expresie a fiecărui tip cântărește dublu. Prag minim 4.
3. **Firma ta**: prima firmă din „Firmele mele” ale cărei cuvinte apar în nume sau conținut.
4. **Partenerul**: rânduri care încep cu Furnizor, Vânzător, Prestator, Emitent, Cumpărător, Client, Beneficiar, Achizitor, Locator, Locatar, Comodant, Comodatar, Partener, Executant, plus rânduri cu SRL/SA/PFA; se alege primul nume care nu e al unei firme proprii. Numele se curăță (fără S.C., SRL, CUI, adresă etc., max 40 de caractere, majusculele transformate în Title Case).
5. **AI Apple** (opțional): doar dacă tipul nu a fost recunoscut, setarea e pornită, textul are minim 40 de caractere și modelul e disponibil. Primește primele 2.500 de caractere; răspunde tip (din lista fixă), partener, dată. Timeout 25 s.
6. **Data**: la poze = data descărcării; altfel se caută o dată (`zz.ll.aaaa`, `aaaa-ll-zz`, `zz lună aaaa`) lângă ancore specifice tipului (contracte: „începând cu data”, „intră în vigoare”…; facturi/proforme/chitanțe/avize/bonuri/NIR: „data emiterii”, „data facturii”, „din data”…; bancă: „perioada”, „de la”…); altfel prima dată din primele 3.000 de caractere; altfel data descărcării. Ani acceptați: 1990 – anul curent + 5.

### Tipuri de documente

| Tip (în nume) | Folder `{tipdoc}` | Expresii căutate |
|---|---|---|
| Proformă | Proforme | factura proforma, proforma |
| Factură | Facturi | factura fiscala, factura, invoice, e factura |
| Chitanță | Chitanțe | chitanta |
| Bon fiscal | Bonuri | bon fiscal |
| Aviz | Avize | aviz de insotire a marfii, aviz de insotire |
| NIR | NIR | nota de receptie si constatare de diferente, nota de receptie |
| Act adițional | Contracte | act aditional, actul aditional |
| Contract | Contracte | contract de, partile contractante, obiectul contractului, contractul, contract |
| Extras de cont | Bancă | extras de cont, sold initial, sold final, account statement |
| Ordin de plată | Bancă | ordin de plata |
| Ofertă | Oferte | oferta de pret, oferta comerciala, cotatie de pret, oferta |
| Comandă | Comenzi | nota de comanda, comanda de achizitie, purchase order, comanda |
| Somație | Somații | somatie, somatia |
| Decizie | Decizii | decizie, decizia |
| Proces-verbal | Procese-verbale | proces verbal, procesul verbal |
| Notificare | Notificări | notificare, instiintare |
| Declarație | Declarații | declaratie, declaratia |
| Certificat | Certificate | certificat, certificatul |
| Autorizație | Autorizații | autorizatie, autorizatia |
| Adeverință | Adeverințe | adeverinta |
| Stat de plată | Salarii | stat de plata, fluturas de salariu, fluturas |
| Cerere | Cereri | cerere, cererea |

La egalitate de scor câștigă tipul aflat mai sus în listă.

## Citirea conținutului (`ContentExtractor`)

| Tip | Cum | Limite / setare |
|---|---|---|
| PDF | text din PDFKit; dacă sub 20 de caractere → OCR Vision pe pagini randate (max 2.200 px, scară max 3) | primele `maxPages` pagini (implicit 3, 1–20); PDF cu parolă nu se citește; `readPDFText`, `ocrScannedPDFs` |
| Imagini (jpg, jpeg, png, heic, heif, tif, tiff, bmp, gif, webp) | OCR Vision, `accurate`, detectare automată a limbii, fără corectură | max 60 MB; sub 200×200 px se sare; `ocrImages` |
| docx/docm/dotx, xlsx/xlsm, pptx, odt/ods/odp | `unzip -p` pe XML-urile interne, tag-urile scoase | `readOfficeFiles` |
| doc, rtf | `NSAttributedString` | `readOfficeFiles` |
| txt, csv, tsv, md, json, log, eml, xml, html, htm, svg | citire directă (max 4 MB); XML/HTML/SVG fără tag-uri; .xml păstrat și brut pentru e-Factura | – |
| zip | `unzip -p` pe `*.xml, *.txt, *.csv, *.json` din arhivă | max 30 MB; `readArchives` |
| altele | nu se citesc | – |

Textul extras e tăiat la 300.000 de caractere.

## Firme găsite în documente

- La fiecare fișier nou procesat (și la „Caută în documentele existente”) se extrag părțile: din e-Factura direct, altfel din text: CUI-uri cu etichetă (CUI, CIF, Cod fiscal, Cod de identificare fiscală, Cod unic de înregistrare) sau cu prefix `RO`, validate cu cifra de control (cheia 753217532). Rolul (furnizor/client) se deduce din eticheta de deasupra; numele din același rând sau din rândul următor. Se citesc primele 250 de rânduri.
- Un document se numără o singură dată, după cheia `mărime|dată modificare` (rămâne la fel după mutare și redenumire). Se păstrează ultimele 5.000 de chei.
- Sugestii: firme cu minim 2 documente, nerespinse și care nu sunt deja în „Firmele mele” (comparare pe cifrele CUI). Ordonare după un scor (pondere în totalul documentelor ×2 + apariții ca client ×0,5 + documente ×0,05). Eticheta „pare a ta”: minim 3 documente și (≥ 30% din documente sau client în ≥ 2).
- „Caută în documentele existente” parcurge recursiv folderele urmărite active, cele mai noi primele, maxim 1.500 de documente.
- „E firma mea” adaugă firma (cuvinte cheie: CUI + nume normalizat) și creează regula ei.

## Curățenie (`CleanupScanner`)

- Parcurge recursiv folderele urmărite **active** (inclusiv subfolderele, fără fișiere ascunse, fără interiorul pachetelor, fără folderele excluse).
- **Dubluri**: grupare după mărime, apoi SHA-256 pe conținut. Grupurile sunt sortate după spațiul eliberabil. În interfață, toate exemplarele în afară de cel mai vechi sunt bifate implicit; la mutare rămâne cel puțin un exemplar din fiecare grup.
- **Installere vechi**: extensii `dmg, pkg, mpkg`, adăugate de mai mult de `installerDays` zile (implicit 30, 7–180).
- **Programare** (`AppState`): prima verificare la 2 minute după pornire, apoi la fiecare oră (ora locală a Mac-ului, fără cron). Căutarea de dubluri rulează dacă `autoDuplicateScan` e pornit și au trecut peste 12 ore de la ultima (ultima căutare e ținută doar în memorie, deci după fiecare repornire a aplicației se caută din nou). Verificarea installerelor rulează la fiecare oră dacă `askAboutInstallers` e pornit; dacă găsește, apare un dialog: „Mută la coș” / „Arată-mi lista” (amână 1 zi) / „Mai târziu” (amână 7 zile). Amânarea e în `UserDefaults`, cheia `installerSnoozeUntil`. Nimic nu rulează în pauză.
- Mutarea se face doar la Coș (`trashItem`), niciodată ștergere definitivă.

## Istoric și anulare

- Fiecare mutare (automată sau din „Sortează ce există”) → `HistoryEntry` (dată, nume original, cale veche, cale nouă, regulă). Se păstrează ultimele 1.000.
- „Readu înapoi” mută fișierul înapoi în folderul original, cu numele original (cu ` (2)` dacă e ocupat), și îl pune în `ignored`, ca să nu mai fie mutat automat. Căile din `ignored` care nu mai există se curăță la scanările complete.
- „Golește” șterge doar lista, nu fișierele.

## Date salvate (fără bază de date)

Toate în `~/Library/Application Support/Sortator/` (buton „Deschide” în Setări → Date):

| Fișier | Conținut |
|---|---|
| `config.json` | `AppConfig`: foldere urmărite, reguli, setări, foldere excluse, firmele mele, `version` (acum 2). Salvat la orice modificare |
| `history.json` | istoricul mutărilor (max 1.000) |
| `firme-gasite.json` | `DiscoveryStore`: firme găsite, chei de documente numărate, total documente |
| `engine-state.json` | `evaluated` (chei deja evaluate, max ~3.000, redus la 2.000) și `ignored` (fișiere readuse) |
| `config-rezerva-<timestamp>.json` | copie a unui `config.json` care nu a putut fi citit; aplicația pornește apoi cu configurația implicită |

Alte locuri: `UserDefaults` (domeniul `ro.mancaregatita.sortator`): `installerSnoozeUntil` și poziția ferestrei (`SortatorMainWindow`).

### Migrarea configurației

`AppConfig.migrate`: de la versiunea 1 la 2, regulile cu destinația `Firme/…` fără variabile primesc `/{tipdoc}` și redenumire; regula „Documente” primește redenumire; dacă lista de firme e goală, se construiește din regulile `Firme/…`. Câmpurile lipsă din JSON primesc valorile implicite (decodare tolerantă).

### Export / import reguli

Export: `Reguli Sortator.json` = lista de reguli. Import: acceptă o listă de reguli sau un obiect cu cheia `rules` (ex. un `config.json`); se generează ID-uri noi; „Adaugă la cele existente” (la final) sau „Înlocuiește toate regulile”.

## Foldere excluse

Implicit: `/Applications`, `~/Applications`, `/System`, `/Library`, `~/Library`. Un folder exclus (și tot ce e în el) nu e urmărit, nu e parcurs la curățenie și nu poate fi destinație. Un folder exclus nu poate fi adăugat ca urmărit. Cerință: folderele cu aplicații nu se ating niciodată; în plus, `.app` și celelalte pachete nu se mută niciodată.

## Permisiuni macOS

| Permisiune | De unde vine | Observații |
|---|---|---|
| Acces la Descărcări / Desktop / Documente | cerere macOS la primul acces (TCC); texte în `Info.plist` (`NSDownloadsFolderUsageDescription` etc.) | dacă e refuzată, citirea folderului eșuează fără mesaj (`scan` iese silențios) |
| Discuri externe / rețea | `NSRemovableVolumesUsageDescription`, `NSNetworkVolumesUsageDescription` | doar dacă se aleg astfel de foldere |
| Alte foldere alese cu „Adaugă folder…” | alegerea în panou | aplicația nu e în sandbox; nu salvează bookmark-uri. Nu are „Full Disk Access” în cod |
| Pornire la login | `SMAppService.mainApp.register()` | activă doar când aplicația rulează din `/Applications/`; dacă macOS cere aprobare, se deschide System Settings → Login Items |
| Apple Intelligence | FoundationModels | necesită macOS 26, Mac compatibil, Apple Intelligence pornit; altfel e ignorat |

Semnarea e ad-hoc, deci după un build nou macOS poate cere din nou permisiunile de foldere (identitatea aplicației se schimbă la fiecare build). Comportament de sistem, nu se vede în cod.

## Build, rulare locală, instalare, actualizare

Nu există variabile de mediu, secrete, chei API sau fișiere `.env`.

### Build în Xcode

1. Xcode 16 sau mai nou (formatul proiectului). Pentru AI-ul Apple și iconița `.icon`: Xcode 26 (SDK macOS 26). Cu Xcode mai vechi, codul din `AppleAI.swift` se compilează fără partea de AI (`#if canImport(FoundationModels)`).
2. Deschide `Sortator.xcodeproj`, schema `Sortator`, destinația „My Mac”.
3. Signing & Capabilities: lasă „Sign to Run Locally” (identitate `-`), fără Team. Nu e nevoie de cont Apple Developer.
4. Run (⌘R). Aplicația pornește din folderul de build (DerivedData) în configurația Release.

Din linia de comandă (echivalent, pe Mac):

```
xcodebuild -project Sortator.xcodeproj -scheme Sortator -configuration Release build
```

### Instalare

În aplicație: Setări → Pornire → „Mută în Aplicații” (`installInApplications`): închide copia care rulează din `/Applications`, șterge `/Applications/Sortator.app`, copiază bundle-ul curent, pornește copia nouă și închide copia din build. Apoi se poate bifa „Pornește automat la deschiderea Mac-ului”.

La pornire, aplicația închide orice altă instanță cu același bundle ID (`quitOtherInstances`), deci rulează mereu o singură copie.

### Actualizare

Manuală (actualizările automate Sparkle și publicarea prin GitHub Actions au fost scoase în commit-ul `33dc182`): Pull în Xcode → Run → Setări → „Mută în Aplicații”. Datele din Application Support rămân.

### Deploy

Nu există deploy pe server. Nu există CI, cron-uri sau joburi externe; singurele activități periodice sunt timerele interne (motor la 2 s, scanare completă la 30 s, curățenie la o oră).

### Teste

Nu există target de teste sau teste automate în repo. Verificare manuală: tab Reguli → „Testează un fișier…” arată regula aleasă, destinația, numele propus, tipul, firma, partenerul, data, metoda de citire și textul extras (primele 4.000 de caractere), fără să mute nimic.

## Integrări externe și legături cu alte aplicații

- Nu folosește Shopify, Supabase, Cloudflare, Vercel, Expo sau alte servicii. Nu face cereri de rețea.
- AI-ul Apple și OCR-ul rulează local pe Mac.
- Nu are legături de date cu celelalte aplicații (Producția, Logistica, Tesa, clienti-chefs etc.).
- Singura legătură: CRM proiecte (`crm`, crm.foodistoffice.workers.dev) citește `README.md` și `docs/*.md` din acest repo pentru documentație.

## Limite, riscuri și datorie tehnică observată

- **Doar primul nivel al folderului** e urmărit; fișierele puse direct în subfoldere nu se sortează (curățenia, în schimb, e recursivă).
- **`{an}`/`{luna}` fără redenumire**: data documentului se calculează doar dacă regula are redenumire sau folosește `{firma}`/`{tipdoc}`/`{partener}`. O regulă care folosește doar `{an}`/`{luna}` pune anul/luna curentă, deși textul de ajutor din editor spune „din data documentului”.
- **„Revino la regulile inițiale”**: dialogul spune „firmele și tipurile de fișiere”, dar `DefaultRules.all` conține doar regulile pe tipuri; regulile firmelor se pierd (firmele din „Firmele mele” rămân). Se recomandă export înainte.
- **AI-ul Apple blochează coada motorului** până la 25 s per document nerecunoscut (semafor), timp în care nu se procesează alte fișiere.
- **Permisiune refuzată = nicio eroare vizibilă**: dacă macOS refuză accesul la folder, aplicația nu afișează nimic, doar nu mută.
- **`lastDuplicateScan` nu e salvat**: după fiecare repornire, căutarea de dubluri rulează din nou la 2 minute.
- **Două iconițe numite `AppIcon`** (`AppIcon.icon` și `Assets.xcassets/AppIcon.appiconset`); care dintre ele e folosită depinde de versiunea Xcode, neclar din cod.
- **Semnare ad-hoc, fără Hardened Runtime/notarizare**: aplicația nu poate fi distribuită altor Mac-uri fără avertismente Gatekeeper; e gândită pentru uz pe Mac-ul propriu.
- **Fără teste automate.**
- Istoric limitat la 1.000 de intrări; scanarea firmelor la 1.500 de documente; chei evaluate la ~3.000.
- `CompanyRow` (tab Firme) e definit în `SettingsView.swift`, nu în `CompaniesView.swift`.

## Istoric și note existente

| Fișier / sursă | Despre ce e |
|---|---|
| `README.md` (versiunea anterioară) | pornire în Xcode și descrierea funcțiilor; conținutul a fost mutat în `docs/UTILIZARE.md` și în acest fișier |
| commit `33dc182` | singurul commit din istoric: scoaterea actualizărilor automate (Sparkle) și a publicării prin GitHub Actions; actualizarea devine manuală |

Nu există alte fișiere `ACTUALIZARE-*`, `CITESTE-MA-*`, `GHID-*` sau `AGENTS.md` în repo.
