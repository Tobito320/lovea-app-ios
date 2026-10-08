# Lovea-MCP für KI-Agenten

Werkzeuge, damit Claude oder Codex Lovea-Fehler mit echten Daten statt Vermutungen untersuchen und Ahmeds Gym auswerten und planen.
Server: `server/mcp.mjs` (stdio, keine Abhängigkeit), Gym-Rechnungen in `server/gym.js`. Worker-Seite: `GET /agent/*` in `server/raum.js` + `server/agent.js`.
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

## Gym
Ahmeds echter Plan und seine Trainings liegen auf `live`. `person` ist `ahmed` (Standard) oder `annika`.
Katalog (`Lovea/Sources/Health/uebungen.json`) und Splits (`GymNeu/splits.json`) liest der Server lokal aus dem Repo.

| Werkzeug | Wofür |
|---|---|
| `lovea_gym_plan` | Aktueller Plan lesbar. `roh` = App-Form zum Ändern, `verlauf` = frühere Pläne mit `seq`. |
| `lovea_gym_trainings` | Einheiten neueste zuerst: Tag, Dauer, Sätze kg×Wdh, getauschte Übungen. `ab`, `limit`. |
| `lovea_gym_auswertung` | `wochen` 1-52: je Woche Trainings, Minuten, Sätze, Volumen, Sätze je Gruppe; diese Woche gegen Satzziele (`ziel.*`-Einstellungen, sonst Standard wie `KoerperZiele`); Erholung und Formerhalt nach Pause; je Übung e1RM-Verlauf (Epley), Plateau, Vorschlag fürs nächste Mal (wie `KoerperLogik.naechstesMal`); Plantreue; Kraftverhältnis der Langhantel-Grundübungen. |
| `lovea_gym_uebungen` | Katalog suchen (de/en), Filter `muskel`, `geraet`. Nur diese ids in Plänen. |
| `lovea_gym_splits` | Split-Vorlagen, mit `id` alle Einheiten. |
| `lovea_gym_plan_setzen` | Einzige Schreibstelle. Genau eins: `plan` (App-Form oder Kurzform `{uebung, saetze: 3, wdh: 10, kg}`), `split` (wie Split wählen in der App) oder `wiederherstellen` (seq). Ohne `anwenden` nur Prüfung und Unterschied. Mit `anwenden` eine `gym.plan`-Op über `POST /ops` (kein Push, App sieht es beim nächsten Verbinden). Schreibt nur für ahmed; Antwort nennt den Befehl zum Rückgängigmachen. |

Beispiele in Claude Code: "werte mein Gym der letzten 8 Wochen aus", "bau mir einen zweiten Push-Tag am Freitag mit Schulterfokus", "nimm Split m-ahmed03", "mach den Plan von gestern wieder her".

## Einrichten
- Claude Code im Repo: `.mcp.json` im Wurzelordner, beim ersten Start bestätigen.
- Schlüssel: `signing/lovea-app.key` des Haupt-Checkouts (Standardpfad in `mcp.mjs`), sonst `LOVEA_KEY_PFAD` setzen. Nie in Prompts oder Notizen kopieren.
- Andere URLs: `LOVEA_URL_TEST`, `LOVEA_URL_LIVE`.
- `live` braucht einen Worker-Deploy mit `agent.js`, sonst Fehler "/agent/* fehlt".

## Tests
`cd server && node --test`: `agent.test.js` (Abfragen), `raum.test.js` (Route ohne Präsenz), `gym.test.js` (Faltung, Auswertung, Planprüfung), `mcp.test.js` (stdio gegen lokalen Worker, auch Plan schreiben und wiederherstellen).

## Später
Chat-Leistungsdaten aus der App: Plan in `docs/PERFORMANCE_MCP.md`; Werkzeuge kämen in denselben Server.
