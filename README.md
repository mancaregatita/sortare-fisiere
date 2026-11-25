# Sortator

Aplicație de Mac (bara de meniu) care mută automat fișierele noi din folderele urmărite (Descărcări, iCloud Drive) în subfoldere cu nume în engleză (`Images`, `Documents`, `Firme/<firmă>/<an>/Invoices`…), după reguli: tipul fișierului, cuvinte din nume sau din conținut (PDF, OCR pe scanări și poze, Word, Excel, XML e-Factura din arhive .zip). Recunoaște tipul documentului și firmele, poate redenumi documentele `Tip Număr – Partener – Dată` (și pe cele deja sortate, cu previzualizare), găsește dubluri și installere vechi și anunță după o instalare că installerul se poate șterge. În iCloud Drive descarcă doar documentele pe care trebuie să le citească și eliberează spațiul după sortare. Proiectele Ableton se mută întregi, doar cu Ableton închis. Folderul `Keep` și folderele tale nu sunt atinse. Rulează local, fără internet.

| | |
|---|---|
| Live / URL | nu are; aplicație locală, instalată în `/Applications/Sortator.app` |
| Cod | GitHub `mancaregatita/sortare-fisiere` (public) |
| Stack | Swift 5, SwiftUI + AppKit, macOS 14+, Xcode 16+ (Xcode 26 pentru AI-ul Apple) |
| Găzduire | Mac-ul propriu (Mac mini-ul pornit permanent sortează iCloud Drive) |
| Bază de date | fără; fișiere JSON în `~/Library/Application Support/Sortator/` |
| Acces | doar utilizatorul Mac-ului pe care e instalată |
| Servicii externe | niciunul |

## Documentație

- [docs/UTILIZARE.md](docs/UTILIZARE.md) – ghid de folosire, ecran cu ecran, și „Când ceva nu merge”
- [docs/TEHNIC.md](docs/TEHNIC.md) – arhitectură, reguli, analiza documentelor, date salvate, permisiuni, build, riscuri

## Pornire rapidă

1. Deschide `Sortator.xcodeproj` în Xcode (schema `Sortator`, „My Mac”; semnare „Sign to Run Locally”, fără Team).
2. **Run** (⌘R). Iconița apare în bara de sus; la prima pornire se deschide fereastra.
3. În aplicație: **Setări → Pornire → Mută în Aplicații**, apoi bifează **Pornește automat la deschiderea Mac-ului**.
4. La primul acces la Descărcări, macOS cere permisiunea: **Allow / Permite**.

Din Terminal (pe Mac):

```
xcodebuild -project Sortator.xcodeproj -scheme Sortator -configuration Release build
```

## Deploy / actualizare

Nu există server sau deploy automat. Actualizare manuală: Pull în Xcode → **Run** → **Setări → Pornire → Mută în Aplicații**. Setările, regulile și istoricul rămân în `~/Library/Application Support/Sortator/`.
