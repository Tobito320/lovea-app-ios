import AVFoundation
import SwiftUI

/// Block 18: profile like Snapchat's friend profile. Same layout for the own profile (tab, gear to
/// Einstellungen) and the partner's (sheet from Chat/Karte).
struct ProfileView: View {
    let person: Person
    @ObservedObject var session: PersonSession
    /// Spiele-Bilanz aus Block 14 (`SpieleModell`), vom Controller in `AppRootView.swift` verdrahtet.
    var bilanz: [(spiel: String, ahmed: Int, annika: Int, paar: String?)] = []

    var body: some View {
        NavigationStack {
            // p65: the gear floats in the scene (own profile hides the navigation bar), so `session` goes in.
            ProfilInhalt(person: person, bilanz: bilanz, schliessen: {}, session: session)
                .gymLeisteOben()
                // R6: nur die Profil-Wurzel, nicht Einstellungen dahinter.
                .tabWischen(vorheriger: "health", naechster: nil)
        }
    }
}

/// Partner profile, presented as a sheet (ChatTab). Actions that switch tabs close the sheet first.
struct PartnerProfilView: View {
    let person: Person
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ProfilInhalt(person: person, bilanz: bilanz, schliessen: { dismiss() })
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } }
                }
        }
        .presentationDragIndicator(.visible)
        // Screenshot notice "… von deinem Profil" (the own profile tab registers nothing).
        .screenshotKontext(.partnerProfil)
        // The profile shows the partner's place and state too: wake their live location like the map does.
        .partnerStandortLive()
    }

    private var bilanz: [(spiel: String, ahmed: Int, annika: Int, paar: String?)] {
        SpielArt.allCases.compactMap { art in
            guard let p = SpieleModell.shared.bilanz[art] else { return nil }
            let paar: String? = art.paarWertung ? art.bilanzText(p) : nil
            return (art.titel, p.ahmed, p.annika, paar)
        }
    }
}

private enum ProfilBlatt: String, Identifiable {
    case wallpaper, medien, zimmer, sterne
    var id: String { rawValue }
}

/// Z-24.3: a tiny one-shot audio player for the profile kiss (`kuss.wav`, generated — no
/// copyrighted audio). A strong static reference is required or ARC drops the player mid-playback.
@MainActor
private enum KussTon {
    private static var player: AVAudioPlayer?
    static func spielen() {
        guard let url = Bundle.main.url(forResource: "kuss", withExtension: "wav")
            ?? Bundle.main.url(forResource: "kuss", withExtension: "wav", subdirectory: "Figuren")
        else { return }
        player = try? AVAudioPlayer(contentsOf: url)
        player?.play()
    }
}

private struct ProfilInhalt: View {
    let person: Person
    let bilanz: [(spiel: String, ahmed: Int, annika: Int, paar: String?)]
    /// Closes the partner sheet before a tab switch; no-op in the tab.
    let schliessen: () -> Void
    /// p65: the own profile's session, for the gear in the scene that opens Einstellungen (none: no gear).
    var session: PersonSession?

    @Environment(\.openURL) private var openURL
    @State private var tipps = 0
    @State private var nummerFehlt = 0
    @State private var blatt: ProfilBlatt?
    /// p60: das offene Blatt der Paar-Signale im Zimmer (Stimmung, Brief, Zettel, Geschenkbox).
    @State private var signale: SignaleBlatt?
    @State private var backdropOffen = false
    /// Z-19.1: Karte ist kein Tab mehr, sie öffnet sich vollflächig über die Karten-Vorschau.
    @State private var karteOffen = false
    // Z-25.1: eigenes Profil. p65 C: "Profil" opens Meine Figur, "Kleidung" the wardrobe (with the Shop button).
    @State private var figurBearbeitenOffen = false
    @State private var kleidungOffen = false
    /// Brief G: the place whose editor opens (where the person is right now, else home).
    @State private var zimmerOrt = RaumOrt.zuhause
    // Z-24.3: Kuss-Animation im Partner-Profil. `kussBasislinie` liest den Ausgangswert beim
    // Erstellen dieser View — spätere Erhöhungen sind dann eindeutig "neu seit dem Öffnen".
    @State private var kussBasislinie = FigurenModell.shared.kussEreignis
    @State private var kussHaptik = 0
    // Z-23.2: "Geschenk erhalten"-Feier im eigenen Profil.
    @State private var geschenkArtikel: ShopArtikel?
    @State private var geschenkHaptik = 0

    private static let monate = ["Januar", "Februar", "März", "April", "Mai", "Juni", "Juli", "August", "September", "Oktober", "November", "Dezember"]

    private var ich: Person { Raum.shared.ich ?? person }
    /// Whom the chat/call buttons reach: always the partner, also from the own profile.
    private var gegenueber: Person { ich.partner }
    private var istEigenes: Bool { person == ich }

    /// p65: the scene stands fixed on top and is always whole, the panorama swipes sideways; only the calm
    /// part under it scrolls. The wall bleeds under the status bar, the scene itself starts below it.
    var body: some View {
        layout
        .ignoresSafeArea(edges: .top)
        .background(Color(uiColor: .systemGroupedBackground))
        .toolbar(istEigenes ? .hidden : .automatic, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.impact(weight: .medium), trigger: tipps)
        .sensoryFeedback(.warning, trigger: nummerFehlt)
        .sheet(item: $blatt) { b in blattInhalt(b) }
        .fullScreenCover(isPresented: $karteOffen) { KarteTab(schliessen: { karteOffen = false }) }
        .sheet(isPresented: $figurBearbeitenOffen) { NavigationStack { FigurEditorSeite(person: person) } }
        .sheet(isPresented: $kleidungOffen) { NavigationStack { FigurEditorSeite(person: person, bereich: .kleidung) } }
        .modifier(KussUndGeschenkReaktionen(
            istEigenes: istEigenes, person: person, kussBasislinie: $kussBasislinie, kussHaptik: $kussHaptik,
            geschenkArtikel: $geschenkArtikel, geschenkHaptik: $geschenkHaptik
        ))
    }

    /// p69: the scene and the part under it. `ProfilLayout` decides from the room the screen gives whether the
    /// scene stands still on top (only the rest scrolls) or the whole profile scrolls as one.
    private var layout: some View {
        GeometryReader { geo in
            let oben = geo.safeAreaInsets.top
            let szene = ProfilLayout.szene(breite: geo.size.width, hoehe: geo.size.height, oben: oben)
            ProfilUnterbau(abschnitte: abschnitte, klebt: szene.klebt, start: istEigenes ? nil : .wir) {
                ProfilPanorama(wahl: ZimmerWahl.aktuell, breite: szene.breite, hoehe: szene.hoehe) {
                    zuhause(paar: !istEigenes)
                } schwebend: {
                    schwebend(oben: oben)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
        }
        // Here and not on a row of the closed "Unser Chat" card: a lazy row can be dropped with its cover.
        .fullScreenCover(isPresented: $backdropOffen) { BackdropAuswahl() }
        // The partner's song is polled while the profile is on screen (Spec 9), not while one row of it is built:
        // a tab or a lazy row that comes and goes must not start and stop it, and the row can stay away while empty.
        .task { if !istEigenes { SpotifyModell.shared.schauen() } }
        .onDisappear { if !istEigenes { SpotifyModell.shared.wegschauen() } }
    }

    /// p69: what stands under the scene, in four tabs. Blocks without a title are bars of buttons and chips;
    /// blocks with one fold open and shut, shut at the start, and build their content only when opened.
    /// A block with nothing to show is left out (`sichtbar`), and a tab with no block is not drawn.
    private var abschnitte: [ProfilAbschnitt] {
        let challenges = ProfilAbschnitt("challenges", .quests, sichtbar: LaufendeChallengesCard.vorhanden) { LaufendeChallengesCard() }
        if istEigenes {
            return [
                ProfilAbschnitt("chips", .zimmer) { eigeneChips },
                ProfilAbschnitt("aktionen", .zimmer) { eigeneAktionen },
                ProfilAbschnitt("zyklus", .wir) { ZyklusProfilZeile(person: person) },
                ProfilAbschnitt("bilanz", .wir, titel: "Spiele-Bilanz", sichtbar: !bilanz.isEmpty) { spieleAbschnittInhalt },
                ProfilAbschnitt("punkte", .quests) { ProfilPunkteKarte(person: person) },
                challenges,
            ]
        }
        return [
            ProfilAbschnitt("bearbeiten", .zimmer, sichtbar: person.figurBearbeitbar(durch: ich)) { partnerBearbeiten },
            ProfilAbschnitt("jetzt", .wir, sichtbar: WetterModell.shared.partner != nil || SpotifyModell.shared.partner != nil) { partnerJetzt },
            ProfilAbschnitt("chips", .wir) { chips },
            ProfilAbschnitt("aktionen", .wir) { aktionen },
            // Z-19.1 / Spec 2: Karte öffnet sich nur über das Partner-Profil, nicht das eigene.
            ProfilAbschnitt("karte", .wir, titel: "Die Karte") { dieKarte },
            ProfilAbschnitt("wir", .wir, titel: "Wir") { wir },
            ProfilAbschnitt("chat", .erinnerungen, titel: "Unser Chat") { unserChat },
            challenges,
        ]
    }

    /// common.md warns a long `body` modifier chain risks "unable to type-check in reasonable
    /// time" (hit Runde 1) — the `blatt` switch is split out for the same reason.
    @ViewBuilder
    private func blattInhalt(_ b: ProfilBlatt) -> some View {
        switch b {
        case .wallpaper: WallpaperAuswahl(partner: gegenueber)
        case .medien: MedienUebersicht(ich: ich)
        case .zimmer: NavigationStack { ZimmerEditor(person: person, ort: zimmerOrt) }
        case .sterne: SterneBlatt(ich: ich) { zurNachricht($0) }
        }
    }

    // MARK: - Scene (fixed panorama, both figures)

    /// p65: the two small things that float over the scene and do not move with the swipe: the one avatar
    /// of the profile with its online dot ("Annika ist online"), and in the own profile the gear.
    /// `oben` is the status bar the wall bleeds into; both sit just under it.
    private func schwebend(oben: CGFloat) -> some View {
        HStack(alignment: .top) {
            ProfilOnlineChip(person: gegenueber, online: Raum.shared.partnerDa)
            Spacer(minLength: 8)
            if let session, person == session.person {
                NavigationLink { EinstellungenView(person: person, session: session) } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial, in: Circle())
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Einstellungen")
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, oben + 4)
        // Chrome over the scene: its letters stop growing with Dynamic Type so it never covers the room.
        .dynamicTypeSize(ProfilLayout.leistenSchrift)
    }

    /// p58: the scene is always the shared home with both of them (`ZuhauseBuehne`), in the partner
    /// profile and the own one. They walk about
    /// by the clock; only when they are together for real (or a kiss plays) the pair's hug and kiss
    /// replaces the walkers. The bouquets (p59) are Annika's choice for her room, shown in both profiles; p68: Ahmed's own stand on his board.
    /// p65: `.panorama`, the wide world the panorama swipes through; a tap on the bed or the sofa sends both there.
    private func zuhause(paar: Bool) -> some View {
        let paarDa = paar && (NaeheLogik.sindZusammen || FigurenModell.shared.kussBeginn != nil)
        let zimmer = Zimmer.von(person)
        // p60: sagen beide Gute Nacht, ist es im Zimmer Nacht; die Signale (Lampe, Brief, Zettel, Box) liegen darüber.
        let nacht = NachtLogik.gemeinsamDunkel(FigurenModell.shared.gruss, jetzt: Date())
        // p61: the shared room's pieces, the cat (it can be stroked here, once a day each), and in the own
        // profile the clothes rail and the shoe shelf open the outfit change.
        let punkte = PunkteModell.shared
        let katze = ZuhauseKatze(id: ZimmerKatze.id(tiere: Person.allCases.map { FigurenModell.shared.aussehen($0).tier }),
                                 gestreichelt: punkte.katzeGestreichelt(ich), streicheln: { punkte.katzeStreicheln() })
        return ZuhauseBuehne(straeusse: ZimmerStraeusse.von(.annika).fuerBuehne, ahmedStraeusse: ZimmerStraeusse.von(.ahmed).fuerBuehne, paarDa: paarDa, extras: .live(), nacht: nacht, wahl: ZimmerWahl.aktuell, katze: katze,
                             outfit: istEigenes ? { kleidungOffen = true } : nil, welt: .panorama,
                             wandDinge: { zeit in AnyView(ZimmerLebenBild(zimmer: zimmer, person: person, nacht: zeit.dunkel, welt: .panorama)) }) { f in
            buehnenFigur(f)
        } paar: {
            // Teil 2 (Nähe): the pair's closeness pose (kiss glides into Stufe 3 and back).
            KussPaar(vorn: person, stufe: NaeheLogik.aktuelleStufe, zusammen: NaeheLogik.sindZusammen) { p, pose, ebene in
                figur(p, naehe: pose, ebene: ebene)
            }
        }
        // p62: the room's living objects (wall, shelf, plant, goal); their taps sit on top, small.
        .overlay { ZimmerLebenTippen(zimmer: zimmer, person: person, welt: .panorama) }
        .overlay { PaarSignaleEbene(blatt: $signale, welt: .panorama) }
        .overlay { AlltagEbene(welt: .panorama) }
    }

    /// A walker, sitter or sleeper of the home scene: their own look and badges, the state and size
    /// the stage asks for. Tapping the partner opens the gesture menu, like the figure always did.
    @ViewBuilder
    private func buehnenFigur(_ f: ZuhauseFigur) -> some View {
        let aussehen = FigurenModell.shared.aussehen(f.person)
        let v = FigurView(aussehen, zustand: f.zustand, abzeichen: abzeichen(f.person), groesse: f.groesse,
                          animiert: f.animiert, bildrate: f.bildrate, ganzkoerper: f.ganzkoerper, pose: f.pose)
        // p65: a sitter on the sofa is placed for a middle-sized body; the others move by the difference of their seat height.
        let sitzKorrektur = f.pose == .sitzenSofa ? FigurPoseLogik.sitzKorrektur(stufe: aussehen.groesse, hoehe: f.groesse) : 0
        Group {
            if f.person == ich {
                v.accessibilityLabel("Deine Figur")
            } else {
                v.figurGesten(person: f.person) { FigurenModell.shared.gesteSenden($0) }
            }
        }
        .overlay(alignment: .top) {
            // p60: the mood bubble above the head; the sleepers in the bed have none.
            if f.zustand != .schlaeft {
                StimmungBlase(person: f.person, figurHoehe: f.groesse, ganzkoerper: f.ganzkoerper) { signale = .stimmung }
            }
        }
        .offset(y: sitzKorrektur)
    }

    /// Brief G: the editor for the place the person is at right now (home, office, classroom),
    /// home from anywhere else.
    private func zimmerGestalten() {
        zimmerOrt = ProfilSzene.fuer(person: person).raumOrt ?? .zuhause
        blatt = .zimmer
    }

    /// Z-34.2: weather and "hört gerade" moved here from the chat header. p65: they sit in the calm part
    /// under the scene now, not on the picture, so they use the normal scheme. Spotify is polled
    /// only while this is on screen (Spec 9).
    private var partnerJetzt: some View {
        HStack(spacing: 6) {
            if let stand = WetterModell.shared.partner { WetterChip(stand: stand) }
            SpotifyHoertGeradeChip()
        }
    }

    /// Z-24.3: while a `kuss` is live (fresh receive, own optimistic send, or a missed-kiss replay
    /// — all three go through `FigurenModell.anzeige`/`geste`), the figure leans toward the other
    /// one. Annika stands left, Ahmed right (Brief G fix), so they lean opposite directions.
    /// `szene` (Brief G, profile person only): the scene's state and extras (dumbbells in the gym,
    /// umbrella or sunglasses outside). A sleeper outside the room (no bed there) stands asleep;
    /// from 22:00 an awake figure is tired and yawns now and then.
    /// `naehe` (Teil 2 Nähe): the pair's closeness pose (level hug or kiss) while together; it
    /// replaces the lean. `ebene` splits the pair's bodies from their pair arms (see `KussPaarBild`).
    /// `handy` (Teil 2): apart, the small "looks at phone and smiles" sign.
    @ViewBuilder
    private func figur(_ p: Person, szene: ProfilSzene? = nil, naehe: NaehePose? = nil, ebene: PaarEbene = .alles, handy: Bool = false) -> some View {
        // Their own shared state even while their app is closed (it arrives in the background too),
        // so both phones show the same; grey "offline" only when nothing was ever shared.
        let live = ProfilSzene.geteilterZustand(p) ?? .offline
        let schlaf = ProfilSzene.schlafGerade(p)
        let schlaeft = schlaf != .wach
        let zustand: FigurZustand = schlaf == .schlaeft ? .schlaeft : (schlaf == .sitzt ? .sitztImBett : (szene?.figur(live) ?? live))
        // Ein Kuss gehört beiden: küsst einer, gleiten beide zueinander, neigen sich und spitzen die Lippen.
        let kuesst = live == .kuss || FigurenModell.shared.anzeige(p.partner).haupt == .kuss
        let richtung: CGFloat = p == .annika ? 1 : -1
        let wetter = WetterModell.shared.staende[p]
        let spaet = !schlaeft && ProfilSzene.spaet(stunde: Calendar.berlin.component(.hour, from: Date()))
        // The kiss needs its arm: no umbrella or dumbbells for those 4 s.
        let szenenExtras: Set<FigurExtra> = kuesst ? [] : szene?.extras(zustand, wetterCode: wetter?.code, temperatur: wetter?.temperatur) ?? []
        let extras = spaet ? szenenExtras.union([.schlaefrig]) : szenenExtras
        let tisch = szene?.raumOrt.map { Zimmer.von(person, ort: $0).tisch } ?? 0
        // Alone (own profile, next to a bed) the kiss is still the lean; the pair's closeness pose replaces it.
        let lehnt = kuesst && naehe == nil
        let gezeigt: FigurZustand = naehe?.zustand(p) ?? (kuesst ? .kuss : (handy && [.ruhig, .mittel, .gut].contains(zustand) ? .imChat : zustand))
        let paarExtras: Set<FigurExtra> = naehe == nil ? extras : []
        // Brief Z: the pencil and its strokes live in the figure; 15 fps like the scene's lights.
        let umarmung: Umarmung? = naehe.map { pose in
            var um = pose.umarmung(p, partnerHaut: NaehePose.haut(FigurenModell.shared.aussehen(p.partner)))
            um.ebene = ebene
            return um
        }
        let v = FigurView(FigurenModell.shared.aussehen(p), zustand: gezeigt, abzeichen: abzeichen(p), groesse: 340, bildrate: gezeigt == .zeichnet ? 15 : 30,
                          ganzkoerper: true, extras: paarExtras, tisch: tisch, umarmung: umarmung,
                          gymGeste: gezeigt == .gym ? GymGeste.fuer(id: TrainingModell.shared.aktiveUebung(p)) : nil)
            .rotationEffect(.degrees(lehnt ? Double(richtung) * 7 : 0), anchor: .bottom)
            .offset(x: lehnt ? richtung * 38 : 0)
            .scaleEffect(lehnt ? 1.05 : 1, anchor: .bottom)
            .animation(.spring(response: 0.45, dampingFraction: 0.62), value: lehnt)
        if p == ich {
            v.accessibilityLabel("Deine Figur")
        } else {
            v.figurGesten(person: p) { FigurenModell.shared.gesteSenden($0) }
        }
    }

    // MARK: - Chips

    private var chips: some View {
        let g = BesondereTage.geburtstag(person)
        let zeichen = Sternzeichen.fuer(monat: g.monat, tag: g.tag)
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip("🎈", "\(g.tag). \(Self.monate[g.monat - 1])", "Geburtstag \(g.tag). \(Self.monate[g.monat - 1])")
                chip("💞", "\(tageZusammen) Tage", "\(tageZusammen) Tage zusammen")
                chip(zeichen.symbol, zeichen.name, "Sternzeichen \(zeichen.name)")
                if istEigenes {
                    PunkteKnopf(person: person)
                }
            }
        }
        .scrollClipDisabled()
    }

    private func chip(_ emoji: String, _ text: String, _ vorlesen: String) -> some View {
        HStack(spacing: 6) {
            Text(emoji)
            Text(text).fontWeight(.semibold)
        }
        .font(.subheadline)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(vorlesen)
    }

    /// Z-25.1: "Chips (Geburtstag, Tage zusammen, Punkte)" — exactly these three, in one line at normal text size.
    /// p69: with large Dynamic Type the line would break (the labels wrap or squeeze), so then it slides sideways.
    private var eigeneChips: some View {
        let g = BesondereTage.geburtstag(person)
        let reihe = HStack(spacing: 8) {
            chip("🎈", "\(g.tag). \(Self.monate[g.monat - 1])", "Geburtstag \(g.tag). \(Self.monate[g.monat - 1])")
            chip("💞", "\(tageZusammen) Tage", "\(tageZusammen) Tage zusammen")
            punkteChip
        }
        return ViewThatFits(in: .horizontal) {
            reihe
            ScrollView(.horizontal, showsIndicators: false) { reihe }.scrollClipDisabled()
        }
    }

    /// Spendable balance (after purchases), same number as the Health tab and the Shop.
    private var punkteChip: some View { PunkteKnopf(person: person) }

    // MARK: - Eigene Aktionen (Z-25.1: Figur bearbeiten, Shop; Brief G: Zimmer gestalten)

    /// p65: the three buttons carry their names (Profil, Zimmer, Kleidung). "Profil" is the figure only,
    /// "Kleidung" the wardrobe.
    private var eigeneAktionen: some View {
        HStack(spacing: 8) {
            beschriftet("person.crop.square", "Profil") { figurBearbeitenOffen = true }
            beschriftet("bed.double.fill", "Zimmer") { zimmerGestalten() }
            beschriftet("tshirt.fill", "Kleidung") { kleidungOffen = true }
        }
    }

    /// p68: Ahmed changes Annika's figure and clothes from her profile. Only where `figurBearbeitbar`
    /// allows it, so on Ahmed's profile (seen by Annika) there is nothing to tap.
    @ViewBuilder private var partnerBearbeiten: some View {
        if person.figurBearbeitbar(durch: ich) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    beschriftet("person.crop.square", "Figur") { figurBearbeitenOffen = true }
                    beschriftet("tshirt.fill", "Kleidung") { kleidungOffen = true }
                }
                Text("\(person.name) bearbeiten. Was du im Shop für sie kaufst, zahlst du.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
                AppKannHinweis(person: person)
            }
        }
    }

    private func beschriftet(_ symbol: String, _ titel: String, _ tun: @escaping () -> Void) -> some View {
        Button(action: tun) {
            Label(titel, systemImage: symbol)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, minHeight: ProfilLayout.tippMinimum)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .controlSize(.large)
        .tint(Color.loveaRose)
    }

    // MARK: - Actions (Kamera · Chat · FaceTime Audio · FaceTime Video)

    /// Z-32.2: the partner's `kontakt.facetime` (number or Apple ID); empty → the older `telefon`
    /// entry, so numbers typed in before Runde 3 keep working. Same rule as the chat header.
    private var partnerKontakt: String {
        let kontakt = EinstellungenModell.shared.string("kontakt.facetime", default: "", von: gegenueber)
        return kontakt.trimmingCharacters(in: .whitespaces).isEmpty
            ? EinstellungenModell.shared.string("telefon", default: "", von: gegenueber)
            : kontakt
    }

    private var aktionen: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                // Kamera: switches to Chat, which opens the snap camera via `AppNavigation.kameraOeffnen`.
                aktion("camera.fill", "Kamera") {
                    AppNavigation.shared.kameraOeffnen = true
                    navigieren("chat")
                }
                aktion("message.fill", "Chat") { navigieren("chat") }
                aktion("phone.fill", "FaceTime Audio") { anrufen(audio: true) }
                aktion("video.fill", "FaceTime Video") { anrufen(audio: false) }
            }
            if FaceTime.url(audio: false, kontakt: partnerKontakt) == nil {
                Text("\(gegenueber.name) hat noch keine FaceTime-Nummer eingetragen")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            }
        }
    }

    private func aktion(_ symbol: String, _ titel: String, _ tun: @escaping () -> Void) -> some View {
        Button(action: tun) {
            Image(systemName: symbol)
                .font(.title3)
                .frame(maxWidth: .infinity, minHeight: ProfilLayout.tippMinimum)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .controlSize(.large)
        .tint(Color.loveaRose)
        .accessibilityLabel(titel)
    }

    private func navigieren(_ tab: String, suche: Bool = false) {
        tipps += 1
        if suche { AppNavigation.shared.chatSuche = true } else if tab == "chat" { AppNavigation.shared.gespraechOeffnen = true }
        AppNavigation.shared.tabWunsch = tab
        schliessen()
    }

    private func anrufen(audio: Bool) {
        guard let url = FaceTime.url(audio: audio, kontakt: partnerKontakt) else {
            nummerFehlt += 1
            return
        }
        tipps += 1
        openURL(url)
    }

    // MARK: - Sections

    private func zeile(_ symbol: String, _ titel: String, _ untertitel: String? = nil, farbe: Color = .loveaRose, _ tun: @escaping () -> Void) -> some View {
        Button {
            tipps += 1
            tun()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.title3)
                    .foregroundStyle(farbe)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(titel).font(.body.weight(.semibold)).foregroundStyle(.primary)
                    if let untertitel {
                        Text(untertitel).font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .frame(minHeight: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var trenner: some View { Divider().padding(.leading, 58) }

    /// Z-34.2: Backdrop (full-screen picker, for both), then Medien and Sterne.
    @ViewBuilder
    private var unserChat: some View {
        zeile("photo.artframe", "Backdrop", backdropUntertitel) { backdropOffen = true }
        trenner
        zeile("photo.on.rectangle.angled", "Wallpaper", "Du und \(gegenueber.name) seht das Wallpaper.") { blatt = .wallpaper }
        trenner
        zeile("photo.stack", "Medien") { blatt = .medien }
        trenner
        zeile("star", "Sterne") { blatt = .sterne }
        trenner
        zeile("magnifyingglass", "Im Chat suchen") { navigieren("chat", suche: true) }
    }

    private var backdropUntertitel: String {
        switch Backdrops.wahl {
        case .vorlage(let id)?: Backdrops.von(id)?.name ?? Backdrops.neutral.name
        case .foto?: "Eigenes Foto"
        case .zeichnung?: "Eigene Zeichnung"
        case nil: "Für euch beide"
        }
    }

    /// Sterne: close the sheets, switch to the chat and jump to the message (B1's `chatZiel`).
    private func zurNachricht(_ id: String) {
        blatt = nil
        AppNavigation.shared.chatZiel = id
        navigieren("chat")
    }

    @ViewBuilder
    private var dieKarte: some View {
        ProfilKarte(person: gegenueber) { tipps += 1; karteOffen = true }
    }

    // MARK: - Wir (compact)

    @ViewBuilder
    private var wir: some View {
        infoZeile("heart.fill", .loveaRose, andichGedachtText)
        trenner
        infoZeile("sparkles", .orange, "Kennengelernt am 04.07.2026")
        if monatsKrone == person {
            trenner
            infoZeile("crown.fill", .yellow, "Pünktlichste\(person == .annika ? "" : "r") des Monats")
        }
        if !bilanz.isEmpty {
            trenner
            spieleAbschnittInhalt
        }
    }

    /// Z-25.1 "Spiele-Bilanz": the per-game W:L breakdown, shared by the partner profile's compact
    /// `wir` row and the own profile's dedicated section.
    @ViewBuilder
    private var spieleAbschnittInhalt: some View {
        if bilanz.isEmpty {
            infoZeile("gamecontroller.fill", .purple, "Noch keine Spiele gespielt")
        } else {
            infoZeile("gamecontroller.fill", .purple, "Spiele", wert: gesamtKrone.map { "👑 \($0.name)" })
            ForEach(Array(bilanz.enumerated()), id: \.offset) { _, eintrag in
                HStack {
                    Text(eintrag.spiel)
                    Spacer()
                    Text(eintrag.paar ?? "Ahmed \(eintrag.ahmed) : \(eintrag.annika) Annika").monospacedDigit().foregroundStyle(.secondary)
                }
                .font(.subheadline)
                .padding(.leading, 58)
                .padding(.trailing, 16)
                .padding(.vertical, 5)
            }
            Spacer().frame(height: 6)
        }
    }

    private func infoZeile(_ symbol: String, _ farbe: Color, _ text: String, wert: String? = nil) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol).font(.body).foregroundStyle(farbe).frame(width: 28).accessibilityHidden(true)
            Text(text).font(.subheadline.weight(.medium))
            Spacer(minLength: 8)
            if let wert { Text(wert).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary) }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }

    /// Eigenes Profil: wie oft der Partner heute an mich gedacht hat. Partner-Profil: wie oft
    /// ich heute an ihn gedacht habe — sonst wäre die Zahl auf beiden Profilen identisch.
    private var andichGedachtText: String {
        if istEigenes {
            let n = FigurenModell.shared.herzHeute[person.partner] ?? 0
            return "Heute \(n)× an dich gedacht"
        } else {
            let n = FigurenModell.shared.herzHeute[ich] ?? 0
            return "Heute \(n)× an \(person.name) gedacht"
        }
    }

    private var gesamtKrone: Person? {
        let mitSieger = bilanz.filter { $0.paar == nil }
        let ahmedGesamt = mitSieger.reduce(0) { $0 + $1.ahmed }
        let annikaGesamt = mitSieger.reduce(0) { $0 + $1.annika }
        guard ahmedGesamt != annikaGesamt else { return nil }
        return ahmedGesamt > annikaGesamt ? .ahmed : .annika
    }

    // MARK: - Abzeichen (Z-15.3)

    private func abzeichen(_ p: Person) -> [String] {
        var alle = Set(FigurenModell.shared.anzeige(p).abzeichen)
        let kalender = KalenderModell.shared.zustand
        // Ungesetzt fällt auf den Beziehungsbeginn zurück (26.08.2026) statt auf "nie".
        let jahrestag = Datum.datum(kalender.jahrestag ?? "2026-08-26")
        let dateHeute = kalender.daten.treffen.contains { $0.datum == Datum.text(Date()) }
        alle.formUnion(BesondereTage.abzeichen(person: p, datum: Date(), jahrestag: jahrestag, dateHeute: dateHeute))
        if monatsKrone == p { alle.insert("krone") }
        return Array(alle)
    }

    private var monatsKrone: Person? {
        let monat = String(Datum.text(Date()).prefix(7))
        return Puenktlich.monatsKrone(ops: KalenderModell.shared.alleOps, monat: monat)
    }

    private var tageZusammen: Int { Datum.tageZwischen("2026-08-26", Datum.text(Date())) }
}

/// Z-24.3/Z-23.2: the kiss-animation and gift-celebration side effects, pulled out of
/// `ProfilInhalt.body` into their own `ViewModifier` — common.md warns long body modifier chains
/// risk "unable to type-check in reasonable time" (hit Runde 1).
private struct KussUndGeschenkReaktionen: ViewModifier {
    let istEigenes: Bool
    let person: Person
    @Binding var kussBasislinie: Int
    @Binding var kussHaptik: Int
    @Binding var geschenkArtikel: ShopArtikel?
    @Binding var geschenkHaptik: Int

    func body(content: Content) -> some View {
        content
            .sensoryFeedback(.impact(flexibility: .soft), trigger: kussHaptik)
            .sensoryFeedback(.success, trigger: geschenkHaptik)
            .overlay(alignment: .top) { geschenkBanner }
            .onAppear {
                missedKussPruefen()
                geschenkPruefen()
            }
            .onChange(of: FigurenModell.shared.kussEreignis) { _, neu in
                guard !istEigenes, neu > kussBasislinie else { return }
                kussBasislinie = neu
                KussTon.spielen()
                kussHaptik += 1
                // Live gezeigt: Marke direkt mit aktualisieren, sonst spielt `missedKussPruefen`
                // denselben Kuss beim nächsten Öffnen dieses Profils nochmal ab.
                if let zeit = FigurenModell.shared.letzterKuss[person] {
                    UserDefaults.standard.set(zeit, forKey: "kussGesehen.\(person.rawValue)")
                }
            }
    }

    /// Z-24.3: a kiss sent/received while this screen wasn't open — plays the live visual once,
    /// the next time the partner profile is opened. `letzterKuss` tracks every delivery (not just
    /// the 4s-fresh window `kussEreignis`/`geste` use), so a missed one is never silently lost.
    /// Only bumps `kussReplay` here — `onChange` above is the SINGLE place that plays sound/haptic,
    /// so a missed kiss and a live one never double-trigger it.
    private func missedKussPruefen() {
        guard !istEigenes else { return }
        let schluessel = "kussGesehen.\(person.rawValue)"
        guard UserDefaults.standard.object(forKey: schluessel) != nil else {
            // Erster Check auf diesem Gerät: Basislinie setzen, auch ohne bisherigen Kuss — sonst
            // bekommt die Marke NIE einen Wert und der allererste echte Kuss würde nie erkannt.
            UserDefaults.standard.set(FigurenModell.shared.letzterKuss[person] ?? .distantPast, forKey: schluessel)
            return
        }
        guard let zeit = FigurenModell.shared.letzterKuss[person] else { return }
        let gesehen = UserDefaults.standard.object(forKey: schluessel) as? Date ?? .distantPast
        guard gesehen < zeit else { return }
        UserDefaults.standard.set(zeit, forKey: schluessel)
        FigurenModell.shared.kussReplay(person)
    }

    /// Z-23.2: a gift that arrived while nobody was looking — celebrated once, on the own profile.
    private func geschenkPruefen() {
        guard istEigenes else { return }
        let erhalten = PunkteModell.shared.geschenkeErhalten(person, preis: { ShopKatalog.artikel($0)?.preis })
        let schluessel = "geschenkGesehen.\(person.rawValue)"
        guard UserDefaults.standard.object(forKey: schluessel) != nil else {
            // Gleicher Fix wie beim Kuss: Basislinie auch bei (noch) leerer Historie setzen, sonst
            // gibt es beim allerersten echten Geschenk nie eine Marke zum Vergleichen dagegen.
            UserDefaults.standard.set(erhalten.first?.seq ?? 0, forKey: schluessel)
            return
        }
        guard let neuestes = erhalten.first, let seq = neuestes.seq else { return }
        let gesehen = UserDefaults.standard.integer(forKey: schluessel)
        guard seq > gesehen else { return }
        UserDefaults.standard.set(seq, forKey: schluessel)
        withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) {
            geschenkArtikel = ShopKatalog.artikel(neuestes.artikel)
        }
        geschenkHaptik += 1
    }

    @ViewBuilder
    private var geschenkBanner: some View {
        if let geschenkArtikel {
            HStack(spacing: 10) {
                Text("🎁").font(.system(size: 26))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Geschenk erhalten!").font(.subheadline.weight(.semibold))
                    Text(geschenkArtikel.name).font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .glassEffect(.regular.interactive(), in: .capsule)
            .padding(.top, 8)
            .onTapGesture { withAnimation { self.geschenkArtikel = nil } }
            .transition(.scale.combined(with: .opacity))
            .task(id: geschenkArtikel.id) {
                try? await Task.sleep(for: .seconds(3.5))
                withAnimation { self.geschenkArtikel = nil }
            }
        }
    }
}
