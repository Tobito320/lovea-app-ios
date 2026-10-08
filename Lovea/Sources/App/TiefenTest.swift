import Foundation

/// Tiefentest (XCUITest-Suite in `Lovea/UITests/TiefenTest*`): Start mit `-tiefentest`.
/// Der "Test-Raum" ist rein lokal: kein Server, kein Netz, keine echten Daten. Die Person kommt aus
/// `-tiefentestPerson ahmed|annika|keine` (statt Schlüsselbund), `-tiefentestNeu YES` löscht vorher
/// alle lokalen Daten, und der Partner bekommt ein paar Beispiel-Ops, damit keine Ansicht leer startet.
enum TiefenTest {
    static var aktiv: Bool { ProcessInfo.processInfo.arguments.contains("-tiefentest") }

    /// Nil = Argument fehlt (normaler Start). "keine" = bewusst ohne Person (Erststart-Test).
    private static var personArgument: String? { UserDefaults.standard.string(forKey: "tiefentestPerson") }

    /// `.some(nil)`: Test will ohne Person starten; `nil`: Schlüsselbund gilt.
    static var personUeberschreibung: Person?? {
        guard aktiv, let wert = personArgument else { return nil }
        return .some(Person(rawValue: wert))
    }

    /// Ganz am Anfang von `LoveaApp.init`: frischer Zustand pro Testlauf.
    static func vorbereiten() {
        guard aktiv, UserDefaults.standard.bool(forKey: "tiefentestNeu") else { return }
        UserDefaults.standard.removeObject(forKey: "lovea.ersterStartFertig")
        let dateien = FileManager.default
        for ordner in [FileManager.SearchPathDirectory.applicationSupportDirectory, .documentDirectory, .cachesDirectory] {
            guard let basis = dateien.urls(for: ordner, in: .userDomainMask).first,
                  let inhalt = try? dateien.contentsOfDirectory(at: basis, includingPropertiesForKeys: nil) else { continue }
            for url in inhalt { try? dateien.removeItem(at: url) }
        }
    }

    private struct NachrichtD: Encodable { let id: String; let text: String }
    private struct SchritteD: Encodable { let datum: String; let anzahl: Int }
    private struct TreffenD: Encodable { let datum: String; let uhrzeit: String; let wasMachenWir: String }

    /// Beispiel-Ops des Partners (und eigene Schritte), nur in die Faltungen, nie in Warteschlange oder Netz.
    @MainActor
    static func einspielen(ich: Person) {
        guard aktiv else { return }
        let partner = ich.partner
        let jetzt = Date()
        let heute = Datum.text(jetzt)
        let treffen = Datum.text(jetzt.addingTimeInterval(5 * 86_400))
        func op<T: Encodable>(_ id: String, _ art: String, _ d: T, von: Person, vor: TimeInterval = 0) -> Op {
            let daten = (try? JSONEncoder().encode(d)) ?? Data("{}".utf8)
            return Op(id: "tiefentest-\(id)", seq: nil, art: art, von: von, zeit: jetzt.addingTimeInterval(-vor), d: daten)
        }
        Raum.shared.lokalEinspielen([
            op("n1", "nachricht.neu", NachrichtD(id: "tiefentest-n1", text: "Hallo aus dem Test-Raum"), von: partner, vor: 3_600),
            op("n2", "nachricht.neu", NachrichtD(id: "tiefentest-n2", text: "Wie war dein Tag? Das ist eine etwas längere Nachricht, damit der Zeilenumbruch in der Blase geprüft wird."), von: partner, vor: 1_800),
            op("n3", "nachricht.neu", NachrichtD(id: "tiefentest-n3", text: "Bis später"), von: partner, vor: 600),
            op("s1", "schritte.setzen", SchritteD(datum: heute, anzahl: 6_543), von: partner),
            op("s2", "schritte.setzen", SchritteD(datum: heute, anzahl: 4_210), von: ich),
            op("t1", "treffen.setzen", TreffenD(datum: treffen, uhrzeit: "18:00", wasMachenWir: "Kino"), von: partner),
        ])
    }
}
