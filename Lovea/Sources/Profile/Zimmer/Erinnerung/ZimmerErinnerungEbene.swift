import SwiftUI

/// Unser Zimmer, Welle 2, Worker E: Wachsen und Erinnern. Sechs ruhige Dinge im Zimmer: Polaroid-Wand,
/// Liebesschlösser am Fenster, Balkon-Kasten, Schneekugel, Erinnerungs-Kisten unterm Bett und das
/// Namensschild der Katze, dazu Pfotenabdrücke an Dingen, die beide heute angetippt haben. Overlay über
/// `ZuhauseBuehne`, rechnet wie `ZimmerSpielEbene` (Welt 975 x 430, unten verankert). Kein Takt, keine
/// Dauer-Animation: Schnee und Entwickeln sind einmalige Animationen.
struct ZimmerErinnerungEbene: View {
    private let welt: ProfilWelt
    private let eigen: Bool

    @State private var blatt: ErinnerungsBlatt?
    @State private var tipp = 0
    @State private var schneeNummer = 0
    @State private var schneeAn = 0
    @State private var faellt = false
    @State private var entwicklung = 1.0
    @State private var gartenAnzahl = 0
    @State private var fotos: [ZimmerPolaroid] = []
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(welt: ProfilWelt = .panorama, eigen: Bool = true) {
        self.welt = welt
        self.eigen = eigen
    }

    // MARK: Plaetze (Panorama-Einheiten, fuer ZimmerPlatzLogik)

    static let polaroidWand = CGRect(x: 92, y: 42, width: 76, height: 46)
    static let liebesschloesser = CGRect(x: 415, y: 66, width: 82, height: 30)
    static let balkonGarten = CGRect(x: 410, y: 172, width: 92, height: 30)
    static let schneekugel = CGRect(x: 704, y: 286, width: 36, height: 44)
    static let erinnerungsKisten = CGRect(x: 62, y: 334, width: 100, height: 26)
    static let katzenSchild = CGRect(x: 166, y: 336, width: 56, height: 20)

    static let alleRects: [CGRect] = [polaroidWand, liebesschloesser, balkonGarten, schneekugel, erinnerungsKisten, katzenSchild]

    private static let plaetze: [String: CGRect] = [
        "polaroid": polaroidWand, "schloesser": liebesschloesser, "garten": balkonGarten,
        "kugel": schneekugel, "kisten": erinnerungsKisten, "katze": katzenSchild
    ]

    private var ich: Person { Raum.shared.ich ?? .ahmed }
    private var heute: String { Datum.text(Date()) }

    var body: some View {
        GeometryReader { geo in
            let s = geo.size.width / welt.breite
            let oben = geo.size.height - ZuhauseZeichnung.hoehe * s
            ZStack(alignment: .topLeading) {
                polaroidDing(s, oben)
                schloesserDing(s, oben)
                gartenDing(s, oben)
                kugelDing(s, oben)
                kistenDing(s, oben)
                schildDing(s, oben)
                pfoten(s, oben)
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: tipp)
        .sensoryFeedback(.success, trigger: schneeNummer)
        .task {
            gartenAnzahl = BalkonGartenLogik.anzahl(eintraege: PunkteModell.shared.verlauf
                .filter { $0.von == .ahmed }.map { ($0.datum, $0.grund) })
            fotos = ZimmerFotos.letzte(ChatModell.shared.nachrichten, anzahl: 40)
        }
        .task(id: schneeNummer) { await schneien() }
        .onDisappear { schneeAn = 0 }
        .sheet(item: $blatt) { b in
            switch b {
            case .kugel: SchneekugelKartenBlatt()
            case .kisten: ErinnerungsKistenBlatt(ich: ich)
            case .katze: KatzenBlatt()
            case .polaroid: PolaroidBlatt(foto: PolaroidWandLogik.wahl(fotos, heute: heute))
            case .schloesser: SchloesserBlatt()
            }
        }
    }

    // MARK: Bausteine

    /// Ein antippbares Ding an einer Stelle der Welt: mindestens 44 x 44 pt, Haptik, Label.
    private func ding<V: View>(_ id: String, _ s: CGFloat, _ oben: CGFloat, name: String,
                               tippen: @escaping () -> Void, @ViewBuilder _ inhalt: () -> V) -> some View {
        let r = Self.plaetze[id] ?? .zero
        return Button {
            tipp += 1
            if eigen { ZimmerTippLog.merke(id) }
            tippen()
        } label: {
            inhalt().padding(8)
                .frame(minWidth: ProfilSlots.tippMinimum, minHeight: ProfilSlots.tippMinimum)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(name)
        .position(x: r.midX * s, y: oben + r.midY * s)
    }

    private func masse(_ r: CGRect, _ s: CGFloat) -> CGSize { CGSize(width: r.width * s, height: r.height * s) }

    // MARK: 9 Polaroid-Wand

    private func polaroidDing(_ s: CGFloat, _ oben: CGFloat) -> some View {
        let m = masse(Self.polaroidWand, s)
        let foto = PolaroidWandLogik.wahl(fotos, heute: heute)
        return ding("polaroid", s, oben, name: foto == nil ? "Polaroid-Wand, noch kein Foto" : "Polaroid-Wand, Foto der Woche",
                    tippen: { blatt = .polaroid }) {
            ZStack {
                RoundedRectangle(cornerRadius: 2 * s).fill(.white)
                    .shadow(color: .black.opacity(0.25), radius: 2 * s, y: s)
                if let foto {
                    ProfilFoto(medienId: foto.medienId)
                        .frame(width: m.width - 8 * s, height: m.height - 16 * s)
                        .overlay { Color.white.opacity(1 - entwicklung) }
                        .frame(maxHeight: .infinity, alignment: .top)
                        .padding(.top, 4 * s)
                } else {
                    Image(systemName: "photo").font(.system(size: 14 * s)).foregroundStyle(.secondary)
                }
            }
            .frame(width: m.width, height: m.height)
            .rotationEffect(.degrees(-3))
        }
        .task(id: foto?.id) { await entwickeln(foto) }
    }

    /// Nur beim ersten Sehen eines Fotos: von Weiß zum Bild, einmal, ohne Takt.
    private func entwickeln(_ foto: ZimmerPolaroid?) async {
        guard let foto else { entwicklung = 1; return }
        let gesehen = ErinnerungGesehen.lesen("zimmer.polaroid.gesehen")
        guard PolaroidWandLogik.entwickelt(foto: foto.id, gesehen: gesehen) else { entwicklung = 1; return }
        if reduceMotion { entwicklung = 1 } else {
            entwicklung = 0
            try? await Task.sleep(for: .milliseconds(400))
            withAnimation(.easeIn(duration: PolaroidWandLogik.entwicklung)) { entwicklung = 1 }
        }
        ErinnerungGesehen.merken("zimmer.polaroid.gesehen", foto.id)
    }

    // MARK: 4 Liebesschloesser

    private func schloesserDing(_ s: CGFloat, _ oben: CGFloat) -> some View {
        let alle = LiebesSchloesserLogik.alle(start: Meilenstein.start, heute: heute)
        let (sichtbar, aeltere) = LiebesSchloesserLogik.sichtbar(alle)
        let m = masse(Self.liebesschloesser, s)
        return ding("schloesser", s, oben,
                    name: "Liebesschlösser am Fenster, \(alle.count) \(alle.count == 1 ? "Monat" : "Monate") zusammen",
                    tippen: { blatt = .schloesser }) {
            ZStack(alignment: .top) {
                Capsule().fill(.gray.opacity(0.7)).frame(height: 1.5 * s).padding(.top, 2 * s)
                HStack(spacing: 0) {
                    ForEach(sichtbar) { l in
                        Image(systemName: "lock.fill")
                            .font(.system(size: 8 * s))
                            .foregroundStyle(l.nummer % 2 == 0 ? Color.pink : Color.yellow)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.top, 3 * s)
                if aeltere > 0 {
                    Text("+\(aeltere)").font(.system(size: 6 * s, weight: .bold)).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                }
            }
            .frame(width: m.width, height: m.height)
        }
    }

    // MARK: 7 Balkon-Garten

    private func gartenDing(_ s: CGFloat, _ oben: CGFloat) -> some View {
        let m = masse(Self.balkonGarten, s)
        let blumen = BalkonGartenLogik.layout(anzahl: gartenAnzahl)
        let farben: [Color] = [.pink, .orange, .purple, .red]
        return ding("garten", s, oben,
                    name: "Balkon-Garten, \(gartenAnzahl) \(gartenAnzahl == 1 ? "Blume" : "Blumen") aus gemeinsamen Aufgaben",
                    tippen: {}) {
            ZStack(alignment: .bottomLeading) {
                ForEach(blumen) { b in
                    let h = (m.height - 8 * s) * b.hoehe
                    ZStack(alignment: .top) {
                        Capsule().fill(.green).frame(width: 1.4 * s, height: h)
                        Circle().fill(farben[b.farbe]).frame(width: 6 * s, height: 6 * s).offset(y: -3 * s)
                    }
                    .frame(height: h, alignment: .bottom)
                    .offset(x: b.x * m.width - 3 * s, y: -7 * s)
                }
                RoundedRectangle(cornerRadius: 2 * s).fill(Color.brown)
                    .frame(width: m.width, height: 9 * s)
            }
            .frame(width: m.width, height: m.height, alignment: .bottomLeading)
        }
    }

    // MARK: 5 Schneekugel

    private func kugelDing(_ s: CGFloat, _ oben: CGFloat) -> some View {
        let m = masse(Self.schneekugel, s)
        return ding("kugel", s, oben, name: "Schneekugel vom ersten Treffen, schütteln für Schnee",
                    tippen: {
                        if schneeAn > 0 { blatt = .kugel } else { schuetteln() }
                    }) {
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 3 * s).fill(Color.brown.opacity(0.8)).frame(width: m.width * 0.8, height: m.height * 0.25)
                Circle().fill(LinearGradient(colors: [.cyan.opacity(0.35), .blue.opacity(0.2)], startPoint: .top, endPoint: .bottom))
                    .overlay(Circle().stroke(.white.opacity(0.6), lineWidth: s))
                    .overlay { flocken(m, s) }
                    .clipShape(Circle())
                    .frame(width: m.width, height: m.width)
                    .offset(y: -m.height * 0.2)
                Image(systemName: "house.fill").font(.system(size: 8 * s)).foregroundStyle(.white)
                    .offset(y: -m.height * 0.3)
            }
            .frame(width: m.width, height: m.height)
            .simultaneousGesture(DragGesture(minimumDistance: 14).onEnded { _ in schuetteln() })
        }
        .contextMenu { Button { blatt = .kugel } label: { Label("Karte öffnen", systemImage: "square.and.pencil") } }
        .accessibilityAction(named: "Karte öffnen") { blatt = .kugel }
    }

    private func flocken(_ m: CGSize, _ s: CGFloat) -> some View {
        ZStack {
            ForEach(0..<schneeAn, id: \.self) { i in
                Circle().fill(.white)
                    .frame(width: 2.5 * s, height: 2.5 * s)
                    .offset(x: (Double((i * 37) % 100) / 100 - 0.5) * m.width * 0.8, y: faellt ? m.width * 0.45 : -m.width * 0.45)
                    .animation(reduceMotion ? nil : .linear(duration: 2.5 + Double(i % 4)), value: faellt)
            }
        }
    }

    private func schuetteln() {
        schneeNummer += 1
    }

    /// Eine einmalige Schneeschauer: Flocken setzen, fallen lassen, nach `dauer` wieder weg. Abbruch beim Verlassen.
    private func schneien() async {
        guard schneeNummer > 0 else { return }
        faellt = false
        schneeAn = SchneekugelLogik.flocken(geschuettelt: true, reduzieren: reduceMotion)
        try? await Task.sleep(for: .milliseconds(60))
        faellt = true
        try? await Task.sleep(for: .seconds(SchneekugelLogik.dauer))
        guard !Task.isCancelled else { return }
        schneeAn = 0
        faellt = false
    }

    // MARK: 19 Erinnerungs-Kisten

    private func kistenDing(_ s: CGFloat, _ oben: CGFloat) -> some View {
        let kisten = ErinnerungsKistenLogik.sortiert(ZimmerLebenModell.lesen(ErinnerungsKistenSchluessel.name, als: [ErinnerungsKiste].self) ?? [])
        let neu = ErinnerungsKistenLogik.neuOffen(kisten, gesehen: ErinnerungGesehen.lesen("zimmer.kisten.gesehen"), heute: heute)
        let m = masse(Self.erinnerungsKisten, s)
        return ding("kisten", s, oben,
                    name: "Erinnerungs-Kisten unterm Bett, \(kisten.count) \(kisten.count == 1 ? "Kiste" : "Kisten")" + (neu.isEmpty ? "" : ", eine ist aufgegangen"),
                    tippen: { blatt = .kisten }) {
            HStack(spacing: 3 * s) {
                ForEach(kisten.prefix(4)) { k in
                    Image(systemName: ErinnerungsKistenLogik.gesperrt(k, heute: heute) ? "shippingbox.fill" : "shippingbox")
                        .font(.system(size: 14 * s))
                        .foregroundStyle(ErinnerungsKistenLogik.gesperrt(k, heute: heute) ? Color.brown : Color.orange)
                }
                if kisten.isEmpty {
                    Image(systemName: "plus.square.dashed").font(.system(size: 14 * s)).foregroundStyle(.secondary)
                }
            }
            .overlay(alignment: .topTrailing) {
                if !neu.isEmpty { Image(systemName: "sparkles").font(.system(size: 8 * s)).foregroundStyle(.yellow).offset(x: 4 * s, y: -4 * s) }
            }
            .frame(width: m.width, height: m.height, alignment: .leading)
        }
    }

    // MARK: 16 Katzen-Schild

    private func schildDing(_ s: CGFloat, _ oben: CGFloat) -> some View {
        let serie = KatzenWachstumLogik.serie(PunkteModell.shared.laufendeSerien)
        let name = KatzenNamen.aktuell()
        let m = masse(Self.katzenSchild, s)
        return ding("katze", s, oben, name: "Namensschild der Katze: \(name), \(KatzenWachstumLogik.stufenName(serie: serie))",
                    tippen: { blatt = .katze }) {
            Text(name)
                .font(.system(size: 8 * s, weight: .bold, design: .rounded))
                .lineLimit(1).minimumScaleFactor(0.5)
                .padding(.horizontal, 3 * s)
                .frame(width: m.width, height: m.height)
                .background(RoundedRectangle(cornerRadius: 3 * s).fill(Color.brown.opacity(0.85)))
                .foregroundStyle(.white)
        }
    }

    // MARK: 3 Pfotenabdruecke

    /// Pfoten neben jedem Ding, das beide heute angetippt haben.
    @ViewBuilder
    private func pfoten(_ s: CGFloat, _ oben: CGFloat) -> some View {
        let beide = ZimmerTippLog.gemeinsam(heute: heute)
        ForEach(beide, id: \.self) { id in
            if let r = Self.plaetze[id] {
                Image(systemName: "pawprint.fill")
                    .font(.system(size: 9 * s))
                    .foregroundStyle(.brown.opacity(0.7))
                    .rotationEffect(.degrees(20))
                    .position(x: r.maxX * s, y: oben + (r.maxY + 4) * s)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
    }
}

// MARK: - Blaetter

private enum ErinnerungsBlatt: String, Identifiable {
    case kugel, kisten, katze, polaroid, schloesser
    var id: String { rawValue }
}

// MARK: - Speicher-Helfer

/// Was dieses Gerät schon gesehen hat (nur lokal, ohne Sync): Polaroid-Entwicklung, aufgegangene Kisten.
enum ErinnerungGesehen {
    static func lesen(_ schluessel: String) -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: schluessel) ?? [])
    }

    static func merken(_ schluessel: String, _ id: String) {
        var menge = lesen(schluessel)
        menge.insert(id)
        UserDefaults.standard.set(Array(menge.suffix(200)), forKey: schluessel)
    }
}

enum ErinnerungsKistenSchluessel {
    static let name = "zimmer.kisten"
}

/// Gemeinsamer Namensschild-Text der Katze, per `EinstellungenModell` für beide synchron.
@MainActor
enum KatzenNamen {
    static let schluessel = "zimmer.katzenname"

    static func aktuell() -> String {
        if case .string(let t)? = EinstellungenModell.shared.geteilt(schluessel) {
            let n = KatzenWachstumLogik.name(t)
            if !n.isEmpty { return n }
        }
        return "Mieze"
    }

    static func setzen(_ roh: String) {
        EinstellungenModell.shared.setzen(schluessel, .string(KatzenWachstumLogik.name(roh)))
    }
}

/// Wer heute was angetippt hat, je Person ein Tagesstand. Andere Overlays können `merke` aufrufen,
/// dann bekommen ihre Dinge auch Pfoten, sobald sie hier einen Platz haben.
@MainActor
enum ZimmerTippLog {
    private static func schluessel(_ p: Person) -> String { "zimmer.tipps.\(p.rawValue)" }

    static func merke(_ id: String, jetzt: Date = Date()) {
        let ich = Raum.shared.ich ?? .ahmed
        let heute = Datum.text(jetzt)
        let alt = ZimmerLebenModell.lesen(schluessel(ich), als: PfotenLogik.TippTag.self)
        let neu = PfotenLogik.merken(alt, ding: id, heute: heute)
        guard neu != alt else { return }
        ZimmerLebenModell.schreiben(schluessel(ich), neu)
    }

    static func gemeinsam(heute: String) -> [String] {
        func menge(_ p: Person) -> Set<String> {
            PfotenLogik.menge(ZimmerLebenModell.lesen(schluessel(p), als: PfotenLogik.TippTag.self), heute: heute)
        }
        return PfotenLogik.gemeinsam(menge(.ahmed), menge(.annika))
    }
}

// MARK: - Sheets

private struct SchneekugelKartenBlatt: View {
    @Environment(\.dismiss) private var dismiss
    @State private var karte = SchneekugelKarte.standard(start: Meilenstein.start)

    private static let schluessel = "zimmer.schneekugel"

    var body: some View {
        NavigationStack {
            Form {
                Section("Wo wir uns getroffen haben") {
                    TextField("Ort", text: $karte.ort)
                    DatePicker("Tag", selection: Binding(
                        get: { Datum.datum(karte.tag) },
                        set: { karte.tag = Datum.text($0) }
                    ), displayedComponents: .date)
                }
                Section("Erinnerung") {
                    TextField("Was war da?", text: $karte.text, axis: .vertical).lineLimit(3...6)
                }
            }
            .navigationTitle("Unsere Schneekugel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Schließen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") {
                        ZimmerLebenModell.schreiben(Self.schluessel, SchneekugelLogik.bereinigt(karte, start: Meilenstein.start))
                        dismiss()
                    }
                }
            }
            .onAppear {
                if let k = ZimmerLebenModell.lesen(Self.schluessel, als: SchneekugelKarte.self) { karte = k }
            }
        }
        .presentationDetents([.medium])
    }
}

private struct SchloesserBlatt: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let alle = LiebesSchloesserLogik.alle(start: Meilenstein.start, heute: Datum.text(Date()))
        NavigationStack {
            List {
                if alle.isEmpty {
                    Text("Das erste Schloss hängt nach einem gemeinsamen Monat.").foregroundStyle(.secondary)
                }
                ForEach(alle.reversed()) { l in
                    Label {
                        VStack(alignment: .leading) {
                            Text("\(l.nummer). Monat")
                            Text(LiebesSchloesserLogik.gravur(l.tag)).font(.caption).foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "lock.fill").foregroundStyle(l.nummer % 2 == 0 ? Color.pink : Color.yellow)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .navigationTitle("Liebesschlösser")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Schließen") { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
    }
}

private struct PolaroidBlatt: View {
    let foto: ZimmerPolaroid?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack {
                if let foto {
                    ProfilFoto(medienId: foto.medienId)
                        .frame(height: 320)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 8).fill(.white).shadow(radius: 4))
                        .padding()
                    Text(Datum.anzeige(Datum.text(foto.zeit))).font(.callout).foregroundStyle(.secondary)
                } else {
                    Text("Sobald ein gemeinsames Foto im Chat gespeichert ist, hängt hier das Foto der Woche.")
                        .multilineTextAlignment(.center).foregroundStyle(.secondary).padding()
                }
            }
            .navigationTitle("Foto der Woche")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Schließen") { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
    }
}

private struct KatzenBlatt: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = KatzenNamen.aktuell()

    var body: some View {
        let serie = KatzenWachstumLogik.serie(PunkteModell.shared.laufendeSerien)
        let kuenste = KatzenWachstumLogik.kunststuecke(serie: serie)
        NavigationStack {
            Form {
                Section("Name auf dem Schild (für euch beide)") {
                    TextField("Name", text: $name)
                        .onSubmit { KatzenNamen.setzen(name) }
                }
                Section("Wie groß sie ist") {
                    Label(KatzenWachstumLogik.stufenName(serie: serie), systemImage: "pawprint.fill")
                    Text("Sie wächst mit euren Tagen am Stück. Pausen machen sie nicht kleiner.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Kunststücke") {
                    if kuenste.isEmpty { Text("Noch keins, sie lernt gerade.").foregroundStyle(.secondary) }
                    ForEach(kuenste, id: \.self) { Label($0, systemImage: "star.fill") }
                    if let n = KatzenWachstumLogik.naechste(serie: serie) {
                        Text("Nächstes: \(n.name), in \(n.fehlen) \(n.fehlen == 1 ? "Tag" : "Tagen")")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Unsere Katze")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Schließen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Sichern") { KatzenNamen.setzen(name); dismiss() } }
            }
        }
        .presentationDetents([.medium])
    }
}

private struct ErinnerungsKistenBlatt: View {
    let ich: Person
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var kisten: [ErinnerungsKiste] = []
    @State private var offen: ErinnerungsKiste?
    @State private var neu = false
    @State private var titel = ""
    @State private var notiz = ""
    @State private var tag = Date()
    @State private var aufgegangen: Set<String> = []

    private var heute: String { Datum.text(Date()) }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if kisten.isEmpty {
                        Text("Leg etwas für später hinein. Die Kiste bleibt zu bis zum Tag, den ihr wählt.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(kisten) { k in zeile(k) }
                }
                if kisten.count < ErinnerungsKistenLogik.hoechstens {
                    Section { Button { neu = true } label: { Label("Neue Kiste", systemImage: "plus") } }
                }
            }
            .navigationTitle("Unterm Bett")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Schließen") { dismiss() } } }
            .sheet(isPresented: $neu) { neueKiste }
            .alert(offen?.titel ?? "", isPresented: Binding(get: { offen != nil }, set: { if !$0 { offen = nil } })) {
                Button("Schön") { offen = nil }
            } message: { Text(offen?.notiz.isEmpty == false ? offen?.notiz ?? "" : "Keine Notiz, nur der Tag.") }
            .onAppear { laden() }
            .task { await aufschliessen() }
        }
        .presentationDetents([.medium, .large])
    }

    private func zeile(_ k: ErinnerungsKiste) -> some View {
        let zu = ErinnerungsKistenLogik.gesperrt(k, heute: heute)
        let auf = aufgegangen.contains(k.id)
        return Button {
            if !zu { offen = k }
        } label: {
            HStack {
                Image(systemName: zu ? "lock.fill" : "shippingbox")
                    .foregroundStyle(zu ? Color.brown : Color.orange)
                    .scaleEffect(auf ? 1.25 : 1)
                    .rotationEffect(.degrees(auf ? -8 : 0))
                    .animation(reduceMotion ? nil : Feder.federnd, value: auf)
                VStack(alignment: .leading) {
                    Text(k.titel)
                    Text(zu ? "Öffnet in \(ErinnerungsKistenLogik.tageBis(k, heute: heute)) Tagen, am \(LiebesSchloesserLogik.gravur(k.tag))"
                            : "Offen seit \(LiebesSchloesserLogik.gravur(k.tag))")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.success, trigger: auf)
        .accessibilityLabel(zu ? "\(k.titel), noch zu" : "\(k.titel), offen")
    }

    private var neueKiste: some View {
        NavigationStack {
            Form {
                TextField("Titel", text: $titel)
                DatePicker("Öffnen am", selection: $tag, in: Date.now..., displayedComponents: .date)
                TextField("Notiz für später", text: $notiz, axis: .vertical).lineLimit(3...8)
                Text("Fotos folgen später. Die Kiste hält Text für euch beide.").font(.caption).foregroundStyle(.secondary)
            }
            .navigationTitle("Neue Kiste")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { neu = false } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Zumachen") {
                        let liste = ErinnerungsKistenLogik.hinzufuegen(kisten, titel: titel, tag: Datum.text(tag), notiz: notiz, von: ich)
                        if liste != kisten {
                            kisten = liste
                            ZimmerLebenModell.schreiben(ErinnerungsKistenSchluessel.name, liste)
                        }
                        titel = ""; notiz = ""; neu = false
                    }
                    .disabled(titel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func laden() {
        kisten = ErinnerungsKistenLogik.sortiert(ZimmerLebenModell.lesen(ErinnerungsKistenSchluessel.name, als: [ErinnerungsKiste].self) ?? [])
    }

    /// Kisten, die seit dem letzten Mal aufgegangen sind: Deckel hüpft einmal, dann gilt sie als gesehen.
    private func aufschliessen() async {
        laden()
        let neuOffen = ErinnerungsKistenLogik.neuOffen(kisten, gesehen: ErinnerungGesehen.lesen("zimmer.kisten.gesehen"), heute: heute)
        guard !neuOffen.isEmpty else { return }
        try? await Task.sleep(for: .milliseconds(500))
        for k in neuOffen {
            aufgegangen.insert(k.id)
            ErinnerungGesehen.merken("zimmer.kisten.gesehen", k.id)
        }
    }
}
