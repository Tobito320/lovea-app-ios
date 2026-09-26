import SwiftUI
import UIKit

// MARK: Studio overlays

/// The partner's pen: tool symbol in the partner color, brush size as a circle. Only while it draws or hovers.
/// Tapping the symbol pokes it (it wiggles on the partner's screen). Radier-Alarm makes the eraser look guilty.
struct PartnerStiftOverlay: View {
    @ObservedObject var state: CanvasViewState
    let live: ZeichnungLive

    var body: some View {
        let hub = LiveZeichnung.shared
        if let stift = hub.partnerStift, let partner = Raum.shared.ich?.partner {
            let punkt = state.viewport.screenPoint(CGPoint(x: stift.x, y: stift.y))
            let durchmesser = max(6, CGFloat(stift.groesse) * state.viewport.scale)
            let farbe = Color.person(partner)
            let schuldig = hub.radierAlarm && stift.werkzeug == StudioTool.eraser.rawValue
            ZStack {
                Circle()
                    .fill(Color(uiColor: (RGBAColor(hex8: stift.farbe) ?? .studioBlack).uiColor).opacity(0.3))
                    .overlay(Circle().stroke(farbe, lineWidth: 1.5))
                    .frame(width: durchmesser, height: durchmesser)
                    .position(punkt)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                Image(systemName: stift.symbol)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(farbe)
                    .rotationEffect(.degrees(schuldig ? -25 : 0))
                    .overlay(alignment: .topTrailing) {
                        if schuldig { Text("😬").font(.caption).offset(x: 12, y: -10) }
                    }
                    .shadow(color: .black.opacity(0.25), radius: 2)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
                    .onTapGesture { live.anstupsen() }
                    .accessibilityLabel("Stift von \(partner.name)")
                    .accessibilityHint("Anstupsen")
                    .accessibilityAddTraits(.isButton)
                    .position(x: punkt.x + 14, y: punkt.y - 14)
                    .animation(.snappy, value: schuldig)
            }
        }
    }
}

/// The partner's figure at the top edge while they have this drawing open. It follows their pen
/// and says "ups" while they erase.
struct PartnerFigurAmRand: View {
    let zeichnungId: String
    @ObservedObject var state: CanvasViewState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let hub = LiveZeichnung.shared
        if hub.partnerIstDrin(zeichnungId), let partner = Raum.shared.ich?.partner {
            GeometryReader { geo in
                let stift = hub.partnerStift
                let x = stift.map { state.viewport.screenPoint(CGPoint(x: $0.x, y: $0.y)).x } ?? 48
                let radiert = stift?.werkzeug == StudioTool.eraser.rawValue && stift?.aktiv == true
                FigurView(FigurenModell.shared.aussehen(partner), zustand: .zeichnet, groesse: 64, bildrate: 20)
                    .figurGesten(person: partner) { FigurenModell.shared.gesteSenden($0) }
                    .overlay(alignment: .bottom) {
                        if radiert {
                            Text("ups")
                                .font(.caption.weight(.bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.regularMaterial, in: Capsule())
                                .offset(y: 22)
                        }
                    }
                    .accessibilityLabel("\(partner.name) ist in der Zeichnung")
                    .position(x: min(max(x, 40), max(40, geo.size.width - 40)), y: 44)
                    .animation(reduceMotion ? nil : .snappy, value: x)
            }
            .transition(.opacity)
        }
    }
}

/// Extras over the canvas (Spec 10.3): floating emoji, the heart where the pens kissed, the own pen
/// wiggling when poked, the emoji picker (two fingers long) and the finish confetti.
struct GemeinsamOverlay: View {
    @ObservedObject var state: CanvasViewState
    let live: ZeichnungLive
    @State private var wackeln = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let auswahl = ["❤️", "😍", "😂", "😮", "🥺", "🔥", "👏", "✨", "🌸", "😘", "🙈", "🎉"]

    var body: some View {
        let hub = LiveZeichnung.shared
        ZStack {
            ForEach(hub.emojis) { emoji in
                SchwebendesEmojiView(e: emoji.e)
                    .position(state.viewport.screenPoint(CGPoint(x: emoji.x, y: emoji.y)))
            }
            if let kuss = hub.kuss {
                Image(systemName: "heart.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.loveaRose)
                    .shadow(color: Color.loveaRose.opacity(0.6), radius: 8)
                    .position(state.viewport.screenPoint(kuss))
                    .transition(.scale.combined(with: .opacity))
            }
            // The wiggle is a looping phase animation; with Reduce Motion the poke is haptic only.
            if wackeln, !reduceMotion, let punkt = hub.letzterEigenerStift, let ich = Raum.shared.ich {
                Image(systemName: "pencil.tip")
                    .font(.title)
                    .foregroundStyle(Color.person(ich))
                    .phaseAnimator([0.0, 16, -16, 10, -10, 0]) { inhalt, winkel in
                        inhalt.rotationEffect(.degrees(winkel))
                    }
                    .position(state.viewport.screenPoint(punkt))
            }
            if hub.konfetti { SpielKonfetti() }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .animation(.spring, value: hub.kuss)
        .overlay { emojiAuswahl }
        .task(id: hub.stupser) {
            guard hub.stupser > 0 else { return }
            wackeln = true
            try? await Task.sleep(for: .seconds(1.2))
            wackeln = false
        }
    }

    @ViewBuilder
    private var emojiAuswahl: some View {
        if let punkt = state.emojiAuswahl {
            GeometryReader { geo in
                ZStack {
                    Color.black.opacity(0.001)
                        .onTapGesture { state.emojiAuswahl = nil }
                        .accessibilityHidden(true)
                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(44), spacing: 4), count: 6), spacing: 4) {
                        ForEach(Self.auswahl, id: \.self) { e in
                            Button {
                                live.emojiSenden(state.viewport.documentPoint(punkt), e)
                                state.emojiAuswahl = nil
                            } label: {
                                Text(e).font(.title).frame(width: 44, height: 44)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(10)
                    .frame(width: 6 * 48 + 16)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
                    .position(
                        x: min(max(punkt.x, 160), max(160, geo.size.width - 160)),
                        y: min(max(punkt.y - 80, 80), max(80, geo.size.height - 80))
                    )
                }
            }
        }
    }
}

private struct SchwebendesEmojiView: View {
    let e: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var oben = false

    var body: some View {
        Text(e)
            .font(.system(size: 44))
            .offset(y: oben && !reduceMotion ? -90 : 0)
            .opacity(oben ? 0 : 1)
            .onAppear {
                withAnimation(.easeOut(duration: 2)) { oben = true }
            }
    }
}

/// Chat line for `zeichnung.einladung` (Spec 10.1): who invited, and "Öffnen" for the partner.
struct ZeichnungEinladungZeile: View {
    let zeichnungId: String
    let name: String
    let von: Person
    let ich: Person
    @State private var offen = false

    var body: some View {
        VStack(spacing: 6) {
            Label(
                von == ich ? "Du hast zum Mitzeichnen an ‚\(name)‘ eingeladen" : "\(von.name) lädt dich zum Mitzeichnen an ‚\(name)‘ ein",
                systemImage: "paintbrush.pointed"
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            if von != ich {
                Button("Öffnen") { offen = true }
                    .buttonStyle(.bordered)
                    .frame(minHeight: 44)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .fullScreenCover(isPresented: $offen) {
            NavigationStack {
                GeteiltStudioView(zeichnungId: zeichnungId, person: ich)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Schließen") { offen = false }
                        }
                    }
            }
        }
    }
}

/// Viewer: follow the drawer's view.
struct FolgenKnopf: View {
    @ObservedObject var state: CanvasViewState

    var body: some View {
        Toggle(isOn: $state.folgen) {
            Label("Folgen", systemImage: "scope")
        }
        .toggleStyle(.button)
        .accessibilityHint("Deine Ansicht bewegt sich mit")
    }
}

// MARK: Share sheet

/// "Teilen" of a project: level, per-drawing edit right, remove the person.
struct TeilenSheet: View {
    let project: ArtworkProject
    @ObservedObject var library: ArtworkLibrary
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let modell = TeilenModell.shared
        let stufe = modell.stand.stufe(projekt: project.id.uuidString)
        let partner = Raum.shared.ich?.partner.name ?? "Partner"
        let zeichnungen = library.sortedArtworks(.name).filter { $0.projectID == project.id }
        NavigationStack {
            Form {
                Section {
                    Picker("Stufe", selection: Binding(
                        get: { stufe },
                        set: { modell.projektTeilen(project, stufe: $0, library: library) }
                    )) {
                        ForEach(TeilenStufe.allCases) { Text($0.titel).tag($0) }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } header: {
                    Text("Mit \(partner) teilen")
                } footer: {
                    switch stufe {
                    case .aus: Text("Nur du siehst dieses Projekt.")
                    case .ansehen: Text("\(partner) sieht alle Zeichnungen live. Einzelne kannst du zum Bearbeiten freigeben.")
                    case .bearbeiten: Text("\(partner) sieht alle Zeichnungen live und darf sie bearbeiten.")
                    }
                }
                if stufe == .ansehen, !zeichnungen.isEmpty {
                    Section("Bearbeiten erlauben") {
                        ForEach(zeichnungen) { artwork in
                            Toggle(artwork.name, isOn: Binding(
                                get: { modell.stand.rechte[artwork.id.uuidString]?.wert.bearbeiten ?? false },
                                set: { modell.bearbeitenErlauben(artwork.id, $0) }
                            ))
                        }
                    }
                }
                if stufe != .aus {
                    Section {
                        Button("\(partner) entfernen", role: .destructive) {
                            modell.projektTeilen(project, stufe: .aus, library: library)
                        }
                    }
                }
            }
            .navigationTitle(project.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }
}

// MARK: Gallery

/// "Mit mir geteilt": the partner's shared projects and invitations, with their figure as badge.
struct GeteiltBereich: View {
    let person: Person
    let open: (String) -> Void

    var body: some View {
        let stand = TeilenModell.shared.stand
        let partner = person.partner
        let staende = stand.geteilteStaende(von: partner)
        if !staende.isEmpty {
            let projekte = stand.geteilteProjekte(von: partner)
            let einzeln = staende.filter { item in !projekte.contains { $0.projektId == item.projektId } }
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Text("Mit mir geteilt").font(.title3.bold())
                    FigurView(FigurenModell.shared.aussehen(partner), zustand: .ruhig, groesse: 30, animiert: false)
                        .accessibilityHidden(true)
                    Spacer()
                }
                ForEach(projekte, id: \.projektId) { projekt in
                    let inProjekt = staende.filter { $0.projektId == projekt.projektId }
                    if !inProjekt.isEmpty {
                        Label(projekt.name, systemImage: "folder").font(.headline)
                        raster(inProjekt, partner: partner)
                    }
                }
                if !einzeln.isEmpty {
                    Label("Einladungen", systemImage: "envelope").font(.headline)
                    raster(einzeln, partner: partner)
                }
            }
        }
    }

    private func raster(_ items: [ZeichnungStand], partner: Person) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150, maximum: 230), spacing: 14)], spacing: 14) {
            ForEach(items, id: \.zeichnungId) { item in
                Button { open(item.zeichnungId) } label: {
                    GeteiltKarte(stand: item, partner: partner)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct GeteiltKarte: View {
    let stand: ZeichnungStand
    let partner: Person
    @State private var bild: UIImage?

    var body: some View {
        let live = LiveZeichnung.shared.partnerIstDrin(stand.zeichnungId)
        VStack(alignment: .leading, spacing: 8) {
            Color(uiColor: .secondarySystemBackground)
                .aspectRatio(4 / 3, contentMode: .fit)
                .overlay {
                    if let bild {
                        Image(uiImage: bild).resizable().scaledToFill()
                    } else {
                        Image(systemName: "paintbrush.pointed").font(.title).foregroundStyle(.secondary)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(alignment: .bottomTrailing) {
                    FigurView(FigurenModell.shared.aussehen(partner), zustand: live ? .zeichnet : .ruhig, groesse: 30, animiert: live)
                        .padding(4)
                        .accessibilityHidden(true)
                }
            HStack(spacing: 5) {
                Text(stand.name ?? "Zeichnung")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                if live {
                    Text("live")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.loveaRose, in: Capsule())
                        .foregroundStyle(.white)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint(live ? "\(partner.name) zeichnet gerade" : "Von \(partner.name)")
        .task(id: stand.vorschau) {
            guard let id = stand.vorschau, let url = try? await Medien.holen(id) else { return }
            bild = await Task.detached(priority: .utility) { () -> UIImage? in
                guard let full = UIImage(contentsOfFile: url.path) else { return nil }
                let scale = min(1, 480 / max(full.size.width, full.size.height, 1))
                return full.preparingThumbnail(of: CGSize(width: full.size.width * scale, height: full.size.height * scale))
            }.value
        }
    }
}

/// Opens a partner drawing: downloads the latest stand, then the studio (tools locked without the edit right).
struct GeteiltStudioView: View {
    let zeichnungId: String
    let person: Person
    @State private var geladen: (id: UUID, stand: ZeichnungStand?)?
    @State private var fehlgeschlagen = false

    var body: some View {
        if let geladen {
            DrawingStudioView(
                artworkID: geladen.id, library: TeilenModell.shared.bibliothek, person: person,
                fremd: true, stand: geladen.stand
            )
        } else if fehlgeschlagen {
            ContentUnavailableView(
                "Konnte nicht laden", systemImage: "wifi.exclamationmark",
                description: Text("Prüf das Netz und versuch es gleich noch mal.")
            )
        } else {
            ProgressView("Lädt …")
                .task { await laden() }
        }
    }

    private func laden() async {
        let modell = TeilenModell.shared
        if let stand = modell.stand.staende[zeichnungId]?.wert,
           let document = try? await StandPaket.laden(stand, into: modell.bibliothek) {
            geladen = (document.id, stand)
        } else if let id = UUID(uuidString: zeichnungId), modell.bibliothek.document(id) != nil {
            // Offline: the copy from the last visit. The next stand brings it up to date.
            geladen = (id, nil)
        } else {
            fehlgeschlagen = true
        }
    }
}
