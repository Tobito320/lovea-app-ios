#requires -version 7
# Taeglicher Import-Lauf fuer die Erstbefuellung von lovea-essen (Cloudflare D1 Free: 100.000
# geschriebene Zeilen/Tag PRO ACCOUNT, nicht pro Datenbank - siehe erstbefuellung-report.md).
# Deshalb: live bekommt die volle Tagesportion (30.000 Produkte x ~3 Zeilen = ~90.000 Zeilen),
# test bekommt nur einmalig eine kleine feste Stichprobe (2.000 Produkte), nicht taeglich neu.
param()

$ErrorActionPreference = "Stop"
$datenDir = "$env:LOCALAPPDATA\LoveaEssen"
$csv = Join-Path $datenDir "products.csv.gz"
$standDatei = Join-Path $datenDir "stand.json"
$logDatei = Join-Path $datenDir "log.txt"
$importDir = $PSScriptRoot
$taskName = "Lovea Essen Import"
$CSV_URL = "https://static.openfoodfacts.org/data/en.openfoodfacts.org.products.csv.gz"
$liveMax = 30000

New-Item -ItemType Directory -Force -Path $datenDir | Out-Null

function Log($text) {
    $zeile = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $text"
    Add-Content -Path $logDatei -Value $zeile
    Write-Host $zeile
}

# Eine lokale Kopie der CSV, damit Zeilenreihenfolge und --start-Indizes ueber alle Tage stabil bleiben.
# Erst in .part laden, dann umbenennen: sonst wuerde ein abgebrochener Download eine
# unvollstaendige Datei hinterlassen, die Test-Path trotzdem als "vorhanden" durchgehen laesst.
if (-not (Test-Path $csv)) {
    $teil = "$csv.part"
    Log "lade CSV einmalig nach $csv"
    try {
        Invoke-WebRequest -Uri $CSV_URL -OutFile $teil -UserAgent "Lovea-Import/1.0 (privat)"
        Move-Item $teil $csv -Force
    } catch {
        Remove-Item $teil -ErrorAction SilentlyContinue
        throw
    }
}

if (Test-Path $standDatei) {
    $stand = Get-Content $standDatei -Raw | ConvertFrom-Json
} else {
    $stand = [pscustomobject]@{ phase = "gescannt"; start = 0; test_fertig = $false }
}

if ($stand.phase -eq "fertig") {
    Log "fertig - nichts mehr zu tun, melde geplante Aufgabe ab"
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
    exit 0
}

$nurGescannt = @()
if ($stand.phase -eq "gescannt") { $nurGescannt = @("--nur-gescannt") }

function RunImport($db, $start, $max) {
    $pyArgs = @("importieren.py", "voll", $csv, "--db", $db, "--start", $start, "--max", $max) + $nurGescannt
    Log "starte: python $($pyArgs -join ' ')"
    Push-Location $importDir
    try {
        $roh = & python @pyArgs 2>&1
    } finally {
        Pop-Location
    }
    $roh | ForEach-Object { Log "  $_" }
    return [pscustomobject]@{ zeilen = $roh; exit = $LASTEXITCODE }
}

function SpeichereStand { $stand | ConvertTo-Json | Set-Content -Path $standDatei }

# Live: volle Tagesportion. Bricht importieren.py mitten drin ab (z. B. Tageslimit erreicht), retten
# wir den Fortschritt konservativ aus den "gesamt"-Zwischenzeilen (print(gesamt, flush=True) je
# Haeppchen): die reine Schreibmenge ist immer <= der echten "gesehen"-Zaehlung, ein Neustart dort
# wiederholt hoechstens ein paar bereits geschriebene Produkte (idempotent per ON CONFLICT), ueberspringt
# aber nie ungeschriebene.
try {
    $live = RunImport "lovea-essen-live" $stand.start $liveMax
    $treffer = $live.zeilen | Select-String -Pattern '^fertig (\d+) naechster start (\d+)$' | Select-Object -Last 1
    if ($live.exit -ne 0 -or -not $treffer) {
        $letzteZahl = $live.zeilen | Where-Object { $_ -match '^\d+$' } | Select-Object -Last 1
        $teilweise = if ($letzteZahl) { [int]$letzteZahl } else { 0 }
        $stand.start = $stand.start + $teilweise
        SpeichereStand
        throw "importieren.py fehlgeschlagen (live, exit=$($live.exit)) - Teilfortschritt gespeichert (start=$($stand.start))"
    }
    $geschrieben = [int]$treffer.Matches[0].Groups[1].Value
    $naechsterStart = [int]$treffer.Matches[0].Groups[2].Value

    # Test: nur einmal insgesamt eine kleine feste Stichprobe, nicht jeden Tag neu.
    if (-not $stand.test_fertig) {
        $test = RunImport "lovea-essen-test" 0 2000
        if ($test.exit -ne 0) { throw "importieren.py fehlgeschlagen (test, exit=$($test.exit))" }
        $stand.test_fertig = $true
    }

    if ($geschrieben -lt $liveMax) {
        # Phase ausgeschoepft: weniger geschrieben als angefordert heisst, die CSV ist fuer diesen Filter zu Ende.
        if ($stand.phase -eq "gescannt") {
            Log "Phase 'gescannt' ausgeschoepft ($geschrieben Produkte) - wechsle zu Phase 'dach'"
            $stand.phase = "dach"
            $stand.start = 0
        } else {
            Log "fertig: Phase 'dach' ausgeschoepft ($geschrieben Produkte) - melde geplante Aufgabe ab"
            $stand.phase = "fertig"
            $stand.start = 0
            Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
        }
    } else {
        $stand.start = $naechsterStart
    }

    SpeichereStand
    Log "Lauf fertig: Phase=$($stand.phase) geschrieben=$geschrieben naechster-start=$($stand.start)"
} catch {
    Log "FEHLER: $_"
    throw
}
