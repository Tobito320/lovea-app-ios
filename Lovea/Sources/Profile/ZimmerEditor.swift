import PhotosUI
import SwiftUI

/// Brief G: one editor per place (home, office, classroom) in the own profile, in the Figuren-Editor's
/// style: live preview on top, tabs Bett or Tisch / Wand / Boden / Deko / Poster / Bilder, tiles drawn
/// with the place itself. A frame photo goes up like the chat's own-photo backdrop before
/// `profil.raeume` is saved, so the partner's phone can fetch it.
struct ZimmerEditor: View {
    let person: Person
    let ort: RaumOrt
    @Environment(\.dismiss) private var dismiss
    @State private var zimmer: Zimmer
    @State private var tab = Tab.moebel
    @State private var nachtVorschau = false
    @State private var fotoAuswahl: PhotosPickerItem?
    @State private var fotoSlot = 0
    @State private var hochladenSlot: Int?
    @State private var fehler: String?

    init(person: Person, ort: RaumOrt = .zuhause) {
        self.person = person
        self.ort = ort
        _zimmer = State(initialValue: Zimmer.von(person, ort: ort))
    }

    private enum Tab: String, CaseIterable, Identifiable {
        case moebel = "Möbel", wand = "Wand", boden = "Boden", deko = "Deko", poster = "Poster", bilder = "Bilder"
        var id: String { rawValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            vorschau
            tabLeiste
            Divider()
            ScrollView {
                inhalt.padding()
            }
            .id(tab)
            Button(action: sichern) {
                Text("Sichern")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.loveaRose)
            .disabled(hochladenSlot != nil)
            .padding()
        }
        .navigationTitle(ort.titel)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
        }
        .onChange(of: fotoAuswahl) { _, neu in fotoUebernehmen(neu) }
    }

    // MARK: - Preview (the own header's scene, scaled down whole)

    private var vorschau: some View {
        let hoehe: CGFloat = 280
        let s = hoehe / SzenenZeichnung.hoehe
        return ZStack(alignment: .bottom) {
            ProfilSzeneHintergrund(szene: szene, zimmer: zimmer, nacht: nachtVorschau && ort == .zuhause)
            FigurView(FigurenModell.shared.aussehen(person), zustand: szene.figur(.ruhig), groesse: 340 * s, ganzkoerper: true, poseImmer: ort == .zuhause, tisch: zimmer.tisch)
        }
        .frame(width: SzenenZeichnung.breite * s, height: hoehe)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Vorschau deines Zimmers")
        .overlay(alignment: .topTrailing) { if ort == .zuhause { nachtKnopf } }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(LinearGradient(colors: [Color.loveaRose.opacity(0.16), Color.loveaRose.opacity(0.02)], startPoint: .top, endPoint: .bottom))
    }

    /// Floats over the picture, so glass fits here.
    private var nachtKnopf: some View {
        Button {
            withAnimation(Feder.weich) { nachtVorschau.toggle() }
            Haptik.auswahl()
        } label: {
            Image(systemName: nachtVorschau ? "sun.max.fill" : "moon.stars.fill")
                .font(.body.weight(.semibold))
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .padding(8)
        .accessibilityLabel(nachtVorschau ? "Bei Tag zeigen" : "Bei Nacht zeigen")
    }

    private var tabLeiste: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Tab.allCases) { t in
                    Button(titel(t)) {
                        withAnimation(Feder.schnell) { tab = t }
                        Haptik.auswahl()
                    }
                    .buttonStyle(.plain)
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14)
                    .frame(minHeight: 44)
                    .background(Capsule().fill(t == tab ? Color.loveaRose.opacity(0.18) : Color(uiColor: .secondarySystemBackground)))
                    .foregroundStyle(t == tab ? Color.loveaRose : Color.primary)
                    .accessibilityAddTraits(t == tab ? .isSelected : [])
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
    }

    @ViewBuilder
    private var inhalt: some View {
        switch tab {
        case .moebel:
            if ort == .zuhause { kacheln(Zimmer.betten, \.bett, art: .bett) } else { kacheln(Zimmer.tische, \.tisch, art: .tisch) }
        case .wand: kacheln(Zimmer.waende, \.wand, art: .raum)
        case .boden: kacheln(Zimmer.boeden, \.boden, art: .raum)
        case .deko: deko
        case .poster: kacheln(Zimmer.posterArten, \.poster, art: .poster)
        case .bilder: bilder
        }
    }

    // MARK: - Bett, Wand, Boden

    private func probe(_ pfad: WritableKeyPath<Zimmer, Int>, _ i: Int) -> Zimmer {
        var z = zimmer
        z[keyPath: pfad] = i
        return z
    }

    private func kacheln(_ namen: [String], _ pfad: WritableKeyPath<Zimmer, Int>, art: ZimmerKachel.Art) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 10)], spacing: 10) {
            ForEach(namen.indices, id: \.self) { i in
                let gewaehlt = zimmer[keyPath: pfad] == i
                Button {
                    withAnimation(Feder.schnell) { zimmer[keyPath: pfad] = i }
                    Haptik.auswahl()
                } label: {
                    VStack(spacing: 4) {
                        ZimmerKachel(zimmer: probe(pfad, i), ort: ort, art: art, aussehen: FigurenModell.shared.aussehen(person))
                            .frame(height: 84)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        Text(namen[i]).font(.caption.weight(.semibold)).foregroundStyle(Color.primary)
                    }
                    .padding(6)
                    .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(gewaehlt ? Color.loveaRose : .clear, lineWidth: 3))
                }
                .buttonStyle(.federnd)
                .accessibilityLabel(namen[i])
                .accessibilityAddTraits(gewaehlt ? .isSelected : [])
            }
        }
    }

    // MARK: - Deko

    private var deko: some View {
        VStack(spacing: 4) {
            let arten = Zimmer.dekoArten(fuer: ort)
            ForEach(arten.indices, id: \.self) { i in
                let d = arten[i]
                Toggle(d.name, isOn: Binding(
                    get: { zimmer.hat(d.id) },
                    set: { an in
                        withAnimation(Feder.schnell) {
                            if an { zimmer.deko.append(d.id) } else { zimmer.deko.removeAll { $0 == d.id } }
                        }
                        Haptik.auswahl()
                    }
                ))
                .font(.headline)
                .tint(Color.loveaRose)
                .frame(minHeight: 44)
            }
        }
    }

    // MARK: - Bilder (up to 3 real photos in the wall frames)

    private var bilder: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Bis zu drei Fotos für die Rahmen an deiner Wand.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                ForEach(0..<Zimmer.rahmenPlaetze, id: \.self) { slot in rahmenKachel(slot) }
            }
            if let fehler {
                Text(fehler).font(.footnote.weight(.semibold)).foregroundStyle(.red)
            }
        }
    }

    private func rahmenKachel(_ slot: Int) -> some View {
        let medienId = zimmer.medien(slot)
        let auswahl = Binding<PhotosPickerItem?>(get: { fotoAuswahl }, set: { neu in
            fotoSlot = slot
            fotoAuswahl = neu
        })
        return PhotosPicker(selection: auswahl, matching: .images) {
            ZStack {
                if let medienId {
                    ProfilFoto(medienId: medienId)
                } else {
                    Image(systemName: "plus").font(.title2.weight(.semibold)).foregroundStyle(Color.loveaRose)
                }
                if hochladenSlot == slot { ProgressView() }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 120)
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.federnd)
        .disabled(hochladenSlot != nil)
        .accessibilityLabel(medienId == nil ? "Foto für Rahmen \(slot + 1) wählen" : "Foto in Rahmen \(slot + 1) ändern")
        .overlay(alignment: .topTrailing) {
            if medienId != nil {
                Button {
                    withAnimation(Feder.schnell) { zimmer.rahmen.removeAll { $0.slot == slot } }
                    Haptik.leicht()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(Color.white, Color.black.opacity(0.55))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Foto aus Rahmen \(slot + 1) entfernen")
            }
        }
    }

    private func fotoUebernehmen(_ item: PhotosPickerItem?) {
        guard let item else { return }
        fotoAuswahl = nil // lets the same photo be picked again after a failed upload
        let slot = fotoSlot
        Task {
            guard let daten = try? await item.loadTransferable(type: Data.self) else {
                fehler = "Das Foto konnte nicht geladen werden."
                return
            }
            await hochladen(daten, slot: slot)
        }
    }

    /// Same path as `BackdropAuswahl`: encode off the main actor, keep the local original for
    /// instant display, upload, and only then put it in the frame.
    private func hochladen(_ daten: Data, slot: Int) async {
        let id = UUID().uuidString
        hochladenSlot = slot
        fehler = nil
        defer { hochladenSlot = nil }
        guard let ergebnis = await Task.detached(priority: .userInitiated, operation: { MedienKodierung.foto(daten, id: id) }).value else {
            fehler = "Das Bild konnte nicht gelesen werden."
            return
        }
        ChatMedien.eigeneQuellen[id] = ergebnis.original
        do {
            try await Medien.hochladen(id: id, original: ergebnis.original, klein: ergebnis.klein)
            withAnimation(Feder.federnd) {
                zimmer.rahmen.removeAll { $0.slot == slot }
                zimmer.rahmen.append(Zimmer.Rahmen(slot: slot, medienId: id))
            }
            Haptik.erfolg()
        } catch {
            fehler = "Hochladen hat nicht geklappt. Versuch es gleich nochmal."
        }
    }

    private func sichern() {
        if zimmer != Zimmer.von(person, ort: ort) { zimmer.sichern(ort: ort) }
        Haptik.erfolg()
        dismiss()
    }

    private var szene: ProfilSzene {
        switch ort {
        case .zuhause: .zimmer
        case .arbeit: .arbeit
        case .schule: .schule
        }
    }

    private func titel(_ t: Tab) -> String {
        t == .moebel ? (ort == .zuhause ? "Bett" : "Tisch") : t.rawValue
    }
}

/// A picker tile drawn with the place itself: the whole place with that wall or floor, the bed,
/// the figure at that desk, or the poster.
struct ZimmerKachel: View {
    enum Art { case bett, tisch, raum, poster }

    let zimmer: Zimmer
    let ort: RaumOrt
    let art: Art
    let aussehen: FigurAussehen

    var body: some View {
        switch art {
        case .tisch:
            FigurView(aussehen, zustand: ort == .schule ? .schule : .arbeit, groesse: 150, animiert: false, ganzkoerper: true, tisch: zimmer.tisch)
                .frame(height: 84, alignment: .bottom)
                .clipped()
                .accessibilityHidden(true)
        case .bett, .raum, .poster:
            leinwand
        }
    }

    private var leinwand: some View {
        let zimmer = zimmer
        let ort = ort
        let art = art
        return Canvas { g, size in
            switch art {
            case .bett:
                var b = g
                let s = min(size.width / 300, size.height / 220)
                b.translateBy(x: (size.width - 300 * s) / 2, y: (size.height - 220 * s) / 2)
                b.scaleBy(x: s, y: s)
                SzenenZeichnung.bettHinten(b, zimmer.bett, kissen: [88, 212], bild: nil)
                SzenenZeichnung.bettVorn(b, zimmer.bett, herz: false)
            case .poster:
                var p = g
                let s = min(size.width / 60, size.height / 78)
                p.translateBy(x: size.width / 2, y: size.height / 2)
                p.scaleBy(x: s, y: s)
                SzenenZeichnung.posterZeichnen(p, zimmer.poster)
            case .raum, .tisch:
                let r = SzenenZeichnung.raum(g, size)
                switch ort {
                case .zuhause: SzenenZeichnung.zimmer(r, zimmer, nacht: false, mitBett: true, bett: nil, t: 0.4)
                case .arbeit: SzenenZeichnung.buero(r, zimmer, t: 0.4)
                case .schule: SzenenZeichnung.klassenzimmer(r, zimmer, t: 0.4)
                }
            }
        }
        .accessibilityHidden(true)
    }
}