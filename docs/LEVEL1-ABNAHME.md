# Lovea – Level 1 Abnahme auf dem Gerät

Für Ahmed und Annika. Auf dem echten iPad mit Apple Pencil durchgehen. Jeden Schritt abhaken.
Klappt etwas nicht: Schritt-Nummer und was passiert ist notieren.

Vorher: Profil → **Leistungsanzeige** einschalten. Sie zeigt oben rechts im Studio fps, den
langsamsten Frame der letzten 2 Sekunden (CPU), die GPU-Zeit und den freien Speicher.

## Ablauf (Roadmap Abschnitt 7)

- [ ] 1. Annika öffnet Zeichnen.
- [ ] 2. Sie erstellt ein Projekt.
- [ ] 3. Sie erstellt darin eine neue Zeichnung.
- [ ] 4. Sie importiert ein echtes Foto aus Fotos.
- [ ] 5. Sie nutzt „Als Schablone“.
- [ ] 6. Das Foto liegt unten, ist transparent und gesperrt.
- [ ] 7. Sie zeichnet mit Apple Pencil auf einer neuen Ebene darüber.
- [ ] 8. Druck verändert den Strich sauber.
- [ ] 9. Sie nutzt einen anderen Pinsel.
- [ ] 10. Sie nimmt eine Farbe mit der Pipette auf.
- [ ] 11. Sie erstellt mehrere Ebenen.
- [ ] 12. Sie ordnet Ebenen neu.
- [ ] 13. Sie ändert die Deckkraft.
- [ ] 14. Sie nutzt Clipping oder Alpha Lock.
- [ ] 15. Sie nutzt mindestens einen Mischmodus.
- [ ] 16. Sie wählt einen Bereich per Lasso.
- [ ] 17. Sie verschiebt, dreht und skaliert ihn.
- [ ] 18. Sie macht Rückgängig und Wiederholen.
- [ ] 19. Sie schließt die Zeichnung.
- [ ] 20. Sie öffnet sie erneut und alles ist noch da.
- [ ] 21. Sie exportiert das fertige Bild als PNG.

## Zusätzlich prüfen

- [ ] Hand liegt auf dem Display, es entsteht kein Strich (Palm Rejection).
- [ ] Doppeltippen auf den Pencil wechselt Pinsel und Radierer (oder was in den Einstellungen gewählt ist).
- [ ] Pencil drücken (Squeeze, Pencil Pro) öffnet das Schnellmenü.
- [ ] Pencil über dem Display schweben lassen zeigt den Pinselkreis (iPad mit Hover).
- [ ] Mit zwei Fingern tippen = Rückgängig, mit drei Fingern tippen = Wiederholen.
- [ ] Langer Druck mit einem Finger nimmt eine Farbe auf, eine Lupe zeigt sie.
- [ ] Nach einer langen Zeichnung mit vielen Ebenen gibt es keinen kurzen Freeze beim Zeichnen.

## Leistungsziele

Ziel aus dem Masterplan: 8,3 ms pro Frame bei 120 Hz, 16,7 ms bei 60 Hz. Die Werte beim Zeichnen
auf einer 2048²-Leinwand mit 10 Ebenen ablesen. Einmal mit Glas, einmal ohne (Schalter „Glas“ in
der Leistungsanzeige).

| Gerät | Bildrate | fps | CPU max (ms) | GPU (ms) | RAM frei (MB) | mit Glas | ohne Glas |
|---|---|---|---|---|---|---|---|
| iPhone 14 (Annika) | 60 Hz | | | | | | |
| iPhone 16 Pro Max (Ahmed) | 120 Hz | | | | | | |
| iPad (Annika) | | | | | | | |

Kostet das Glas mehr als 1 ms pro Frame, bleibt der Schalter aus. Dann wird es im Code durch
`.regularMaterial` ersetzt.
