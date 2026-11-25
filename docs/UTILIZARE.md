# Sortator – ghid de utilizare

## Ce face

Sortator stă în bara de sus a Mac-ului (lângă ceas) și pune ordine în folderele alese, de obicei Descărcări și iCloud Drive:

- fișierele noi sunt mutate automat în subfoldere, după reguli pe care le poți schimba:

  | Folder | Ce ajunge acolo |
  |---|---|
  | `Firme/<firmă>/<an>/Invoices · Contracts · Bank · Receipts · Certificates · Authorities · Other` | documentele firmelor tale |
  | `Images`, `Videos` | toate la un loc (le ordonezi în Finder după Modified) |
  | `Audio` | muzică și înregistrări |
  | `Documents` | orice document care nu ține de firme (PDF, Word, Excel, Pages, Numbers, Keynote, XML…) |
  | `Archives` | zip, rar, 7z… |
  | `Installers` | dmg, pkg, iso, exe… |
  | `Ableton Projects` | proiectele Ableton, mutate ca folder întreg, doar când Ableton e închis |
  | `Other` | fișiere de design și fonturi |
  | `Keep` | excepțiile tale: ce pui aici nu e atins niciodată |

- folderele tale (un repo dezarhivat, un proiect, orice folder pus în folderul urmărit) nu sunt mutate și nu sunt desfăcute; se mută doar fișiere și proiectele Ableton;
- citește și conținutul documentelor (PDF, poze și scanări, Word, Excel, e-Factura din SPV), deci recunoaște o factură chiar dacă numele fișierului nu spune nimic;
- poate redenumi documentele, în engleză și fără diacritice: `Tip Număr – Partener – Dată` (ex. `Invoice CHE 1234 – Furnizor Exemplu – 2026-11-03.pdf`); fără număr găsit: `Invoice – Furnizor Exemplu – 2026-11-03.pdf`;
- poate redenumi și documentele deja sortate: tab-ul **Foldere** → **Redenumește documentele sortate…** (sau din **Setări**), cu listă de previzualizare și bife; orice redenumire se anulează din **Istoric**;
- găsește singură firmele din documente și te întreabă care sunt ale tale;
- găsește dublurile și installerele vechi și te întreabă ce muți la Coș; după ce instalezi o aplicație, o notificare te întreabă dacă ștergi installerul;
- ține istoricul: orice mutare se poate anula.

Totul rulează pe Mac, fără internet. Nimic nu se șterge definitiv: ce alegi să arunci merge la Coș.

## Cine o folosește

Un singur utilizator, pe Mac-ul propriu. Aplicația nu are conturi și nu e legată de celelalte aplicații Chefs Evolution.

## Instalare (o singură dată)

1. Deschide `Sortator.xcodeproj` în Xcode și apasă **Run** (⌘R). Iconița apare în bara de sus, iar la prima pornire se deschide fereastra.
2. În **Setări → Pornire**, apasă **Mută în Aplicații**. Aplicația se copiază în Aplicații și repornește de acolo.
3. Tot acolo, bifează **Pornește automat la deschiderea Mac-ului**. Dacă macOS cere aprobare, se deschide singur ecranul din System Settings unde o aprobi.
4. La primul acces la Descărcări (sau Desktop, Documente), macOS întreabă dacă permiți. Apasă **Allow / Permite**.

## iCloud Drive pe Mac mini

Sortator rulează doar pe Mac mini-ul pornit permanent. Laptopul doar pune fișiere în iCloud Drive; mini-ul le sortează. Pe laptop, Sortator nu urmărește iCloud Drive (altfel ar sorta două Mac-uri aceleași fișiere).

1. Pe mini: System Settings → Apple Account → iCloud → iCloud Drive pornit; **Optimize Mac Storage** poate rămâne pornit.
2. Mini-ul rămâne logat și nu intră în sleep (System Settings → Energy: „Prevent automatic sleeping…”).
3. Build sau copiază Sortator pe mini, **Mută în Aplicații**, bifează pornirea automată.
4. Tab-ul **Foldere** → **Adaugă iCloud Drive**. Permite notificările și accesul la iCloud dacă macOS întreabă.
5. Pentru fișierele deja existente: **Reorganizare → Mută folderele vechi în structura nouă…**, apoi **Sortează ce există…**.

Cum lucrează cu spațiul:

- pozele, video-urile, arhivele, installerele și proiectele Ableton se mută fără să fie descărcate;
- documentele care sunt doar în iCloud (PDF, Word, Excel, XML, zip sub 30 MB, restul sub 100 MB) se descarcă pe rând ca să fie citite (firmă, tip, număr);
- la un minut după mutare, copia locală se șterge de pe mini; fișierul rămâne în iCloud și se descarcă singur când îl deschizi, pe orice device;
- ambele se pot opri din **Setări → iCloud Drive**.

## Actualizare

Nu se actualizează singură. Când există o versiune nouă: în Xcode faci Pull, apoi **Run**, apoi în aplicație **Setări → Pornire → Mută în Aplicații**. Regulile, firmele și istoricul rămân.

## Meniul din bara de sus

Click pe iconiță (săgeată în tavă; cerc cu pauză când e în pauză):

- câte foldere urmărește și ultimul lucru făcut;
- **Ultimele mutări** (5): click pe una o arată în Finder;
- **Firme de confirmat**, **Dubluri găsite**, **Installere vechi**: apar doar când e ceva de văzut;
- **Pune pe pauză / Repornește sortarea**;
- **Deschide Sortator…** (⌘,), **Istoric mutări…**, **Ieșire din Sortator** (⌘Q).

## Fereastra Sortator, tab cu tab

Jos, în fiecare tab, bara de stare arată Activ / În pauză, ultimul mesaj și comutatorul **Pauză**.

### Foldere

**Foldere urmărite**

- **Adaugă folder…** sau **Adaugă Descărcări**.
- Doar fișierele care apar **după** ce ai adăugat (sau reactivat) folderul sunt mutate automat. Ce era deja acolo rămâne neatins.
- **Sortează ce există…**: arată lista cu ce s-ar muta și unde, cu numele nou. Debifezi ce vrei să rămână, apoi **Mută**. Nu mută nimic înainte să confirmi.
- **Adaugă iCloud Drive** (apare doar dacă iCloud Drive e pornit pe Mac).
- Comutatorul **Activ** oprește/pornește un singur folder.
- Se mută doar fișierele aflate direct în folder (și pachetele Pages/Numbers/Keynote). Subfolderele și aplicațiile (.app) nu se mută niciodată; excepție: proiectele Ableton (folder cu `Ableton Project Info`), mutate întregi în `Ableton Projects` doar cât Ableton e închis.
- În fiecare folder urmărit se creează `Keep`: ce pui acolo nu e mutat, redenumit sau verificat la dubluri.
- **Reorganizare**:
  - **Mută folderele vechi în structura nouă…**: folderele în română (Imagini, Documente, Arhive, Instalare, Design, Fonturi, `Firme/<firmă>/Facturi`…) trec în cele noi (Images, Documents, `Firme/<firmă>/<an>/Invoices`…), iar numele documentelor redenumite trec în engleză. Arată lista înainte, muți doar ce e bifat, folderele vechi rămase goale se șterg. Se anulează din **Istoric**;
  - **Redenumește documentele sortate…**.

**Foldere excluse**

- Sortator nu atinge niciodată aceste foldere: nu ia fișiere din ele și nu pune fișiere în ele, chiar dacă o regulă ar trimite acolo.
- Implicit: Aplicații, Librărie, Sistem. **Exclude un folder…** adaugă altele; **Pune la loc excluderile inițiale** le readuce dacă le-ai scos.

### Reguli

- În stânga, lista regulilor, numerotată. **Se verifică de sus în jos; prima care se potrivește decide.** Dacă nu se potrivește niciuna, fișierul rămâne unde e.
- Butoane jos: **+** regulă nouă, **−** șterge, duplică, săgeți sus/jos (sau trage cu mouse-ul). Meniul **…**: Exportă regulile, Importă reguli, Revino la regulile inițiale.
- În dreapta, editorul regulii:
  - **Nume** și **Regula este activă**;
  - **Se aplică atunci când se potrivesc**: Toate condițiile sau Oricare condiție;
  - **Condiții**: Extensia este / Numele conține / Conținutul conține / Numele sau conținutul conține, urmate de cuvinte separate prin virgulă;
  - **Mută în**: subfolder al folderului urmărit (ex. `Documents`) sau orice folder de pe Mac (începe cu `~/` sau `/`). Butonul **Alege…** îl selectezi din Finder;
  - **Redenumește: Tip Număr – Partener – Dată**.
- **Testează un fișier…** (jos): alegi un fișier și vezi ce regulă s-ar aplica, unde ar merge, ce nume ar primi, ce tip/firmă/partener/dată a găsit și ce text a citit. Nu mută nimic.

**Cum scrii cuvintele**

| Scrii | Găsește |
|---|---|
| `factura` | cuvântul întreg „factura” (nu contează majusculele și diacriticele) |
| `factur*` | tot ce începe cu „factur”: factura, facturi, facturare |
| `*fact*` | „fact” oriunde |
| un CUI, ex. `12345678` | și scris cu RO în față |

**Variabile în „Mută în”**

| Scrii | Devine |
|---|---|
| `{tipdoc}` | Invoices, Contracts, Bank, Receipts, Certificates, Authorities (Other dacă nu recunoaște) |
| `{firma}` | firma ta de pe document |
| `{partener}` | cealaltă firmă de pe document |
| `{an}`, `{luna}` | anul și luna documentului (atenție: doar la regulile cu redenumire sau care folosesc și `{firma}`, `{tipdoc}` sau `{partener}`; altfel se pune luna curentă) |
| `{tip}` | Images, Videos, Documents… |
| `{ext}` | extensia, ex. PDF |

**Excepții**: o regulă cu „Mută în” gol lasă fișierul pe loc. Pune-o deasupra celorlalte.

**Regulile de la început**: câte una pe tip de fișier (Images, Videos, Audio, Documents, Archives, Installers, Ableton Projects, Other), fiecare în subfolderul cu același nume. Doar „Documents” are redenumirea pornită. Regulile firmelor se adaugă deasupra lor. La actualizarea din noiembrie 2026, regulile vechi în română au fost înlocuite automat; regulile tale și ale firmelor au rămas.

### Firme

**Firme găsite în documente**

- Sortator citește CUI-urile și numele firmelor din facturi, contracte și e-Factura. Firmele tale apar pe aproape toate documentele, mai ales ca client; acestea primesc eticheta **pare a ta**.
- Apar aici firmele găsite în cel puțin 2 documente.
- Poți corecta numele direct în listă, apoi:
  - **E firma mea**: o adaugă la Firmele mele și creează regula ei: documentele firmei merg în `Firme/<firmă>/<an>/<tip document>` (Invoices, Contracts, Bank…) și sunt redenumite;
  - **Nu e a mea**: dispare din listă (**Arată din nou firmele respinse** le readuce).
- **Caută în documentele existente**: citește documentele deja aflate în folderele urmărite (cele mai noi 1.500). Poate dura; se poate opri.

**Firmele mele**

- Nume + „Recunoscută după” (CUI și nume, separate prin virgulă). Se folosesc la „Firmă” din numele fișierului și ca să știe care e partenerul.
- **Adaugă o firmă manual** dacă nu a găsit-o singură.

### Curățenie

**Dubluri**: fișiere cu exact același conținut, din folderele create de Sortator (Images, Documents, Firme…) și din rădăcina folderelor urmărite. Folderele tale și `Keep` nu sunt verificate, nici fișierele aflate doar în iCloud (ar trebui descărcate). Cel mai vechi exemplar rămâne debifat; celelalte sunt bifate. Verifici, apoi **Mută la coș**. Din fiecare grup rămâne mereu cel puțin un exemplar.

**Installere vechi**: fișiere .dmg și .pkg mai vechi de 30 de zile (se schimbă în Setări). **Verifică acum**, bifezi, **Mută la coș**.

### Istoric

- Toate mutările (ultimele 1.000), cu căutare după nume, regulă sau folder.
- **Arată**: deschide fișierul în Finder.
- **Readu înapoi**: pune fișierul unde era, cu numele vechi, iar Sortator nu îl mai mută automat.
- **Golește**: șterge doar lista; fișierele rămân unde sunt.

### Setări

| Secțiune | Ce reglezi |
|---|---|
| Funcționare | Pauză; câte secunde așteaptă după ce un fișier nu se mai schimbă (implicit 3) |
| Citirea conținutului | PDF, OCR pe PDF scanate, OCR pe poze, Word/Excel/PowerPoint/OpenOffice, XML din arhive .zip, câte pagini citește din fiecare PDF (implicit 3) |
| Redenumire și tipul documentului | redenumirea pornită/oprită pentru toate regulile; AI-ul Apple ca rezervă (doar macOS 26 cu Apple Intelligence pornit; starea e afișată) |
| iCloud Drive | descarcă documentele doar din iCloud ca să le citească; eliberează spațiul după sortare |
| Curățenie | căutare automată de dubluri; notificare după instalare; întrebare despre installerele vechi; după câte zile un installer e „vechi” |
| Pornire | Mută în Aplicații; Pornește automat la deschiderea Mac-ului |
| Date | **Deschide** folderul cu setările, regulile și istoricul |

## Ce se întâmplă automat

- Fișierele noi din folderele urmărite se mută la câteva secunde după ce s-au terminat de descărcat. Descărcările în curs (.crdownload, .part etc.) sunt ignorate.
- La fiecare document nou, aplicația notează firmele găsite (pentru tab-ul Firme).
- La 2 minute după pornire și apoi la fiecare oră: caută dubluri (cel mult o dată la 12 ore) și verifică installerele vechi. Dacă găsește installere vechi, te întreabă: **Mută la coș**, **Arată-mi lista** (nu mai întreabă o zi) sau **Mai târziu** (nu mai întreabă o săptămână).
- La fiecare 10 minute verifică installerele deschise: dacă a apărut o aplicație nouă în Aplicații (sau au trecut 24 de ore de la deschidere), primești notificarea „Ai instalat X. Ștergi installerul?” cu **Șterge** (la Coș) și **Păstrează**. Funcționează doar pentru ce instalezi pe Mac-ul pe care rulează Sortator.
- În pauză nu se face nimic din toate acestea. Fișierele venite în pauză se sortează după ce repornești.

## Când ceva nu merge

| Ce vezi | Cauza probabilă | Ce faci |
|---|---|---|
| Nu se mută nimic | Aplicația e în pauză | Meniul de sus → **Repornește sortarea** (sau comutatorul Pauză din fereastră) |
| Nu se mută nimic dintr-un folder | macOS nu i-a dat acces la folder (mai ales după o actualizare din Xcode) | System Settings → Privacy & Security → Files & Folders → Sortator: pornește accesul la folderul respectiv. Apoi ieși și repornește Sortator |
| Fișierele vechi din folder nu se mută | Normal: se mută doar cele venite după adăugarea folderului | Foldere → **Sortează ce există…** |
| Un fișier rămâne pe loc | Nicio regulă nu se potrivește, sau regula are „Mută în” gol | Reguli → **Testează un fișier…** și vezi ce regulă se potrivește |
| Un fișier merge în alt folder decât te așteptai | O regulă mai de sus se potrivește prima | Mută regula dorită mai sus (săgeți sus/jos) |
| Mesaj „nu a fost mutat: regula … duce într-un folder exclus” | Destinația e în Foldere excluse | Schimbă destinația regulii sau scoate folderul din excluderi |
| Un fișier readus cu „Readu înapoi” nu mai e sortat | Normal: fișierele readuse nu se mai mută automat | Mută-l manual sau folosește **Sortează ce există…** |
| Documentul nu e redenumit | Nu a recunoscut tipul documentului, regula nu are redenumirea bifată, sau redenumirea e oprită în Setări | **Testează un fișier…** arată tipul găsit; verifică bifa din regulă și din Setări |
| Firma apare ca „No company” în folder | Firma nu e în **Firmele mele** sau CUI-ul/numele nu apar în document | Tab Firme → **E firma mea** sau adaug-o manual cu CUI |
| Factura scanată nu e recunoscută | OCR oprit sau scanare slabă | Setări → pornește OCR pe PDF scanate / poze; vezi textul citit în **Testează un fișier…** |
| Firma ta nu apare la „Firme găsite” | A apărut în mai puțin de 2 documente sau ai respins-o | **Caută în documentele existente** sau **Arată din nou firmele respinse**; ori adaug-o manual |
| „Pornește automat” nu se poate bifa | Aplicația rulează din Xcode, nu din Aplicații | Setări → Pornire → **Mută în Aplicații** |
| Pornirea automată nu ține | macOS așteaptă aprobarea | System Settings → General → Login Items: permite Sortator |
| AI-ul Apple „nu este disponibil” | Mac/macOS fără Apple Intelligence sau oprit | Nu e obligatoriu; recunoașterea principală merge oricum. Pentru AI: System Settings → Apple Intelligence & Siri |
| Am mutat ceva greșit | – | Istoric → **Readu înapoi**. Pentru ce a mers la Coș: deschide Coșul și alege Put Back |
| Am stricat regulile | – | Reguli → … → **Importă reguli…** dintr-un export anterior, sau **Revino la regulile inițiale…** (atenție: regulile firmelor se pierd; fă întâi un export) |
| Un fișier din iCloud stă pe loc câteva minute | Se descarcă încă de pe laptop, sau mini-ul îl descarcă ca să-l citească | Așteaptă; dacă nu are internet, rămâne până se descarcă (cel mult 10 minute de încercare, apoi se sortează după nume) |
| Un proiect Ableton nu se mută | Ableton e deschis | Normal: se mută după ce închizi Ableton |
| Un folder al meu nu e sortat | Normal: folderele nu se mută | Pune fișierele direct în folderul urmărit, sau lasă-l așa |
| Nu vine notificarea după instalare | Notificările Sortator sunt oprite, sau ai instalat pe alt Mac | System Settings → Notifications → Sortator: Allow. Pe laptop nu se vede instalarea |
| Am două iconițe Sortator în bara de sus | Rulează și copia din Xcode, și cea din Aplicații | La pornire aplicația o închide singură pe cealaltă; dacă persistă, **Ieșire din Sortator** din ambele și pornește-o din Aplicații |

## Unde sunt datele

Setările, regulile, firmele și istoricul sunt în `~/Library/Application Support/Sortator/` (Setări → Date → **Deschide**). Pentru o rezervă a regulilor: Reguli → … → **Exportă regulile…**.
