# Erstbefuellung ueber mehrere Tage

`taeglich.ps1` laedt die Open-Food-Facts-CSV einmalig nach `%LOCALAPPDATA%\LoveaEssen\products.csv.gz`
und importiert davon taeglich eine Portion in `lovea-essen-live` (und einmalig eine kleine
Stichprobe in `lovea-essen-test`), gesteuert ueber `stand.json` im selben Ordner. Phase 1
(`--nur-gescannt`) laedt die gescannten Produkte, Phase 2 (`--nur-ungescannt`) nur die restlichen
DACH-Produkte, damit nichts doppelt geschrieben wird.
Grund: Cloudflare D1 Free zaehlt die 100.000 geschriebenen Zeilen/Tag pro Account, nicht pro
Datenbank (developers.cloudflare.com/d1/platform/pricing). Taeglicher Windows-Task "Lovea Essen
Import" (04:30), Stop: `Unregister-ScheduledTask -TaskName "Lovea Essen Import" -Confirm:$false`.
