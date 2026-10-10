import SwiftUI

/// Bearbeitbare Kopie eines Tages. Zahlenfelder sind Text, solange getippt wird.
struct ZyklusEintragEntwurf: Equatable {
    var id: String
    var blutung: Blutung?
    var symptome: Set<Symptom> = []
    var stimmung: Set<Stimmung> = []
    var ausfluss: Ausfluss?
    var temperaturText = ""
    var eisprungTest: TestErgebnis?
    var schwangerschaftsTest: TestErgebnis?
    var sex: SexEintrag?
    var pille: Bool?
    var wasserMl: Int?
    var schlafMin: Int?
    var gewichtText = ""
    var notiz = ""

    init(id: String, tag: ZyklusTag? = nil) {
        self.id = id
        guard let tag else { return }
        blutung = tag.blutung
        symptome = tag.symptome
        stimmung = tag.stimmung
        ausfluss = tag.ausfluss
        temperaturText = Self.text(tag.temperatur, stellen: 2)
        eisprungTest = tag.eisprungTest
        schwangerschaftsTest = tag.schwangerschaftsTest
        sex = tag.sex
        pille = tag.pille
        wasserMl = tag.wasserMl
        schlafMin = tag.schlafMin
        gewichtText = Self.text(tag.gewicht, stellen: 1)
        notiz = tag.notiz ?? ""
    }

    var tag: ZyklusTag {
        let notizBereinigt = notiz.trimmingCharacters(in: .whitespacesAndNewlines)
        return ZyklusTag(
            id: id,
            blutung: blutung,
            symptome: symptome,
            stimmung: stimmung,
            ausfluss: ausfluss,
            temperatur: Self.zahl(temperaturText),
            eisprungTest: eisprungTest,
            schwangerschaftsTest: schwangerschaftsTest,
            sex: sex,
            pille: pille,
            wasserMl: wasserMl,
            schlafMin: schlafMin,
            gewicht: Self.zahl(gewichtText),
            notiz: notizBereinigt.isEmpty ? nil : notizBereinigt
        )
    }

    /// 36,6 und 36.6 gelten gleich. Leer, Unsinn und Werte bis 0 ergeben nil.
    static func zahl(_ text: String) -> Double? {
        let sauber = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        guard let wert = Double(sauber), wert.isFinite, wert > 0 else { return nil }
        return wert
    }

    static func text(_ wert: Double?, stellen: Int) -> String {
        guard let wert else { return "" }
        var text = String(format: "%.\(stellen)f", wert)
        while text.hasSuffix("0") { text.removeLast() }
        if text.hasSuffix(".") { text.removeLast() }
        return text.replacingOccurrences(of: ".", with: ",")
    }

    /// Schritt für Wasser und Schlaf. Bei 0 oder darunter wird der Wert wieder "nicht eingetragen".
    static func schritt(_ wert: Int?, delta: Int, grenze: Int) -> Int? {
        let neu = (wert ?? 0) + delta
        return neu <= 0 ? nil : min(neu, grenze)
    }

    @MainActor
    func speichern(in speicher: any ZyklusSpeicher) {
        speicher.setze(tag)
    }
}

/// Eintrag-Blatt für einen Tag. Änderungen bleiben im Entwurf; erst "Fertig" schreibt in den Speicher.
struct ZyklusEintragBlatt: View {
    let speicher: any ZyklusSpeicher
    let datum: String
    var schliessen: (() -> Void)?
    @State private var entwurf: ZyklusEintragEntwurf
    @Environment(\.dismiss) private var dismiss

    init(speicher: any ZyklusSpeicher, datum: String, schliessen: (() -> Void)? = nil) {
        self.speicher = speicher
        self.datum = datum
        self.schliessen = schliessen
        _entwurf = State(initialValue: ZyklusEintragEntwurf(id: datum, tag: speicher.tage[datum]))
    }

    var body: some View {
        ScrollView {
            ZyklusEintragInhalt(entwurf: $entwurf, datum: datum, fertig: fertig, abbrechen: zu)
        }
        .scrollDismissesKeyboard(.interactively)
        .tastaturFertig()
        .background(ZyklusHintergrund(deko: false).ignoresSafeArea())
    }

    private func fertig() {
        entwurf.speichern(in: speicher)
        zu()
    }

    private func zu() {
        if let schliessen { schliessen() } else { dismiss() }
    }
}

/// Der Inhalt ohne Scroll und Speicher, damit die Render-Tafel ihn zeichnen kann.
/// `fuerBild` ersetzt Textfelder durch Platzhalter-Zellen (ImageRenderer zeichnet sie nicht).
struct ZyklusEintragInhalt: View {
    @Binding var entwurf: ZyklusEintragEntwurf
    var datum: String
    var fertig: () -> Void = {}
    var abbrechen: () -> Void = {}
    var fuerBild = false
    @Environment(\.colorScheme) private var schema

    var body: some View {
        VStack(spacing: 14) {
            VStack(spacing: 4) {
                Text("Dein Tag")
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .foregroundStyle(ZyklusFarbe.tinte(schema))
                Text(Datum.anzeige(datum))
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(ZyklusFarbe.tinteLeise(schema))
            }
            abschnitt("Blutung") {
                ZyklusEinzelAuswahl(
                    optionen: Blutung.allCases.map { ZyklusAuswahlOption(wert: $0, titel: $0.eintragTitel) },
                    gewaehlt: $entwurf.blutung)
            }
            abschnitt("Symptome") { ZyklusSymptomeAuswahl(gewaehlt: $entwurf.symptome) }
            abschnitt("Stimmung") {
                ZyklusMehrfachAuswahl(
                    optionen: Stimmung.allCases.map { ZyklusAuswahlOption(wert: $0, titel: $0.eintragTitel) },
                    gewaehlt: $entwurf.stimmung)
            }
            abschnitt("Ausfluss") {
                ZyklusEinzelAuswahl(
                    optionen: Ausfluss.allCases.map { ZyklusAuswahlOption(wert: $0, titel: $0.eintragTitel) },
                    gewaehlt: $entwurf.ausfluss)
            }
            abschnitt("Temperatur") { feld("Morgens, in °C", text: $entwurf.temperaturText, einheit: "°C") }
            abschnitt("Eisprungtest") {
                ZyklusEinzelAuswahl(
                    optionen: TestErgebnis.allCases.map { ZyklusAuswahlOption(wert: $0, titel: $0.eintragTitel) },
                    gewaehlt: $entwurf.eisprungTest)
            }
            abschnitt("Schwangerschaftstest") {
                ZyklusEinzelAuswahl(
                    optionen: TestErgebnis.allCases.map { ZyklusAuswahlOption(wert: $0, titel: $0.eintragTitel) },
                    gewaehlt: $entwurf.schwangerschaftsTest)
            }
            abschnitt("Sex") {
                ZyklusEinzelAuswahl(
                    optionen: SexEintrag.allCases.map { ZyklusAuswahlOption(wert: $0, titel: $0.eintragTitel) },
                    gewaehlt: $entwurf.sex)
            }
            abschnitt("Pille") {
                ZyklusEinzelAuswahl(
                    optionen: [ZyklusAuswahlOption(wert: true, titel: "Genommen"), ZyklusAuswahlOption(wert: false, titel: "Vergessen")],
                    gewaehlt: $entwurf.pille)
            }
            abschnitt("Wasser") {
                schrittZeile(wert: $entwurf.wasserMl, schritt: 250, grenze: 6000, name: "Wasser") {
                    String(format: "%.2f l", Double($0) / 1000).replacingOccurrences(of: ".", with: ",")
                }
            }
            abschnitt("Schlaf") {
                schrittZeile(wert: $entwurf.schlafMin, schritt: 30, grenze: 960, name: "Schlaf") { "\($0 / 60) h \($0 % 60) min" }
            }
            abschnitt("Gewicht") { feld("Zum Beispiel 58,5", text: $entwurf.gewichtText, einheit: "kg") }
            abschnitt("Notiz") {
                if fuerBild {
                    platzhalter(entwurf.notiz.isEmpty ? "Was war heute noch?" : entwurf.notiz, hoehe: 70)
                } else {
                    TextField("Was war heute noch?", text: $entwurf.notiz, axis: .vertical)
                        .lineLimit(3...6)
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(ZyklusFarbe.tinte(schema))
                }
            }
            HStack(spacing: 12) {
                ZyklusKnopf(titel: "Abbrechen", leise: true, aktion: abbrechen)
                ZyklusKnopf(titel: "Fertig", symbol: "checkmark", aktion: fertig)
            }
        }
        .padding(16)
    }

    private func abschnitt<Inhalt: View>(_ titel: String, @ViewBuilder _ inhalt: @escaping () -> Inhalt) -> some View {
        ZyklusKarte {
            VStack(alignment: .leading, spacing: 10) {
                Text(titel)
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(ZyklusFarbe.tinte(schema))
                    .accessibilityAddTraits(.isHeader)
                inhalt()
            }
        }
    }

    private func platzhalter(_ text: String, hoehe: CGFloat = 44) -> some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(ZyklusFarbe.fliederweiss.farbe(schema).opacity(0.5))
            .frame(height: hoehe)
            .overlay(alignment: .leading) {
                Text(text)
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(ZyklusFarbe.tinteLeise(schema))
                    .padding(.horizontal, 12)
            }
    }

    @ViewBuilder
    private func feld(_ hinweis: String, text: Binding<String>, einheit: String) -> some View {
        if fuerBild {
            platzhalter(text.wrappedValue.isEmpty ? hinweis : "\(text.wrappedValue) \(einheit)")
        } else {
            HStack {
                TextField(hinweis, text: text)
                    .keyboardType(.decimalPad)
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(ZyklusFarbe.tinte(schema))
                    .padding(.horizontal, 12)
                    .frame(minHeight: 44)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(ZyklusFarbe.fliederweiss.farbe(schema).opacity(0.5)))
                Text(einheit)
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(ZyklusFarbe.tinteLeise(schema))
            }
        }
    }

    private func schrittZeile(wert: Binding<Int?>, schritt: Int, grenze: Int, name: String, anzeige: @escaping (Int) -> String) -> some View {
        HStack(spacing: 12) {
            knopf("minus", "\(name) weniger") { wert.wrappedValue = ZyklusEintragEntwurf.schritt(wert.wrappedValue, delta: -schritt, grenze: grenze) }
            Text(wert.wrappedValue.map(anzeige) ?? "Noch leer")
                .font(.system(.body, design: .rounded).weight(.semibold))
                .foregroundStyle(wert.wrappedValue == nil ? ZyklusFarbe.tinteLeise(schema) : ZyklusFarbe.tinte(schema))
                .frame(maxWidth: .infinity)
            knopf("plus", "\(name) mehr") { wert.wrappedValue = ZyklusEintragEntwurf.schritt(wert.wrappedValue, delta: schritt, grenze: grenze) }
        }
    }

    private func knopf(_ symbol: String, _ name: String, aktion: @escaping () -> Void) -> some View {
        Button(action: aktion) {
            Image(systemName: symbol)
                .font(.body.weight(.bold))
                .foregroundStyle(ZyklusFarbe.aufHimbeere(schema))
                .frame(width: 44, height: 44)
                .background(Circle().fill(ZyklusFarbe.himbeere.farbe(schema)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(name)
    }
}
