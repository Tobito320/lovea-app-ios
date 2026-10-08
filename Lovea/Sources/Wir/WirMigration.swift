import Foundation

/// Zieht die alte gemeinsame Wunschliste ("Unsere Liste", Ops `liste.setzen` / `liste.loeschen`) in die
/// Date-Ideen und die geteilten Notizen um. Nichts geht verloren: jeder Eintrag wird erst als Idee oder
/// Notiz gesendet, danach mit dem alten `liste.loeschen` aus der Liste genommen. Die alten Ops bleiben
/// unverändert im Log, `WirModell` faltet sie weiter wie bisher.
///
/// Feste IDs und fester Zeitstempel `stempel`: senden beide Handys (oder ein Handy zweimal), entstehen
/// dieselben Objekte, kein Duplikat. Jede echte Änderung danach (neuerer Zeitstempel) gewinnt, auch ein
/// Löschen. Ein Eintrag, den ein altes Handy später noch in die Liste schreibt, wird beim nächsten Lauf
/// mitgenommen.
enum WirMigration {
    /// 2026-10-08 00:00 UTC.
    static let stempel = Date(timeIntervalSince1970: 1_791_417_600)
    /// Ab dieser Länge (oder mit Zeilenumbruch) ist ein Eintrag zu lang für einen Idee-Titel: er wird Notiz.
    static let maxTitel = 80

    /// Ein alter Listen-Eintrag und das, was daraus wird (genau eins von `idee` und `notiz`).
    struct Schritt: Equatable {
        var listenId: String
        var idee: DateIdee?
        var notiz: WirNotiz?
    }

    static func ideeId(_ listenId: String) -> String { "idee-liste-" + listenId }
    static func notizId(_ listenId: String) -> String { "notiz-liste-" + listenId }

    /// Eine Zeile bis `maxTitel` Zeichen wird Date-Idee (geschafft = erledigt), alles andere Notiz.
    /// Einträge ohne Text bleiben stehen: es gibt nichts zu retten, und nichts wird gelöscht.
    static func plan(_ liste: [WirModell.ListenEintrag]) -> [Schritt] {
        liste.sorted(by: { $0.id < $1.id }).compactMap { eintrag in
            let text = eintrag.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return nil }
            if text.count <= maxTitel, !text.contains("\n") {
                let idee = DateIdee(
                    id: ideeId(eintrag.id), titel: text, kategorie: .aktivitaet, erledigt: eintrag.geschafft,
                    geaendert: stempel, von: eintrag.von
                )
                return Schritt(listenId: eintrag.id, idee: idee)
            }
            let rest = eintrag.geschafft ? "\n(geschafft)" : ""
            return Schritt(listenId: eintrag.id, notiz: WirNotiz(id: notizId(eintrag.id), text: text + rest, geaendert: stempel, von: eintrag.von))
        }
    }

    /// Reihenfolge je Eintrag: neues Objekt zuerst, dann Entfernen aus der Liste. Bricht etwas ab, bleibt
    /// der Eintrag in der Liste und kommt beim nächsten Lauf wieder dran.
    static func ops(_ plan: [Schritt], von ich: Person) -> [Op] {
        plan.flatMap { schritt -> [Op] in
            var ops: [Op] = []
            if let idee = schritt.idee { ops.append(Op.neu(DateSpeicher.art, idee, von: ich)) }
            if let notiz = schritt.notiz { ops.append(Op.neu(WirNotizLogik.art, notiz, von: ich)) }
            ops.append(Op.neu("liste.loeschen", ListeLoeschenD(id: schritt.listenId), von: ich))
            return ops
        }
    }
}

/// Körper von `liste.loeschen`, wie `MitId` in `WirModell`.
struct ListeLoeschenD: Codable { var id: String }
