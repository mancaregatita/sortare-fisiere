# Sortator

Aplicație de Mac (bara de meniu) care mută automat fișierele noi din folderele urmărite (ex. Descărcări) în subfoldere, după reguli: tipul fișierului, cuvinte din nume sau din conținut (PDF, OCR pe scanări și poze, Word, Excel, XML e-Factura din arhive .zip).

## Pornire

1. Deschide `Sortator.xcodeproj` în Xcode.
2. Apasă **Run** (⌘R). Iconița apare în bara de meniu de sus, iar la prima pornire se deschide fereastra.
3. În **Setări → Pornire**, apasă **Mută în Aplicații**. Aplicația se copiază în /Applications și repornește de acolo; apoi poți bifa **Pornește automat la deschiderea Mac-ului**.

La prima accesare a folderului Descărcări, macOS cere permisiunea: apasă **Allow / Permite**.

## Cum funcționează

- **Foldere urmărite**: doar fișierele care apar după activare sunt mutate automat. Pentru ce exista deja: **Sortează ce există…** arată lista înainte să mute ceva.
- **Foldere excluse**: nu sunt atinse niciodată (implicit Aplicații, Librărie, Sistem). Subfolderele și aplicațiile (.app) nu se mută niciodată.
- **Reguli**: se verifică de sus în jos; prima care se potrivește decide. Destinație goală = fișierul rămâne pe loc (excepție).
- **Redenumire**: documentele recunoscute primesc numele `Dată – Firmă – Tip – Partener` (ex. `2026-11-03 – Firma Mea – Factură – Furnizor Exemplu.pdf`). Data: la contracte data de început, la facturi data emiterii, la poze data descărcării. e-Factura (XML/ZIP din SPV) se citește direct din date.
- **Tip document**: Factură, Proformă, Chitanță, Contract, Extras de cont, Ofertă, Decizie etc. În destinații: `{tipdoc}`, `{firma}`, `{partener}`. AI-ul Apple (macOS 26) e folosit doar ca rezervă.
- **Curățenie**: dubluri (conținut identic) — bifezi ce merge la coș; installere .dmg/.pkg mai vechi de 30 de zile — aplicația te întreabă.
- **Istoric**: orice mutare se poate anula cu **Readu înapoi** (revine și numele original).
- **Testează un fișier…** (tab Reguli): arată ce regulă s-ar aplica și ce text a citit aplicația, fără să mute nimic.

Setările, regulile și istoricul sunt în `~/Library/Application Support/Sortator/`.
