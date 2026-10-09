import Foundation

/// Faltung der drei öffentlichen Punkt-Ops in `KalenderModell.Zustand`. Reihenfolgefrei, soweit es
/// zählt: `setzen` schlägt `platzhalter` (egal wer zuerst kommt), `loeschen` setzt einen Grabstein,
/// den spät eintreffende `setzen`/`platzhalter` nicht beleben.
enum TreffenAblauf {
    nonisolated static func anwenden(_ op: Op, in z: inout KalenderModell.Zustand) {
        switch op.art {
        case "treffen.punkt.setzen":
            guard let d = op.daten(PunktSetzenD.self), !z.geloeschtePunkte.contains(d.id) else { return }
            ersetzen(TreffenPunkt(
                id: d.id, datum: d.datum, von: op.von, start: d.start, ende: d.ende,
                titel: d.titel, notiz: d.notiz, ort: d.ort, versteckt: false, sichtbarAb: nil
            ), in: &z)
        case "treffen.punkt.platzhalter":
            guard let d = op.daten(PlatzhalterD.self), !z.geloeschtePunkte.contains(d.id) else { return }
            if z.punkte.values.contains(where: { liste in liste.contains { $0.id == d.id && $0.hatInhalt } }) { return }
            ersetzen(TreffenPunkt(
                id: d.id, datum: d.datum, von: op.von, start: d.start, ende: d.ende,
                titel: nil, notiz: nil, ort: nil, versteckt: true, sichtbarAb: TreffenZeit.datum(d.sichtbarAb) ?? op.zeit
            ), in: &z)
        case "treffen.punkt.loeschen":
            guard let d = op.daten(PunktLoeschenD.self) else { return }
            z.geloeschtePunkte.insert(d.id)
            for datum in z.punkte.keys { z.punkte[datum]?.removeAll { $0.id == d.id } }
        default:
            break
        }
    }

    /// Ein Punkt hat eine Id; ändert sich das Datum, wandert er in den neuen Tag.
    private nonisolated static func ersetzen(_ punkt: TreffenPunkt, in z: inout KalenderModell.Zustand) {
        for datum in z.punkte.keys { z.punkte[datum]?.removeAll { $0.id == punkt.id } }
        z.punkte[punkt.datum, default: []].append(punkt)
    }
}
