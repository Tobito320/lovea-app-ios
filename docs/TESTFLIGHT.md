# Lovea zu TestFlight bringen

Der Workflow `.github/workflows/testflight.yml` baut die App auf GitHub. Er lädt sie dann zu TestFlight hoch.
Er startet nur von Hand. Vorher braucht er acht Secrets im Repo.

Wichtig: Passwörter tippst du selbst ein. Kein Agent gibt ein Passwort ein.

## 1. App in App Store Connect anlegen

Das machst du einmal.

1. Öffne https://developer.apple.com/account/resources/identifiers.
2. Lege eine App ID an. Bundle ID: `com.onlyus.lovea` (Explicit).
3. Öffne https://appstoreconnect.apple.com → Apps → Plus → Neue App.
4. Plattform iOS. Name `Lovea`. Bundle ID `com.onlyus.lovea`. SKU zum Beispiel `lovea`.

## 2. Die acht Secrets

Alle Befehle laufen in PowerShell. Du brauchst die GitHub CLI (`gh auth login`).
`gh secret set` fragt nach dem Wert, wenn keiner übergeben wird. Dann tippst oder fügst du ihn selbst ein.

### DEVELOPMENT_TEAM

Deine Team ID. Zehn Zeichen, zum Beispiel `AB12CD34EF`.
Du findest sie unter https://developer.apple.com/account → Membership details → Team ID.

```powershell
gh secret set DEVELOPMENT_TEAM --repo Tobito320/lovea-app-ios
```

### APPLE_CERT_P12_BASE64

Dein Apple Distribution Zertifikat mit privatem Schlüssel, als .p12 Datei.

Weg A, mit einem Mac:

1. Öffne https://developer.apple.com/account/resources/certificates.
2. Plus → Apple Distribution. Lade eine CSR aus der Schlüsselbundverwaltung hoch.
3. Lade das Zertifikat herunter. Doppelklick installiert es.
4. Schlüsselbundverwaltung → Meine Zertifikate → Apple Distribution → Rechtsklick → Exportieren → `lovea.p12`.
5. Vergib dabei ein Passwort. Das brauchst du gleich für `APPLE_CERT_PASSWORD`.

Weg B, nur Windows (openssl, zum Beispiel aus Git Bash):

```bash
openssl genrsa -out lovea.key 2048
openssl req -new -key lovea.key -out lovea.csr -subj "/emailAddress=DEINE@MAIL.de/CN=Ahmed/C=DE"
```

1. Lade `lovea.csr` unter Certificates → Plus → Apple Distribution hoch.
2. Lade `distribution.cer` herunter und lege sie neben `lovea.key`.
3. Baue die .p12 Datei. openssl fragt nach einem Export-Passwort. Das tippst du selbst.

```bash
openssl x509 -inform DER -in distribution.cer -out distribution.pem
openssl pkcs12 -export -legacy -inkey lovea.key -in distribution.pem -out lovea.p12
```

Ohne `-legacy` kann macOS die Datei nicht lesen. Die Datei `lovea.key` gut aufheben und nicht ins Repo legen.

Secret setzen:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("lovea.p12")) | gh secret set APPLE_CERT_P12_BASE64 --repo Tobito320/lovea-app-ios
```

### APPLE_CERT_PASSWORD

Das Passwort der .p12 Datei. Du tippst es selbst ein, wenn der Befehl fragt.

```powershell
gh secret set APPLE_CERT_PASSWORD --repo Tobito320/lovea-app-ios
```

### APPSTORE_PROFILE_BASE64

Das Provisioning Profile für den App Store.

1. Öffne https://developer.apple.com/account/resources/profiles.
2. Plus → Distribution → App Store Connect.
3. App ID `com.onlyus.lovea` wählen. Das Apple Distribution Zertifikat von oben wählen.
4. Name zum Beispiel `Lovea App Store`. Herunterladen als `Lovea_App_Store.mobileprovision`.

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("Lovea_App_Store.mobileprovision")) | gh secret set APPSTORE_PROFILE_BASE64 --repo Tobito320/lovea-app-ios
```

Der Workflow liest den Namen selbst aus dem Profil.

### ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_P8_BASE64

Ein API-Schlüssel für App Store Connect. Damit lädt der Workflow hoch.

1. Öffne https://appstoreconnect.apple.com → Benutzer und Zugriff → Integrationen → App Store Connect API.
2. Unter Teamschlüssel: Plus. Name `GitHub Lovea`. Zugriff: App Manager.
3. Lade die Datei `AuthKey_XXXXXXXXXX.p8` herunter. Das geht nur einmal.
4. Die Schlüssel-ID steht in der Tabelle. Die Issuer ID steht oben über der Tabelle.

```powershell
gh secret set ASC_KEY_ID --repo Tobito320/lovea-app-ios
gh secret set ASC_ISSUER_ID --repo Tobito320/lovea-app-ios
[Convert]::ToBase64String([IO.File]::ReadAllBytes("AuthKey_XXXXXXXXXX.p8")) | gh secret set ASC_KEY_P8_BASE64 --repo Tobito320/lovea-app-ios
```

### LOVEA_APP_KEY

Der App-Schlüssel für den Server. Zufällig erzeugt, 32 Byte als Hex. Derselbe Wert steht auch als
Worker-Secret `LOVEA_APP_KEY` (siehe [`README.md`](../README.md) Abschnitt „Server“). Lokal liegt
er in `signing/lovea-app.key`, nicht im Repo.

```powershell
(Get-Content signing\lovea-app.key -Raw).Trim() | gh secret set LOVEA_APP_KEY --repo Tobito320/lovea-app-ios
```

Prüfen, ob alle acht da sind:

```powershell
gh secret list --repo Tobito320/lovea-app-ios
```

## 3. Workflow starten

Das Actions-Budget für private Repos ist zurzeit aufgebraucht. Deshalb laufen CI und TestFlight
derzeit mit kurzzeitig öffentlich gestelltem Repo: erst öffentlich stellen, Workflow laufen lassen,
danach wieder zurück auf privat.

```powershell
gh repo edit Tobito320/lovea-app-ios --visibility public --accept-visibility-change-consequences
gh workflow run testflight.yml --repo Tobito320/lovea-app-ios
gh run watch --repo Tobito320/lovea-app-ios
gh repo edit Tobito320/lovea-app-ios --visibility private --accept-visibility-change-consequences
```

Fehlt ein Secret, bricht der erste Schritt ab. Er nennt dann die fehlenden Namen.
Die Build-Nummer ist die Laufnummer des Workflows. Sie steigt also von selbst.

Nach dem Hochladen prüft Apple den Build. Das dauert meist 5 bis 30 Minuten.
Danach steht er in App Store Connect → Apps → Lovea → TestFlight.
Beim ersten Build fragt Apple nach der Exportkonformität. Lovea nutzt keine eigene Verschlüsselung, also "Keine".

## 4. Annika als Testerin einladen

Annika wird interne Testerin. Dafür braucht sie einen Zugang zu deinem Team.

1. App Store Connect → Benutzer und Zugriff → Plus.
2. Annikas Apple-ID-Mail eintragen. Rolle: Marketing oder Kundensupport reicht.
3. Annika nimmt die Einladung per Mail an.
4. App Store Connect → Apps → Lovea → TestFlight → Interne Tests → Plus → neue Gruppe, zum Beispiel `Wir`.
5. Annika zur Gruppe hinzufügen. Den Build zur Gruppe hinzufügen.
6. Annika installiert die App TestFlight auf ihrem iPhone oder iPad und öffnet die Einladung.

Neue Builds landen danach automatisch bei ihr.
