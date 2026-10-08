# Lovea-MCP für KI-Agenten

Nur-Lese-Werkzeuge, damit Claude oder Codex Lovea-Fehler mit echten Daten statt Vermutungen untersuchen.
Server: `server/mcp.mjs` (stdio, keine Abhängigkeit). Worker-Seite: `GET /agent/*` in `server/raum.js` + `server/agent.js`.
Kein WebSocket, darum keine Präsenz-Meldung beim Partner.

## Werkzeuge
Alle nehmen `umgebung`: `test` (Standard) oder `live` (echte Daten von Ahmed und Annika).

| Werkzeug | Wofür |
|---|---|
| `lovea_statistik` | Erster Schritt: Ops je Art/Person (Anzahl, Bytes, letzte Zeit), Medien (unfertige Uploads), verbundene Sockets, Push-Token vorhanden, letzter Standort-Zeitpunkt, Merker-Schlüssel, DB-Größe. Keine Inhalte. |
| `lovea_ops` | Op-Log filtern: `art` (genau oder Präfix `gym.`), `von`, `seit` (seq), `ab`/`bis` (ISO), `suche`, `limit` 1-200, `aufsteigend`, `voll`. Inhalte über 2000 Zeichen gekürzt. Private Arten des anderen (Entwurf, Galerie) bleiben verborgen. |
| `lovea_merker` | Einen Server-Merker lesen. `spotify.token.*` gesperrt. |
| `lovea_messen` | Antwortzeiten: Worker+Raum, Raum+SQL, D1-Essen. Kalt, Median, p95, max. |
| `lovea_logs` | `wrangler tail` für 5-120 s mitschneiden (braucht `npm ci` in `server/` und Wrangler-Login). |

## Einrichten
- Claude Code im Repo: `.mcp.json` im Wurzelordner, beim ersten Start bestätigen.
- Schlüssel: `signing/lovea-app.key` des Haupt-Checkouts (Standardpfad in `mcp.mjs`), sonst `LOVEA_KEY_PFAD` setzen. Nie in Prompts oder Notizen kopieren.
- Andere URLs: `LOVEA_URL_TEST`, `LOVEA_URL_LIVE`.
- `live` braucht einen Worker-Deploy mit `agent.js`, sonst Fehler "/agent/* fehlt".

## Tests
`cd server && node --test`: `agent.test.js` (Abfragen), `raum.test.js` (Route ohne Präsenz), `mcp.test.js` (stdio gegen lokalen Worker).

## Später
Chat-Leistungsdaten aus der App: Plan in `docs/PERFORMANCE_MCP.md`; Werkzeuge kämen in denselben Server.
