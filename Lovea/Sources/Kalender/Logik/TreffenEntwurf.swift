import Foundation

/// Z-42.2: was der Treffen-Tag zeigt (`jetzt`) oder zuletzt geladen bzw. gesendet hat (`basis`).
/// Gesendet wird nur, was davon abweicht: Verlassen ohne Änderung überschreibt nie die Änderung
/// des Partners mit altem Text, und ein leeres „Was machen wir" legt kein Treffen an.
struct TreffenEntwurf: Equatable {
    /// „Was machen wir", ohne Leerzeichen am Rand.
    var text = ""
    /// „HH:mm", nil = ohne Uhrzeit.
    var uhrzeit: String?
    var notiz = ""

    /// Die `treffen.setzen`-Op, falls Text oder Uhrzeit von `basis` abweichen.
    func treffen(_ datum: String, seit basis: TreffenEntwurf) -> TreffenD? {
        guard !text.isEmpty, text != basis.text || uhrzeit != basis.uhrzeit else { return nil }
        // "" nimmt eine gesetzte Uhrzeit zurück; nil hieße „Uhrzeit bleibt" (so sendet „Machen wir").
        return TreffenD(datum: datum, uhrzeit: uhrzeit ?? (basis.uhrzeit == nil ? nil : ""), wasMachenWir: text)
    }

    /// Die eigene Notiz für `notiz.setzen`, falls sie von `basis` abweicht.
    func neueNotiz(seit basis: TreffenEntwurf) -> String? {
        notiz == basis.notiz ? nil : notiz
    }
}
