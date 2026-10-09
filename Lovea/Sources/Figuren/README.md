# Figuren/FigurView*

`FigurView.swift` wurde rein mechanisch geteilt (keine Logikaenderung). `Zeichner` ist ein Typ, seine Methoden liegen in `extension Zeichner` ueber mehrere Dateien; gespeicherte Felder und `init` stehen in `FigurViewZeichner.swift`.

| Typ / Inhalt | Datei |
|---|---|
| `FigurExtra`, `PaarHand`, `PaarEbene`, `Umarmung`, `FigurView` | `FigurView.swift` |
| Zeichen-Helfer (`P`, `kreis`, `teil`, ...), `Pal`, `Arm`, `Bein`, `Mund`, `Auge`, `NeuesGesicht`, `VForm`, `Aermel`, `Haltung`, `Masse` | `FigurViewHelfer.swift` |
| `Zeichner`: Felder, `init`, Zeit, `zeichne`, Zubehoer, Kopfgruppe | `FigurViewZeichner.swift` |
| `Zeichner`: Rumpf, Koerper, Oberteil, Marken, Jacke, Arm | `FigurViewZeichnerKoerper.swift` |
| `Zeichner`: Gesicht, Augen, Nase, Mund, Bart | `FigurViewZeichnerGesicht.swift` |
| `Zeichner`: Haare, Kopfschmuck, Brille, Muetze | `FigurViewZeichnerHaare.swift` |
| `Zeichner`: Pose, Hintergrund, Requisiten | `FigurViewZeichnerPose.swift` |
| `Zeichner`: Effekte, Mimik-Effekte, Abzeichen | `FigurViewZeichnerEffekte.swift` |
| `Zeichner`: Ganzkoerper (Masse, Beine, Hose, Schuhe, Rumpf) | `FigurViewGanz.swift` |
| `Zeichner`: Ganzkoerper-Pose, Szene, Tablett, Auto, Scooter | `FigurViewGanzPose.swift` |
| `Zeichner`: Frisuren Runde 3 (`Striche`) | `FigurViewHaarstile.swift` |
| `Zeichner`: Gym-Uebungen, Extras | `FigurViewGymExtras.swift` |
| `AlleOptionenVorschau`, `#Preview` | `FigurViewVorschau.swift` |
| `Zeichner`: neue Gesichter, Naehe (Partner-Arm und Hand) | `FigurViewGesichterNeu.swift` |

Zugriffsstufen: frueher `private`/`fileprivate` fuer Typen und Funktionen auf Dateiebene sind jetzt internal, weil sie ueber Dateigrenzen genutzt werden.
