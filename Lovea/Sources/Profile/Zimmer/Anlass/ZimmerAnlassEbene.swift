import SwiftUI

/// Anlaesse im Zimmer: Radio (17), Geburtstagsecke (12), Traumblase (13), Partnerlook (15), Regentag (20).
/// Overlay im Panorama (Entwurfsraum 975 x 430, unten verankert), nichts davon blinkt oder laeuft schnell.
struct ZimmerAnlassEbene: View {
    let welt: ProfilWelt
    let eigen: Bool

    init(welt: ProfilWelt = .panorama, eigen: Bool = true) {
        self.welt = welt
        self.eigen = eigen
    }

    /// Das Radio auf dem Regal, immer sichtbar.
    static let radioFlaeche = CGRect(x: 624, y: 176, width: 48, height: 40)
    /// Geburtstagsecke, Partnerlook und Regenplatz sind nur zeitweise da.
    private static let feierMitte = CGPoint(x: 572, y: 346)
    private static let regenMitte = CGPoint(x: 462, y: 330)
    private static let outfitMitte = CGPoint(x: 572, y: 222)

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var tipp = 0
    @State private var radioOffen = false
    @State private var wuenscheOffen = false
    @State private var songText = ""
    @State private var regenWeg = false
    @State private var outfitGesehen = false

    private var ich: Person { Raum.shared.ich ?? .ahmed }
    private var besitzer: Person { eigen ? ich : ich.partner }
    private var heute: String { Datum.text(Date()) }
    private var haptikAn: Bool { UserDefaults.standard.object(forKey: "lovea.haptik") as? Bool ?? true }

    var body: some View {
        if welt == .panorama {
            GeometryReader { geo in
                let s = geo.size.width / welt.breite
                let oben = geo.size.height - ZuhauseZeichnung.hoehe * s
                ZStack {
                    radio(s, oben)
                    if let kind = ZimmerGeburtstagLogik.geburtstagskind(am: Date()) { feier(kind, s, oben) }
                    if ProfilSzene.schlafGerade(besitzer) == .schlaeft { traum(s, oben) }
                    if partnerlook { outfit(s, oben) }
                    if regnetBeiPartner && !regenWeg { regen(s, oben) }
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
            .sensoryFeedback(trigger: tipp) { _, _ -> SensoryFeedback? in haptikAn ? .impact(weight: .light) : nil }
        }
    }

    // MARK: Bausteine

    private func ding<Inhalt: View>(_ mitte: CGPoint, _ s: CGFloat, _ oben: CGFloat, name: String, tippen: @escaping () -> Void,
                                    @ViewBuilder inhalt: () -> Inhalt) -> some View {
        Button { tipp += 1; tippen() } label: {
            inhalt().padding(8).frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(name)
        .position(x: mitte.x * s, y: oben + mitte.y * s)
    }

    private func pille(_ text: String, _ s: CGFloat) -> some View {
        Text(text)
            .font(.system(size: max(10, 11 * s), weight: .medium))
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(.thinMaterial, in: Capsule())
    }

    // MARK: 17 Radio

    private var partnerSong: SpotifyModell.Song? { SpotifyModell.shared.partner.flatMap { $0.gueltig ? $0 : nil } }
    private var unserSong: String? { ZimmerLebenModell.lesen(ZimmerRadioLogik.schluessel, als: String.self) }

    private func radio(_ s: CGFloat, _ oben: CGFloat) -> some View {
        let r = Self.radioFlaeche
        let name = "Radio, " + (partnerSong?.titel ?? "unser Song")
        return ding(CGPoint(x: r.midX, y: r.midY), s, oben, name: name, tippen: {
            songText = unserSong ?? ""
            radioOffen = true
        }) {
            Image(systemName: partnerSong == nil ? "radio" : "radio.fill")
                .font(.system(size: 26 * s))
                .foregroundStyle(Pal.holz.farbe)
                .frame(width: r.width * s, height: r.height * s)
        }
        .sheet(isPresented: $radioOffen) { radioBlatt }
    }

    private var radioBlatt: some View {
        NavigationStack {
            Form {
                Section("Läuft gerade") {
                    if let song = partnerSong {
                        Button {
                            if let url = song.oeffnenURL { UIApplication.shared.open(url) }
                        } label: {
                            VStack(alignment: .leading) {
                                Text(song.titel ?? "Hört gerade Musik").font(.headline)
                                if let k = song.kuenstler { Text(k).font(.subheadline).foregroundStyle(.secondary) }
                            }
                        }
                    } else {
                        Text("Gerade läuft nichts.").foregroundStyle(.secondary)
                    }
                }
                Section("Unser Song") {
                    TextField("Spotify-Link", text: $songText).textInputAutocapitalization(.never).autocorrectionDisabled()
                    Button("Speichern") {
                        if let l = ZimmerRadioLogik.link(aus: songText) {
                            ZimmerLebenModell.schreiben(ZimmerRadioLogik.schluessel, l)
                            songText = l
                        }
                    }
                    .disabled(ZimmerRadioLogik.link(aus: songText) == nil)
                    if let l = unserSong, let url = URL(string: l) {
                        Button("Unseren Song öffnen") { UIApplication.shared.open(url) }
                    }
                }
            }
            .navigationTitle("Radio")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
    }

    // MARK: 12 Geburtstag

    private func feier(_ kind: Person, _ s: CGFloat, _ oben: CGFloat) -> some View {
        ding(Self.feierMitte, s, oben, name: "Geburtstag von \(kind.name), Wünsche lesen", tippen: { wuenscheOffen = true }) {
            HStack(spacing: 2 * s) {
                Image(systemName: "birthday.cake.fill").font(.system(size: 26 * s)).foregroundStyle(.pink)
                ZStack(alignment: .top) {
                    Image(systemName: "cat.fill").font(.system(size: 22 * s)).foregroundStyle(.orange)
                    Image(systemName: "triangle.fill").font(.system(size: 9 * s)).foregroundStyle(.purple).offset(y: -7 * s)
                }
            }
        }
        .sheet(isPresented: $wuenscheOffen) {
            NavigationStack {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(ZimmerGeburtstagLogik.wuensche(fuer: kind), id: \.self) { w in
                            Text(w).frame(maxWidth: .infinity, alignment: .leading).padding()
                                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding()
                }
                .navigationTitle("Alles Gute")
                .navigationBarTitleDisplayMode(.inline)
            }
            .presentationDetents([.medium])
        }
    }

    // MARK: 13 Traum

    @ViewBuilder
    private func traum(_ s: CGFloat, _ oben: CGFloat) -> some View {
        let bett = ProfilSlots.welt(.bett)
        let wunsch = ZimmerLebenModell.lesen(ZimmerTraumLogik.schluessel(besitzer), als: String.self)
        if let text = ZimmerTraumLogik.text(stimmung: SignaleSpeicher.shared.stimmung(von: besitzer), wunsch: wunsch) {
            HStack(spacing: 4) {
                Image(systemName: "moon.zzz.fill")
                Text(text)
            }
            .font(.system(size: max(10, 11 * s)))
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(.thinMaterial, in: Capsule())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(besitzer.name) träumt: \(text)")
            .position(x: bett.midX * s, y: oben + (bett.minY - 6) * s)
        }
    }

    // MARK: 15 Partnerlook

    private var partnerlook: Bool {
        ZimmerOutfitLogik.gleich(FigurenModell.shared.aussehen(.ahmed), FigurenModell.shared.aussehen(.annika))
    }

    private func outfit(_ s: CGFloat, _ oben: CGFloat) -> some View {
        let schluessel = ZimmerOutfitLogik.tagesSchluessel(heute)
        let neu = !outfitGesehen && !UserDefaults.standard.bool(forKey: schluessel)
        return ding(Self.outfitMitte, s, oben, name: "Gleiche Farbe, Partnerlook", tippen: {
            UserDefaults.standard.set(true, forKey: schluessel)
            outfitGesehen = true
        }) {
            Image(systemName: neu ? "heart.fill" : "heart")
                .font(.system(size: 18 * s))
                .foregroundStyle(.pink)
                .symbolEffect(.bounce, options: .nonRepeating, isActive: neu && !reduceMotion)
        }
    }

    // MARK: 20 Regentag

    private var regnetBeiPartner: Bool {
        ZimmerRegenLogik.regnet(code: WetterModell.shared.staende[ich.partner]?.code)
    }

    private func regen(_ s: CGFloat, _ oben: CGFloat) -> some View {
        let m = Self.regenMitte
        return ZStack {
            ding(m, s, oben, name: "Regenschirm und Decke bei \(ich.partner.name)", tippen: {}) {
                HStack(spacing: 2 * s) {
                    Image(systemName: "umbrella.fill").font(.system(size: 22 * s)).foregroundStyle(.blue)
                    Image(systemName: "bed.double.fill").font(.system(size: 18 * s)).foregroundStyle(.teal)
                }
            }
            if eigen {
                Button {
                    FigurenModell.shared.gesteSenden("herz")
                    tipp += 1
                    regenWeg = true
                } label: {
                    pille("Bei \(ich.partner.name) regnet es. Herz schicken?", s)
                }
                .buttonStyle(.plain)
                .frame(minHeight: 44)
                .accessibilityLabel("Herz schicken, bei \(ich.partner.name) regnet es")
                .position(x: m.x * s, y: oben + (m.y + 30) * s)
            }
        }
    }
}
