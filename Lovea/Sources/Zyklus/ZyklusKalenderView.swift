import SwiftUI

struct ZyklusTagStatus: Equatable {
    var periode = false
    var vorhersage = false
    var fruchtbar = false
    var eisprung = false
    var log = false
}

enum ZyklusKalenderModus: Equatable {
    case eintragen, periodeStart, periodeEnde
}

/// Reine Kalender-Rechnung: Monatsraster, Tagesstatus, nachträgliche Perioden-Änderungen.
enum ZyklusKalenderLogik {
    static func monatsStart(_ tag: String) -> String {
        let k = Datum.kalender.dateComponents([.year, .month], from: Datum.datum(tag))
        return String(format: "%04d-%02d-01", k.year ?? 2000, k.month ?? 1)
    }

    static func monatVerschieben(_ monat: String, um schritte: Int) -> String {
        let d = Datum.kalender.date(byAdding: .month, value: schritte, to: Datum.datum(monatsStart(monat)))!
        return Datum.text(d)
    }

    static func tagVerschieben(_ tag: String, um tage: Int) -> String {
        Datum.text(Datum.kalender.date(byAdding: .day, value: tage, to: Datum.datum(tag))!)
    }

    /// Wochen als Zeilen zu je 7 Zellen, Montag zuerst. Leere Zellen sind nil.
    static func raster(monat: String) -> [[String?]] {
        let start = Datum.datum(monatsStart(monat))
        let kal = Datum.kalender
        let tageImMonat = kal.range(of: .day, in: .month, for: start)?.count ?? 30
        let wochentag = kal.component(.weekday, from: start) // 1 = Sonntag
        let vorlauf = (wochentag + 5) % 7
        var zellen: [String?] = Array(repeating: nil, count: vorlauf)
        for i in 0..<tageImMonat { zellen.append(Datum.text(kal.date(byAdding: .day, value: i, to: start)!)) }
        while zellen.count % 7 != 0 { zellen.append(nil) }
        return stride(from: 0, to: zellen.count, by: 7).map { Array(zellen[$0..<$0 + 7]) }
    }

    static func status(_ id: String, logik: ZyklusLogik, tage: [String: ZyklusTag], heute: String) -> ZyklusTagStatus {
        let t = tage[id]
        let phase = logik.phase(am: id)
        var s = ZyklusTagStatus()
        s.periode = t?.blutung != nil
        s.vorhersage = !s.periode && phase == .periode && id >= heute
        s.fruchtbar = phase == .fruchtbar || phase == .eisprung
        s.eisprung = phase == .eisprung
        s.log = t.map { !$0.istLeer } ?? false
        return s
    }

    /// Periode beginnt an diesem Tag. Nil, wenn dort schon eine Blutung steht.
    static func startSetzen(_ id: String, tage: [String: ZyklusTag]) -> ZyklusTag? {
        ZyklusHeuteLogik.periodeStart(id, tage: tage)
    }

    /// Periode endet an diesem Tag: Tage vom Start bis hier bluten, spätere Blutungstage danach fallen weg.
    /// Gibt nur geänderte Tage zurück. Leer, wenn keine Periode davor liegt oder sie länger als 14 Tage her ist.
    static func endeSetzen(_ id: String, tage: [String: ZyklusTag], logik: ZyklusLogik) -> [ZyklusTag] {
        guard let start = logik.periodenStarts.last(where: { $0 <= id }),
              ZyklusHeuteLogik.tageBis(start, id) <= 14 else { return [] }
        var geaendert: [ZyklusTag] = []
        var tag = start
        while tag <= id {
            var t = tage[tag] ?? ZyklusTag(id: tag)
            if t.blutung == nil {
                t.blutung = .leicht
                geaendert.append(t)
            }
            tag = tagVerschieben(tag, um: 1)
        }
        var n = 0
        while n < 14, var t = tage[tag], t.blutung != nil {
            t.blutung = nil
            geaendert.append(t)
            tag = tagVerschieben(tag, um: 1)
            n += 1
        }
        return geaendert
    }

    static func monatTitel(_ monat: String) -> String {
        let stil = Date.FormatStyle(locale: Locale(identifier: "de_DE"), calendar: Datum.kalender, timeZone: Datum.kalender.timeZone)
        return Datum.datum(monat).formatted(stil.month(.wide).year())
    }

    static func tagBeschreibung(_ id: String, status s: ZyklusTagStatus) -> String {
        var teile = [Datum.anzeige(id)]
        if s.periode { teile.append("Periode") }
        if s.vorhersage { teile.append("Periode erwartet") }
        if s.eisprung { teile.append("Eisprung") } else if s.fruchtbar { teile.append("Fruchtbar") }
        if s.log { teile.append("Eintrag vorhanden") }
        return teile.joined(separator: ", ")
    }
}

/// Monatsraster mit Periode, Vorhersage, fruchtbarem Fenster, Eisprung und Logpunkten.
struct ZyklusKalenderView: View {
    let speicher: any ZyklusSpeicher
    let eintragBlatt: (String) -> AnyView
    let heute: String
    @State private var monat: String
    @State private var modus = ZyklusKalenderModus.eintragen
    @State private var blatt: ZyklusAuswahl?
    @State private var stand = 0
    @Environment(\.colorScheme) private var schema

    init(speicher: any ZyklusSpeicher, eintragBlatt: @escaping (String) -> AnyView, heute: String = Datum.text(Date())) {
        self.speicher = speicher
        self.eintragBlatt = eintragBlatt
        self.heute = heute
        _monat = State(initialValue: ZyklusKalenderLogik.monatsStart(heute))
    }

    var body: some View {
        ZStack {
            ZyklusHintergrund()
            ScrollView { inhalt.padding(.horizontal, 16).padding(.vertical, 12) }
        }
        .sheet(item: $blatt, onDismiss: { stand += 1 }) { a in eintragBlatt(a.id) }
    }

    var inhalt: some View {
        let _ = stand
        let logik = speicher.logik(heute: heute)
        let tage = speicher.tage
        return VStack(spacing: 16) {
            kopf
            ZyklusKarte {
                VStack(spacing: 6) {
                    wochentage
                    ForEach(Array(ZyklusKalenderLogik.raster(monat: monat).enumerated()), id: \.offset) { _, woche in
                        HStack(spacing: 4) {
                            ForEach(0..<7, id: \.self) { i in
                                if let id = woche[i] {
                                    zelle(id, status: ZyklusKalenderLogik.status(id, logik: logik, tage: tage, heute: heute))
                                } else {
                                    Color.clear.frame(maxWidth: .infinity, minHeight: 44)
                                }
                            }
                        }
                    }
                }
            }
            modusLeiste
            legende
        }
    }

    private var kopf: some View {
        HStack {
            Button { monat = ZyklusKalenderLogik.monatVerschieben(monat, um: -1) } label: {
                Image(systemName: "chevron.left").font(.title3.weight(.bold)).frame(width: 44, height: 44)
            }
            .accessibilityLabel("Vorheriger Monat")
            Spacer()
            Text(ZyklusKalenderLogik.monatTitel(monat))
                .font(.system(.title2, design: .rounded).weight(.heavy))
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Button { monat = ZyklusKalenderLogik.monatVerschieben(monat, um: 1) } label: {
                Image(systemName: "chevron.right").font(.title3.weight(.bold)).frame(width: 44, height: 44)
            }
            .accessibilityLabel("Nächster Monat")
        }
        .foregroundStyle(ZyklusFarbe.tinte(schema))
        .buttonStyle(.plain)
    }

    private var wochentage: some View {
        HStack(spacing: 4) {
            ForEach(["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"], id: \.self) { n in
                Text(n)
                    .font(.system(.caption, design: .rounded).weight(.bold))
                    .foregroundStyle(ZyklusFarbe.tinteLeise(schema))
                    .frame(maxWidth: .infinity)
            }
        }
        .accessibilityHidden(true)
    }

    private func zelle(_ id: String, status s: ZyklusTagStatus) -> some View {
        let nummer = Datum.kalender.component(.day, from: Datum.datum(id))
        let periodeTon = ZyklusPhasenTon.periode.farbe(schema)
        let eisTon = ZyklusPhasenTon.eisprung.farbe(schema)
        let fruchtTon = ZyklusPhasenTon.fruchtbar.farbe(schema)
        let gefuellt = s.periode
        return Button { tippen(id) } label: {
            ZStack {
                if s.periode {
                    Circle().fill(periodeTon)
                } else if s.eisprung {
                    Circle().fill(eisTon.opacity(0.3)).overlay(Circle().strokeBorder(eisTon, lineWidth: 2.5))
                } else if s.fruchtbar {
                    Circle().fill(fruchtTon.opacity(schema == .dark ? 0.35 : 0.22))
                }
                if s.vorhersage {
                    Circle().strokeBorder(periodeTon, style: StrokeStyle(lineWidth: 2, dash: [4, 3]))
                }
                if id == heute {
                    Circle().strokeBorder(ZyklusFarbe.himbeere.farbe(schema), lineWidth: 2.5).padding(-2)
                }
                Text("\(nummer)")
                    .font(.system(.callout, design: .rounded).weight(id == heute ? .heavy : .semibold))
                    .foregroundStyle(gefuellt ? ZyklusFarbe.aufHimbeere(schema) : ZyklusFarbe.tinte(schema))
                if s.log {
                    Circle()
                        .fill(gefuellt ? ZyklusFarbe.aufHimbeere(schema) : ZyklusFarbe.himbeere.farbe(schema))
                        .frame(width: 5, height: 5)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                        .padding(.bottom, 3)
                }
            }
            .padding(2)
            .frame(maxWidth: .infinity, minHeight: 44)
            .aspectRatio(1, contentMode: .fit)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(ZyklusKalenderLogik.tagBeschreibung(id, status: s))
    }

    private func tippen(_ id: String) {
        switch modus {
        case .eintragen:
            blatt = ZyklusAuswahl(id: id)
        case .periodeStart:
            if let t = ZyklusKalenderLogik.startSetzen(id, tage: speicher.tage) { speicher.setze(t) }
            modus = .eintragen
        case .periodeEnde:
            for t in ZyklusKalenderLogik.endeSetzen(id, tage: speicher.tage, logik: speicher.logik(heute: heute)) { speicher.setze(t) }
            modus = .eintragen
        }
        stand += 1
    }

    private var modusLeiste: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                modusChip("Eintragen", .eintragen)
                modusChip("Periode Start", .periodeStart)
                modusChip("Periode Ende", .periodeEnde)
            }
            if modus != .eintragen {
                Text(modus == .periodeStart ? "Tippe den ersten Tag deiner Periode." : "Tippe den letzten Tag deiner Periode.")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(ZyklusFarbe.tinteLeise(schema))
            }
        }
    }

    private func modusChip(_ titel: String, _ wert: ZyklusKalenderModus) -> some View {
        Button { modus = wert } label: { ZyklusChip(titel: titel, gewaehlt: modus == wert) }
            .buttonStyle(.plain)
    }

    private var legende: some View {
        let periodeTon = ZyklusPhasenTon.periode.farbe(schema)
        return ZyklusKarte {
            VStack(alignment: .leading, spacing: 8) {
                legendeZeile("Periode") { Circle().fill(periodeTon) }
                legendeZeile("Periode erwartet") { Circle().strokeBorder(periodeTon, style: StrokeStyle(lineWidth: 2, dash: [4, 3])) }
                legendeZeile("Fruchtbar") { Circle().fill(ZyklusPhasenTon.fruchtbar.farbe(schema).opacity(0.3)) }
                legendeZeile("Eisprung") { Circle().strokeBorder(ZyklusPhasenTon.eisprung.farbe(schema), lineWidth: 2.5) }
                legendeZeile("Eintrag vorhanden") { Circle().fill(ZyklusFarbe.himbeere.farbe(schema)).padding(5) }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func legendeZeile<F: View>(_ titel: String, @ViewBuilder _ form: () -> F) -> some View {
        HStack(spacing: 10) {
            form().frame(width: 18, height: 18)
            Text(titel)
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(ZyklusFarbe.tinte(schema))
        }
    }
}
