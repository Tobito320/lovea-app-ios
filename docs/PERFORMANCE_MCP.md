# Chat-Leistung: Remote-Daten und MCP (noch nicht gebaut)

Stand: Diagnose läuft **nur lokal** in der App (Einstellungen → Chat-Leistung).
Das Backend (`server/`, Cloudflare Worker, Op-Log über WebSocket) hat keinen Diagnose-Endpunkt.
Ein neuer Endpunkt plus Speicher wäre neue Infrastruktur, darum fehlt er absichtlich.

## Schnittstelle in der App
`ChatPerfUploader` (in `ChatPerfModell.swift`) nimmt `[ChatPerfTrace]`. Keine Implementierung.

## Vorgeschlagener Endpunkt
`POST /diagnostics/chat-performance` — gleiche Auth wie `/fl`, Body `{ "traces": [ChatPerfTrace] }`,
Batch ≤ 100, antwortet `204`. Upload asynchron, Fehler still ignorieren.
Speicherung: eigene D1-Tabelle `chat_perf` (Spalten = Felder von `ChatPerfTrace`, plus `person`).
Nie Nachrichtentext speichern.

## Read-only MCP-Tools (nur falls Daten vorhanden)
- `get_chat_performance_summary({ days?: int })` → `{ count, latestTotalMs, avgTotalMs, p50, p95, avgTapToRequest, avgRequestToResponse, avgResponseToRender, bottleneck }`
- `get_recent_chat_traces({ limit?: int ≤ 100 })` → `ChatPerfTrace[]`
- `get_conversation_performance({ conversationId })` → Summary für eine Unterhaltung

Keine Schreib-Tools, kein Zugriff auf Nachrichten oder andere Tabellen.

## Minimaler Plan
1. D1-Migration `chat_perf`. 2. Worker-Route mit Validierung. 3. `ChatPerfUploader` mit URLSession + Batch beim Öffnen der Diagnose-Seite.
4. Kleiner MCP-Server, der die drei Abfragen auf `chat_perf` ausführt.
