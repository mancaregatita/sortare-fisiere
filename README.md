# Sortator

Aplicație de Mac (bara de meniu) care mută automat fișierele noi din folderele urmărite (ex. Descărcări) în subfoldere, după reguli: tipul fișierului, cuvinte din nume sau din conținut (PDF, OCR pe scanări și poze, Word, Excel, XML e-Factura din arhive .zip). Recunoaște tipul documentului și firmele, poate redenumi documentele `Dată – Firmă – Tip – Partener`, găsește dubluri și installere vechi. Rulează local, fără internet.

| | |
|---|---|
| Live / URL | nu are; aplicație locală, instalată în `/Applications/Sortator.app` |
| Cod | GitHub `mancaregatita/sortare-fisiere` (public) |
| Stack | Swift 5, SwiftUI + AppKit, macOS 14+, Xcode 16+ (Xcode 26 pentru AI-ul Apple) |
| Găzduire | Mac-ul propriu |
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
