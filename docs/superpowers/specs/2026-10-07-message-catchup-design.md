# Nachrichten nach App-Start und Mitteilung nachholen

Stand: 07.10.2026. Ahmed hat den Entwurf im Gespräch freigegeben. Diese Spezifikation beschreibt den ersten, schnellen Lovea-Fix. Die Ursache ist anhand des Codes plausibel, auf einem betroffenen Gerät noch nicht nachgewiesen.

## Problem und Befund

Eine Push-Mitteilung kann vor der zugehörigen Nachricht in der App erscheinen. Beim Öffnen der App oder Tippen auf die Mitteilung soll der Chat fehlende Nachrichten vom Server laden. Heute setzt `Raum.verbinden()` den Status `verbunden` bereits nach `URLSessionWebSocketTask.resume()`, ohne eine Antwort abzuwarten. `Raum.start()` und `Raum.nachholenBisFertig()` kehren bei `verbunden == true` früh zurück. Ein stumm gewordener Socket kann daher einen erneuten Abruf verhindern. Der bestehende Ping-Wächter entdeckt den Ausfall erst später.

Der Server in `server/raum.js` unterstützt `nachholen` mit einem Sequenz-Cursor und markiert die Antwort mit `seite: true`. Der Client speichert in `empfangenBisSeq` nur vollständig empfangene Nachhol-Seiten. Live-Broadcasts dürfen diesen Cursor nicht verschieben.

## Verhalten

- Beim aktiven Öffnen der App und beim Tippen auf eine Nachrichten-Mitteilung stößt `Raum` einmalig einen Nachhol-Abruf an. Ein stiller Push nutzt denselben Weg. Ein vermeintlich verbundener Socket verhindert diesen Abruf nicht.
- Der Abruf beginnt beim dauerhaft gespeicherten Cursor `vollstaendigBisSeq()`. Während einer laufenden Nachhol-Serie wird kein zweiter Abruf gestartet. Treffen Vordergrund und Mitteilungs-Tap zusammen, teilen sie denselben Abruf. Weitere Server-Seiten werden wie bisher bis `mehr == false` geladen.
- Bleibt eine angeforderte Nachhol-Seite 10 Sekunden lang aus, trennt `Raum` den Socket und verbindet neu. Die neue Verbindung fordert die fehlenden Ops ab dem letzten vollständig gesicherten Cursor an. Eine bloße `pong`-Antwort zählt nicht als Nachhol-Erfolg. Ein verspätetes Paket der alten Verbindung wird über die vorhandene Verbindungs-Generation ignoriert.
- Bleibt auch auf der neuen Verbindung die Nachhol-Seite aus, wird die Verbindung als gescheitert behandelt; die vorhandene Wiederverbindung mit Backoff bleibt zuständig. Die App zeigt keine neue Fehlermeldung. Keine wiederkehrende Hintergrund-Abfrage.
- Empfangene Ops bleiben über ihre vorhandenen IDs idempotent. Erst nach gesicherter Nachhol-Seite wird der Cursor vorgerückt. Das Tippen auf die Mitteilung öffnet den Chat weiterhin sofort; die Nachricht erscheint nach erfolgreichem Abgleich.

## Umsetzungskante

Der Fix sitzt in `Lovea/Sources/Sync/Raum.swift`, wo `start()`, `aktiv(_:)`, `nachholenBisFertig()` und der Socket-Empfang zusammenlaufen. `LoveaAppDelegate.swift` ruft beim Mitteilungs-Tap den neuen ereignisbezogenen Abruf an. Die vorhandene Server-Nachricht `nachholen` und das Op-Log werden wiederverwendet. Keine neue API, kein neuer Dienst, kein Polling.

## Prüfung und Freigabe

- `SyncTests.swift` mit Fake-Transport: Socket wirkt verbunden, Server sendet zunächst keine Seite; Vordergrund/Tap sendet `nachholen` mit gespeichertem Cursor; nach Frist folgt genau eine Neuverbindung. Verspätete alte Antwort erzeugt kein Duplikat.
- Regression: Verzögerte gültige Seite vor Frist verhindert Neuverbindung. `pong` allein verhindert sie nicht. Ein Live-Broadcast verschiebt den vollständigen Cursor nicht. Mehrseitiges Nachholen bleibt vollständig.
- Auf zwei echten Geräten mit gedrosseltem und unterbrochenem Netz prüfen: Nachricht senden, Mitteilung öffnen, App aus Hintergrund öffnen, fehlende Nachricht erscheint ohne manuellen Neustart und ohne doppelte Anzeige. Danach schnelle Netzverbindung und Akkuverhalten auf dem Weg Vordergrund/Hintergrund prüfen.
- Erst nach grünem CI, Review und erfolgreichem TestFlight-Build als erledigt markieren. Für GitHub Actions das Repo nur während des Builds öffentlich halten und danach wieder privat schalten.

## Grenze

Push-Zustellung selbst hängt weiterhin von iOS/APNs ab. Dieser Fix stellt sicher, dass ein Öffnen der App die auf dem Server gespeicherten Ops nachholt, auch wenn der Socket zuvor als verbunden galt.
