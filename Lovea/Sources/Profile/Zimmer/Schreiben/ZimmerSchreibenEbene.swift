import SwiftUI

/// Unser Zimmer, Worker G: Schreiben als Overlay über `ZuhauseBuehne` (Welt 975 x 430, unten verankert).
/// Tagebuch (ab 365 Einträgen ein Buch zum Blättern), Kompliment-Glas, Zeitkapsel (nur im Tagebuch-Blatt,
/// das Rechteck bleibt reserviert) und das Papierflugzeug im Fenster, solange ein langsamer Brief fliegt.
/// Kein schneller Takt: ein einziger, langer Animationslauf, der bei Unsichtbarkeit und mit "Bewegung reduzieren" ruht.
struct ZimmerSchreibenEbene: View {
    private let welt: ProfilWelt
    private let eigen: Bool

    // Orte in Entwurfseinheiten (für ZimmerPlatzLogik)
    static let tagebuchRect = CGRect(x: 542, y: 372, width: 44, height: 40)
    static let komplimentRect = CGRect(x: 592, y: 372, width: 44, height: 44)
    /// Reserviert für die Zeitkapsel (gezeichnet als kleine Truhe, wenn eine Kapsel da ist).
    static let kapselRect = CGRect(x: 534, y: 176, width: 42, height: 44)
    static let alleRects: [CGRect] = [tagebuchRect, komplimentRect, kapselRect]

    private enum Blatt: String, Identifiable {
        case tagebuch, kompliment, kapsel
        var id: String { rawValue }
    }

    @State private var blatt: Blatt?
    @State private var hinweis: String?
    @State private var tipp = 0
    @State private var flugX = 0.0
    @State private var inView = true
    @Environment(\.scenePhase) private var phase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let briefe = BriefeSpeicher.shared

    init(welt: ProfilWelt = .panorama, eigen: Bool = true) {
        self.welt = welt
        self.eigen = eigen
    }

    private var ich: Person { Raum.shared.ich ?? .ahmed }
    private var sichtbar: Bool { inView && phase == .active }
    private var fliegende: [Brief] { briefe.fliegende }
    private var fliegt: Bool { !fliegende.isEmpty }
    private var kapsel: ZimmerKapsel? { ZimmerSchreibenDaten.kapsel(von: ich) }

    var body: some View {
        Group {
            if welt == .panorama && eigen { szene }
        }
    }

    private var szene: some View {
        GeometryReader { geo in
            let s = geo.size.width / welt.breite
            let oben = geo.size.height - ZuhauseZeichnung.hoehe * s
            ZStack(alignment: .topLeading) {
                if fliegt { flugzeug(s, oben) }
                tagebuch(s, oben)
                komplimentGlas(s, oben)
                if kapsel != nil { kapselTruhe(s, oben) }
                if let hinweis {
                    Text(hinweis)
                        .font(.footnote.weight(.semibold))
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: .capsule)
                        .allowsHitTesting(false)
                        .accessibilityAddTraits(.updatesFrequently)
                        .position(x: geo.size.width / 2, y: oben + 54 * s)
                }
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: tipp)
        .onAppear { inView = true }
        .onDisappear { inView = false }
        .onScrollVisibilityChange(threshold: 0.05) { inView = $0 }
        .task(id: fliegt && sichtbar && !reduceMotion) { await fliegen() }
        .sheet(item: $blatt) { b in
            switch b {
            case .tagebuch: ZimmerTagebuchBlatt()
            case .kompliment: ZimmerKomplimentBlatt()
            case .kapsel: ZimmerKapselBlatt()
            }
        }
    }

    // MARK: Bausteine

    private func ding<V: View>(_ rect: CGRect, _ s: CGFloat, _ oben: CGFloat, name: String, tippen: @escaping () -> Void,
                               @ViewBuilder _ inhalt: () -> V) -> some View {
        Button {
            tipp += 1
            tippen()
        } label: {
            inhalt().padding(4)
                .frame(minWidth: ProfilSlots.tippMinimum, minHeight: ProfilSlots.tippMinimum)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(name)
        .position(x: rect.midX * s, y: oben + rect.midY * s)
    }

    private func zeigen(_ text: String) {
        withAnimation(reduceMotion ? nil : Feder.schnell) { hinweis = text }
        Task {
            try? await Task.sleep(for: .seconds(4))
            if hinweis == text { withAnimation(reduceMotion ? nil : Feder.schnell) { hinweis = nil } }
        }
    }

    // MARK: Tagebuch

    private func tagebuch(_ s: CGFloat, _ oben: CGFloat) -> some View {
        let r = Self.tagebuchRect
        let buch = ZimmerSchreibenDaten.istBuch
        return ding(r, s, oben, name: buch ? "Unser Tagebuch, ein Buch zum Blättern" : "Unser Tagebuch, eine Zeile pro Tag", tippen: { blatt = .tagebuch }) {
            ZStack {
                RoundedRectangle(cornerRadius: 3 * s).fill(buch ? Color.brown : Color.pink.opacity(0.8))
                RoundedRectangle(cornerRadius: 3 * s).stroke(.white.opacity(0.6), lineWidth: 1)
                Image(systemName: "heart.fill").font(.system(size: 9 * s * 2)).foregroundStyle(.white.opacity(0.9))
            }
            .frame(width: r.width * s * 0.8, height: r.height * s * 0.8)
        }
    }

    // MARK: Kompliment-Glas

    private func komplimentGlas(_ s: CGFloat, _ oben: CGFloat) -> some View {
        let r = Self.komplimentRect
        let gesendet = ZimmerSchreibenDaten.heuteGesendet
        return ding(r, s, oben, name: gesendet ? "Kompliment-Glas, heute gesendet" : "Kompliment-Glas, ein Kompliment für heute", tippen: { blatt = .kompliment }) {
            ZStack {
                RoundedRectangle(cornerRadius: 6 * s).fill(.white.opacity(0.35))
                RoundedRectangle(cornerRadius: 6 * s).stroke(.white.opacity(0.8), lineWidth: 1)
                Image(systemName: gesendet ? "heart.fill" : "sparkles").foregroundStyle(.pink)
            }
            .frame(width: r.width * s * 0.8, height: r.height * s * 0.9)
        }
    }

    // MARK: Zeitkapsel

    private func kapselTruhe(_ s: CGFloat, _ oben: CGFloat) -> some View {
        let r = Self.kapselRect
        let offen = kapsel.map { ZimmerSchreibenLogik.kapselOffen(oeffnung: $0.oeffnungsDatum) } ?? false
        return ding(r, s, oben, name: offen ? "Zeitkapsel, bereit zum Öffnen" : "Zeitkapsel, verschlossen", tippen: { blatt = .kapsel }) {
            Image(systemName: offen ? "shippingbox.fill" : "lock.fill")
                .font(.system(size: 16 * s * 2))
                .foregroundStyle(offen ? Color.yellow : Color.brown)
        }
    }

    // MARK: Papierflugzeug (langsame Post)

    private func flugzeug(_ s: CGFloat, _ oben: CGFloat) -> some View {
        let f = ProfilSlots.welt(.fenster)
        let x = f.minX + f.width * (reduceMotion ? 0.5 : flugX)
        let y = f.minY + f.height * 0.45 - 12 * sin(flugX * .pi)
        let ankunft = fliegende.compactMap(\.ankunft).min()
        let text = ankunft.map { "Ein Brief fliegt, kommt am \(NaeheDatum.kurz($0)) an" } ?? "Ein Brief fliegt"
        return Button {
            tipp += 1
            zeigen(text)
        } label: {
            Image(systemName: "paperplane.fill")
                .font(.system(size: 13 * s * 2))
                .foregroundStyle(.white)
                .shadow(radius: 1)
                .padding(15)
                .frame(minWidth: ProfilSlots.tippMinimum, minHeight: ProfilSlots.tippMinimum)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(text)
        .position(x: x * s, y: oben + y * s)
    }

    /// Ein einziger langer Lauf (kein Takt). Läuft nur, solange ein Brief fliegt und die Szene zu sehen ist.
    private func fliegen() async {
        var aus = Transaction()
        aus.disablesAnimations = true
        withTransaction(aus) { flugX = 0 }
        guard fliegt, sichtbar, !reduceMotion else { return }
        try? await Task.sleep(for: .seconds(1))
        guard !Task.isCancelled else { return }
        withAnimation(.linear(duration: 18).repeatForever(autoreverses: false)) { flugX = 1 }
    }
}

// MARK: - Daten

struct ZimmerKapsel: Codable, Equatable {
    var text: String
    var geschrieben: Double
    var oeffnung: Double
    var oeffnungsDatum: Date { Date(timeIntervalSince1970: oeffnung) }
}

/// Lesen und Schreiben der Schreib-Werte (`zimmer.tagebuch.YYYY-MM`, `zimmer.kapsel`, `zimmer.kompliment`).
@MainActor
enum ZimmerSchreibenDaten {
    typealias L = ZimmerSchreibenLogik
    static let kapselSchluessel = "zimmer.kapsel"
    static let komplimentSchluessel = "zimmer.kompliment"

    static var ich: Person { Raum.shared.ich ?? .ahmed }

    private static func monat(_ schluessel: String, von person: Person) -> [String: String] {
        RDaten.lesen(schluessel, von: person, als: [String: String].self) ?? [:]
    }

    /// Alle Einträge einer Person über alle Monate (Tag -> Text).
    static func eintraege(von person: Person) -> [String: String] {
        var alle: [String: String] = [:]
        for (k, v) in EinstellungenModell.shared.werte[person] ?? [:] where k.hasPrefix(L.tagebuchPraefix) {
            guard case .string(let s) = v, let d = s.data(using: .utf8),
                  let m = try? JSONDecoder().decode([String: String].self, from: d) else { continue }
            alle.merge(m) { a, _ in a }
        }
        return alle.filter { !$0.value.isEmpty }
    }

    static var anzahl: Int { eintraege(von: .ahmed).count + eintraege(von: .annika).count }
    static var istBuch: Bool { L.istBuch(anzahl: anzahl) }

    static func eintragSetzen(_ text: String, tag: String) {
        guard let t = L.eintragBereinigt(text) else { return }
        let schluessel = L.tagebuchSchluessel(tag: tag)
        var m = monat(schluessel, von: ich)
        m[tag] = t
        RDaten.schreiben(schluessel, m)
    }

    static func kapsel(von person: Person) -> ZimmerKapsel? {
        RDaten.lesen(kapselSchluessel, von: person, als: ZimmerKapsel.self)
    }

    static func kapselVergraben(_ text: String, jetzt: Date = Date()) {
        guard let t = L.eintragBereinigt(text) else { return }
        let k = ZimmerKapsel(text: t, geschrieben: jetzt.timeIntervalSince1970,
                             oeffnung: L.kapselOeffnung(geschrieben: jetzt).timeIntervalSince1970)
        RDaten.schreiben(kapselSchluessel, k)
    }

    static var heuteGesendet: Bool {
        guard let d = RDaten.datum(komplimentSchluessel, von: ich) else { return false }
        return Datum.text(d) == Datum.text(Date())
    }

    static func komplimentGesendet() { RDaten.setzen(komplimentSchluessel, zahl: Date().timeIntervalSince1970) }
}

// MARK: - Blätter

private struct ZimmerTagebuchBlatt: View {
    @Environment(\.dismiss) private var dismiss
    @State private var kapselOffen = false
    @State private var text = ""
    @State private var auswahl: String?
    @State private var gespeichert = 0
    private typealias L = ZimmerSchreibenLogik

    private var heute: String { Datum.text(Date()) }
    private var ich: Person { Raum.shared.ich ?? .ahmed }
    private var seiten: [L.Seite] {
        L.seiten(ahmed: ZimmerSchreibenDaten.eintraege(von: .ahmed), annika: ZimmerSchreibenDaten.eintraege(von: .annika),
                 neuesteZuerst: !ZimmerSchreibenDaten.istBuch)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                eingabe
                if ZimmerSchreibenDaten.istBuch { buch } else { liste }
            }
            .padding()
            .navigationTitle("Unser Tagebuch")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Zeitkapsel") { kapselOffen = true }
                }
                ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } }
            }
            .sheet(isPresented: $kapselOffen) { ZimmerKapselBlatt() }
            .sensoryFeedback(.success, trigger: gespeichert)
            .onAppear {
                text = ZimmerSchreibenDaten.eintraege(von: ich)[heute] ?? ""
                auswahl = seiten.last?.id
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var eingabe: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Heute, eine Zeile").font(.footnote).foregroundStyle(.secondary)
            HStack {
                TextField("Was war heute schön?", text: $text, axis: .vertical)
                    .lineLimit(1...3)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: text) { _, neu in if neu.count > L.maxZeichen { text = String(neu.prefix(L.maxZeichen)) } }
                Button("Speichern") {
                    ZimmerSchreibenDaten.eintragSetzen(text, tag: heute)
                    gespeichert += 1
                }
                .buttonStyle(.borderedProminent)
                .disabled(L.eintragBereinigt(text) == nil)
            }
        }
    }

    private var liste: some View {
        List(seiten) { s in
            VStack(alignment: .leading, spacing: 4) {
                Text(s.tag).font(.caption).foregroundStyle(.secondary)
                zeile(Person.ahmed, s.ahmed)
                zeile(Person.annika, s.annika)
            }
            .accessibilityElement(children: .combine)
        }
        .listStyle(.plain)
        .overlay {
            if seiten.isEmpty { Text("Noch keine Einträge. Ab 365 wird daraus ein Buch.").font(.footnote).foregroundStyle(.secondary) }
        }
    }

    @ViewBuilder
    private func zeile(_ p: Person, _ t: String?) -> some View {
        if let t, !t.isEmpty { Text("\(p.name): \(t)").font(.subheadline) }
    }

    private var buch: some View {
        TabView(selection: $auswahl) {
            ForEach(seiten) { s in
                VStack(alignment: .leading, spacing: 10) {
                    Text(s.tag).font(.headline)
                    zeile(Person.ahmed, s.ahmed)
                    zeile(Person.annika, s.annika)
                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .background(Color.brown.opacity(0.12), in: .rect(cornerRadius: 10))
                .padding(.horizontal, 8)
                .tag(Optional(s.id))
                .accessibilityElement(children: .combine)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .accessibilityLabel("Tagebuch-Buch, wischen zum Blättern")
    }
}

private struct ZimmerKomplimentBlatt: View {
    @Environment(\.dismiss) private var dismiss
    @State private var text = ZimmerSchreibenLogik.kompliment(fuer: Date())
    @State private var gesendet = 0

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                Text("Kompliment für heute").font(.footnote).foregroundStyle(.secondary)
                TextField("Kompliment", text: $text, axis: .vertical)
                    .lineLimit(2...5)
                    .textFieldStyle(.roundedBorder)
                Button {
                    ChatModell.shared.nachrichtSenden(text: text)
                    ZimmerSchreibenDaten.komplimentGesendet()
                    gesendet += 1
                    dismiss()
                } label: {
                    Label("Senden", systemImage: "paperplane.fill").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Spacer()
            }
            .padding()
            .navigationTitle("Kompliment-Glas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
            .sensoryFeedback(.success, trigger: gesendet)
        }
        .presentationDetents([.medium])
    }
}

private struct ZimmerKapselBlatt: View {
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var vergraben = 0
    private typealias L = ZimmerSchreibenLogik

    private var ich: Person { Raum.shared.ich ?? .ahmed }
    private var meine: ZimmerKapsel? { ZimmerSchreibenDaten.kapsel(von: ich) }
    private var offen: Bool { meine.map { L.kapselOffen(oeffnung: $0.oeffnungsDatum) } ?? false }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                if let k = meine, !offen {
                    Label("Verschlossen", systemImage: "lock.fill").font(.headline)
                    Text("Öffnet am \(Datum.text(k.oeffnungsDatum)), in \(L.kapselTageBis(oeffnung: k.oeffnungsDatum)) Tagen.")
                        .foregroundStyle(.secondary)
                } else {
                    if let k = meine {
                        Label("Geöffnet", systemImage: "shippingbox.fill").font(.headline)
                        Text(k.text).padding().frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.yellow.opacity(0.15), in: .rect(cornerRadius: 10))
                    }
                    Text("Neue Kapsel: öffnet am selben Tag im nächsten Jahr.").font(.footnote).foregroundStyle(.secondary)
                    TextField("Was soll dein zukünftiges Ich lesen?", text: $text, axis: .vertical)
                        .lineLimit(2...5)
                        .textFieldStyle(.roundedBorder)
                    Button {
                        ZimmerSchreibenDaten.kapselVergraben(text)
                        vergraben += 1
                        dismiss()
                    } label: {
                        Label("Vergraben", systemImage: "lock.fill").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(L.eintragBereinigt(text) == nil)
                }
                Spacer()
            }
            .padding()
            .navigationTitle("Zeitkapsel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
            .sensoryFeedback(.success, trigger: vergraben)
        }
        .presentationDetents([.medium])
    }
}
