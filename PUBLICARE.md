# Publicare și actualizări automate

Fiecare versiune nouă se construiește, se semnează cu Developer ID, se notarizează la Apple și se publică singură în **Releases**. Aplicațiile instalate verifică la 6 ore și se actualizează în fundal.

## Configurare (o singură dată)

### 1. Repo public
GitHub → repo `sortare-fisiere` → **Settings** → **General** → jos, la **Danger Zone** → **Change repository visibility** → **Make public**.

### 2. Certificatul Developer ID Application (doar Account Holder)
1. Xcode → **Settings…** → **Accounts** → selectezi echipa → **Manage Certificates…** → **+** → **Developer ID Application**.
   (Alternativ, din [Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources) → **Certificates** → **+** → **Developer ID** → **Developer ID Application**.)
2. **Keychain Access** → **login** → **My Certificates** → click dreapta pe „Developer ID Application: …” → **Export…** → format `.p12` → alegi o parolă.
3. În Terminal: `base64 -i ~/Desktop/NumeFisier.p12 | pbcopy` — textul e acum copiat, pentru secretul `DEVELOPER_ID_P12`.

### 3. Cheia API App Store Connect (pentru notarizare)
App Store Connect → **Users and Access** → **Integrations** → **App Store Connect API** → **Team Keys** → **Generate API Key** (sau **+**) → nume „Sortator” → **Access: Developer** → **Generate** → **Download API Key** (fișierul `.p8` se poate descărca o singură dată). Notezi **Key ID** (în listă) și **Issuer ID** (deasupra listei).

### 4. Team ID
[developer.apple.com/account](https://developer.apple.com/account) → **Membership details** → **Team ID**.

### 5. Secretele în GitHub
Repo → **Settings** → **Secrets and variables** → **Actions** → **New repository secret**, câte unul:

| Nume | Ce pui |
|---|---|
| `DEVELOPER_ID_P12` | textul copiat la pasul 2.3 |
| `DEVELOPER_ID_P12_PASSWORD` | parola aleasă la export |
| `APPLE_TEAM_ID` | Team ID |
| `ASC_KEY_ID` | Key ID |
| `ASC_ISSUER_ID` | Issuer ID |
| `ASC_KEY_P8` | tot conținutul fișierului `.p8` (deschis în TextEdit) |
| `SPARKLE_ED_PRIVATE_KEY` | cheia de semnare a actualizărilor (primită separat) |

## O versiune nouă
- Automat: o etichetă `v1.2` urcată în repo pornește publicarea.
- Manual: tab-ul **Actions** → **Publicare versiune** → **Run workflow** → versiunea.

Prima instalare pe un Mac: din **Releases** descarci `Sortator-<versiune>.zip`, îl deschizi și tragi Sortator în Aplicații. De atunci se actualizează singur.
