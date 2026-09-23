import AVFoundation
import SwiftUI

/// Block 18: profile like Snapchat's friend profile. Same layout for the own profile (tab, gear to
/// Einstellungen) and the partner's (sheet from Chat/Karte).
struct ProfileView: View {
    let person: Person
    @ObservedObject var session: PersonSession
    /// Spiele-Bilanz aus Block 14 (`SpieleModell`), vom Controller in `AppRootView.swift` verdrahtet.
    var bilanz: [(spiel: String, ahmed: Int, annika: Int)] = []

    var body: some View {
        NavigationStack {
            ProfilInhalt(person: person, bilanz: bilanz, schliessen: {})
                .toolbar {
                    if person == session.person {
                        ToolbarItem(placement: .primaryAction) {
                            NavigationLink { EinstellungenView(person: person, session: session) } label: {
                                Label("Einstellungen", systemImage: "gearshape.fill")
                            }
                        }
                    }
                }
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
    }

    private var bilanz: [(spiel: String, ahmed: Int, annika: Int)] {
        SpielArt.allCases.compactMap { art in
            guard let p = SpieleModell.shared.bilanz[art] else { return nil }
            return (art.titel, p.ahmed, p.annika)
        }
    }
}

private enum ProfilBlatt: String, Identifiable {
    case wallpaper, chatfarbe, medien, hintergrund, orte, eigenerHintergrund, chatThema, flamme
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
    let bilanz: [(spiel: String, ahmed: Int, annika: Int)]
    /// Closes the partner sheet before a tab switch; no-op in the tab.
    let schliessen: () -> Void

    @Environment(\.openURL) private var openURL
    @State private var dehnung: CGFloat = 0
    @State private var tipps = 0
    @State private var nummerFehlt = 0
    @State private var blatt: ProfilBlatt?
    /// Z-19.1: Karte ist kein Tab mehr, sie öffnet sich vollflächig über die Karten-Vorschau.
    @State private var karteOffen = false
    // Z-25.1: eigenes Profil (Figur bearbeiten, Shop).
    @State private var figurBearbeitenOffen = false
    @State private var shopOffen = false
    // Z-24.3: Kuss-Animation im Partner-Profil. `kussBasislinie` liest den Ausgangswert beim
    // Erstellen dieser View — spätere Erhöhungen sind dann eindeutig "neu seit dem Öffnen".
    @State private var kussBasislinie = FigurenModell.shared.kussEreignis
    @State private var kussHaptik = 0
    // Z-23.2: "Geschenk erhalten"-Feier im eigenen Profil.
    @State private var geschenkArtikel: ShopArtikel?
    @State private var geschenkHaptik = 0

    private static let kopfHoehe: CGFloat = 430
    private static let monate = ["Januar", "Februar", "März", "April", "Mai", "Juni", "Juli", "August", "September", "Oktober", "November", "Dezember"]

    private var ich: Person { Raum.shared.ich ?? person }
    /// Whom the chat/call buttons reach: always the partner, also from the own profile.
    private var gegenueber: Person { ich.partner }
    private var istEigenes: Bool { person == ich }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if istEigenes { eigenerKopf } else { kopf }
                VStack(alignment: .leading, spacing: 24) {
                    if istEigenes {
                        eigeneChips
                        eigeneAktionen
                        abschnitt("Spiele-Bilanz") { spieleAbschnittInhalt }
                    } else {
                        chips
                        aktionen
                        abschnitt("Unser Chat") { unserChat }
                        // Z-19.1 / Spec 2: Karte öffnet sich nur über das Partner-Profil, nicht das eigene.
                        abschnitt("Die Karte") { dieKarte }
                        abschnitt("Wir") { wir }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 32)
            }
        }
        .ignoresSafeArea(edges: .top)
        .onScrollGeometryChange(for: CGFloat.self) { geo in
            max(0, -(geo.contentOffset.y + geo.contentInsets.top))
        } action: { _, neu in
            dehnung = neu
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.impact(weight: .medium), trigger: tipps)
        .sensoryFeedback(.warning, trigger: nummerFehlt)
        .sensoryFeedback(.impact(weight: .light), trigger: dehnung > 90) { _, neu in neu }
        .sheet(item: $blatt) { b in blattInhalt(b) }
        .fullScreenCover(isPresented: $karteOffen) { KarteTab(schliessen: { karteOffen = false }) }
        .sheet(isPresented: $figurBearbeitenOffen) { NavigationStack { FigurEditorSeite(person: person) } }
        .sheet(isPresented: $shopOffen) { ShopView() }
        .modifier(KussUndGeschenkReaktionen(
            istEigenes: istEigenes, person: person, kussBasislinie: $kussBasislinie, kussHaptik: $kussHaptik,
            geschenkArtikel: $geschenkArtikel, geschenkHaptik: $geschenkHaptik
        ))
    }

    /// common.md warns a long `body` modifier chain risks "unable to type-check in reasonable
    /// time" (hit Runde 1) — the `blatt` switch is split out for the same reason.
    @ViewBuilder
    private func blattInhalt(_ b: ProfilBlatt) -> some View {
        switch b {
        case .wallpaper: WallpaperAuswahl(partner: gegenueber)
        case .chatfarbe: ChatFarbeAuswahl(ich: ich)
        case .medien: MedienUebersicht(ich: ich)
        case .hintergrund: ChatHintergrundEinstellung(ich: ich)
        case .orte: OrteListeView()
        case .eigenerHintergrund: EigenerHintergrundAuswahl(person: person)
        case .chatThema: ChatThemaAuswahl(ich: ich)
        case .flamme: BesitzFlammenAuswahl(ich: ich)
        }
    }

    // MARK: - Header (stretchy wallpaper, both figures, avatar + name)

    /// The container keeps a fixed height; only the wallpaper behind it grows upwards while pulling
    /// down, so nothing below shifts and feeds back into the scroll offset.
    private var kopf: some View {
        ZStack(alignment: .bottomLeading) {
            HStack(alignment: .bottom, spacing: -64) {
                figur(person).zIndex(1)
                figur(person.partner)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.trailing, -6)

            HStack(spacing: 12) {
                avatar
                VStack(alignment: .leading, spacing: 2) {
                    Text(person.name).font(.title.bold())
                    Text("zusammen seit 26.08.2026").font(.subheadline.weight(.medium)).opacity(0.9)
                }
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.4), radius: 6, y: 1)
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity)
        .frame(height: Self.kopfHoehe)
        .background(alignment: .bottom) {
            // Z-25.2 "jeder stellt nur seinen eigenen ein": the partner profile shows the
            // partner's own background too, not the old shared one — `EigenerHintergrund`
            // falls back to the shared `profilWallpaper` on its own if `person` hasn't set one.
            EigenerHintergrund(person: person)
                .frame(height: Self.kopfHoehe + dehnung)
                .overlay { kopfSchatten }
        }
    }

    /// Z-25.1: own profile only — the person's own `profil.hintergrund`, a single full-body figure,
    /// name and a "Hintergrund ändern" tap target (no partner figure, no "Unser Chat", no steps).
    private var eigenerKopf: some View {
        ZStack(alignment: .bottomLeading) {
            figur(person)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 20)
            HStack(spacing: 12) {
                avatar
                Text(person.name).font(.title.bold())
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.4), radius: 6, y: 1)
            }
            .padding(16)
            Image(systemName: "pencil.circle.fill")
                .font(.title2)
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.5), radius: 4)
                .padding(14)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        }
        .frame(maxWidth: .infinity)
        .frame(height: Self.kopfHoehe)
        .background(alignment: .bottom) {
            EigenerHintergrund(person: person)
                .frame(height: Self.kopfHoehe + dehnung)
                .overlay { kopfSchatten }
        }
        .onTapGesture { blatt = .eigenerHintergrund }
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Ändert deinen Profil-Hintergrund")
    }

    private var kopfSchatten: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [.black.opacity(0.35), .clear], startPoint: .top, endPoint: .bottom).frame(height: 130)
            Spacer(minLength: 0)
            LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .top, endPoint: .bottom).frame(height: 170)
        }
    }

    /// Z-24.3: while a `kuss` is live (fresh receive, own optimistic send, or a missed-kiss replay
    /// — all three go through `FigurenModell.anzeige`/`geste`), the figure leans toward the other
    /// one. `person` sits left/front of the pair (see `kopf`'s HStack order), `person.partner`
    /// right/behind, so they lean opposite directions.
    @ViewBuilder
    private func figur(_ p: Person) -> some View {
        let zustand = FigurenModell.shared.anzeige(p).haupt
        let kuesst = zustand == .kuss
        let richtung: CGFloat = p == person ? 1 : -1
        let v = FigurView(FigurenModell.shared.aussehen(p), zustand: zustand, abzeichen: abzeichen(p), groesse: 340, ganzkoerper: true, poseImmer: true)
            .offset(x: kuesst ? richtung * 14 : 0)
            .scaleEffect(kuesst ? 1.04 : 1, anchor: .bottom)
            .animation(.spring(response: 0.35, dampingFraction: 0.6), value: kuesst)
        if p == ich {
            v.accessibilityLabel("Deine Figur")
        } else {
            v.figurGesten(person: p) { FigurenModell.shared.gesteSenden($0) }
        }
    }

    /// Round head crop of the figure. The head sits at y 30…152 of FigurView's 240-unit canvas,
    /// centre ≈ 0.38 of the height — at `groesse = 1.6d` that is 0.19·d above the view centre.
    private var avatar: some View {
        let d: CGFloat = 84
        let online = istEigenes ? Raum.shared.verbunden : Raum.shared.partnerDa
        return FigurView(FigurenModell.shared.aussehen(person), zustand: .ruhig, groesse: d * 1.6, animiert: false)
            .offset(y: d * 0.19)
            .frame(width: d, height: d)
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(Circle())
            .overlay(Circle().stroke(.white, lineWidth: 3))
            .overlay(alignment: .bottomTrailing) {
                if online {
                    Circle().fill(.green)
                        .frame(width: 18, height: 18)
                        .overlay(Circle().stroke(.white, lineWidth: 2.5))
                        .offset(x: -2, y: -2)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(person.name), \(online ? "online" : "offline")")
    }

    // MARK: - Chips

    private var chips: some View {
        let g = BesondereTage.geburtstag(person)
        let zeichen = Sternzeichen.fuer(monat: g.monat, tag: g.tag)
        let streak = ChatModell.shared.streak.tage
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip("🎈", "\(g.tag). \(Self.monate[g.monat - 1])", "Geburtstag \(g.tag). \(Self.monate[g.monat - 1])")
                chip("💞", "\(tageZusammen) Tage", "\(tageZusammen) Tage zusammen")
                if streak > 0 {
                    chip(EinstellungenModell.shared.string("flamme", default: "🔥"), "\(streak)", "Streak \(streak) Tage")
                }
                chip(zeichen.symbol, zeichen.name, "Sternzeichen \(zeichen.name)")
                if istEigenes {
                    PunkteChip(person: person)
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

    /// Z-25.1: "Chips (Geburtstag, Tage zusammen, Punkte)" — exactly these three, and no
    /// `ScrollView` (kein seitliches Scrollen): three chips fit one line at any phone width.
    private var eigeneChips: some View {
        let g = BesondereTage.geburtstag(person)
        return HStack(spacing: 8) {
            chip("🎈", "\(g.tag). \(Self.monate[g.monat - 1])", "Geburtstag \(g.tag). \(Self.monate[g.monat - 1])")
            chip("💞", "\(tageZusammen) Tage", "\(tageZusammen) Tage zusammen")
            punkteChip
        }
    }

    /// Spendable balance (after purchases), same number as the Health tab and the Shop.
    private var punkteChip: some View { PunkteChip(person: person) }

    // MARK: - Eigene Aktionen (Z-25.1: Figur bearbeiten, Shop)

    private var eigeneAktionen: some View {
        HStack(spacing: 10) {
            aktion("person.crop.square", "Figur bearbeiten") { figurBearbeitenOffen = true }
            aktion("bag.fill", "Shop") { shopOffen = true }
        }
    }

    // MARK: - Actions (Kamera · Chat · FaceTime Audio · FaceTime Video)

    private var partnerNummer: String { EinstellungenModell.shared.string("telefon", default: "", von: gegenueber) }

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
            if FaceTimeLink.url(partnerNummer, audio: false) == nil {
                Text("\(gegenueber.name) hat noch keine Nummer eingetragen")
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
                .frame(maxWidth: .infinity, minHeight: 36)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .controlSize(.large)
        .tint(Color.loveaRose)
        .accessibilityLabel(titel)
    }

    private func navigieren(_ tab: String, suche: Bool = false) {
        tipps += 1
        if suche { AppNavigation.shared.chatSuche = true }
        AppNavigation.shared.tabWunsch = tab
        schliessen()
    }

    private func anrufen(audio: Bool) {
        guard let url = FaceTimeLink.url(partnerNummer, audio: audio) else {
            nummerFehlt += 1
            return
        }
        tipps += 1
        openURL(url)
    }

    // MARK: - Sections

    private func abschnitt<Inhalt: View>(_ titel: String, @ViewBuilder _ inhalt: () -> Inhalt) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(titel).font(.title3.bold()).padding(.horizontal, 4)
            VStack(spacing: 0) { inhalt() }
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
                .clipShape(RoundedRectangle(cornerRadius: 18))
        }
    }

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

    @ViewBuilder
    private var unserChat: some View {
        zeile("photo.on.rectangle.angled", "Wallpaper", "Du und \(gegenueber.name) seht das Wallpaper.") { blatt = .wallpaper }
        trenner
        zeile("circle.fill", "Chatfarbe", "Ändere die Farbe deines Namens.", farbe: ChatFarbe.farbe(ich)) { blatt = .chatfarbe }
        trenner
        zeile("photo.stack", "Medien") { blatt = .medien }
        trenner
        zeile("photo.artframe", "Chat-Hintergrund") { blatt = .hintergrund }
        trenner
        // Z-23.2: gekaufte Chat-Themes/Flammen werden hier gewählt — der Kauf selbst passiert im Shop.
        zeile("paintpalette", "Chat-Thema", chatThemaUntertitel) { blatt = .chatThema }
        trenner
        zeile("flame", "Deine Flamme", flammeUntertitel) { blatt = .flamme }
        trenner
        zeile("magnifyingglass", "Im Chat suchen") { navigieren("chat", suche: true) }
    }

    private var chatThemaUntertitel: String? {
        guard case .string(let id)? = EinstellungenModell.shared.geteilt("chat.theme"), !id.isEmpty else { return "Keins gewählt" }
        return ChatThemes.von(id)?.name
    }

    private var flammeUntertitel: String { EinstellungenModell.shared.string("flamme", default: "🔥", von: ich) }

    @ViewBuilder
    private var dieKarte: some View {
        KartenVorschau(person: gegenueber) { tipps += 1; karteOffen = true }
        Divider()
        zeile("bell.badge", "Ankunftsbenachrichtigungen", "Wenn jemand an einem Ort ankommt oder geht.") { blatt = .orte }
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
                    Text("Ahmed \(eintrag.ahmed) : \(eintrag.annika) Annika").monospacedDigit().foregroundStyle(.secondary)
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
        let ahmedGesamt = bilanz.reduce(0) { $0 + $1.ahmed }
        let annikaGesamt = bilanz.reduce(0) { $0 + $1.annika }
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
