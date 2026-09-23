import SwiftUI
import UIKit

// MARK: Studio overlays

/// The partner's pen: tool symbol in the partner color, brush size as a circle. Only while it draws or hovers.
struct PartnerStiftOverlay: View {
    @ObservedObject var state: CanvasViewState

    var body: some View {
        if let stift = LiveZeichnung.shared.partnerStift, let partner = Raum.shared.ich?.partner {
            let punkt = state.viewport.screenPoint(CGPoint(x: stift.x, y: stift.y))
            let durchmesser = max(6, CGFloat(stift.groesse) * state.viewport.scale)
            let farbe = Color.person(partner)
            ZStack {
                Circle()
                    .fill(Color(uiColor: (RGBAColor(hex8: stift.farbe) ?? .studioBlack).uiColor).opacity(0.3))
                    .overlay(Circle().stroke(farbe, lineWidth: 1.5))
                    .frame(width: durchmesser, height: durchmesser)
                    .position(punkt)
                Image(systemName: stift.symbol)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(farbe)
                    .shadow(color: .black.opacity(0.25), radius: 2)
                    .position(x: punkt.x + 14, y: punkt.y - 14)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}

/// The partner's figure at the canvas edge while they have this drawing open.
struct PartnerFigurAmRand: View {
    let zeichnungId: String

    var body: some View {
        if LiveZeichnung.shared.partnerIstDrin(zeichnungId), let partner = Raum.shared.ich?.partner {
            FigurView(FigurenModell.shared.aussehen(partner), zustand: .zeichnet, groesse: 72)
                .figurGesten(person: partner) { FigurenModell.shared.gesteSenden($0) }
                .accessibilityLabel("\(partner.name) ist in der Zeichnung")
                .transition(.move(edge: .leading).combined(with: .opacity))
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

/// Opens a partner drawing to watch: downloads the latest stand, then the studio in viewer mode.
struct GeteiltStudioView: View {
    let zeichnungId: String
    let person: Person
    @State private var geladen: (id: UUID, stand: ZeichnungStand?)?
    @State private var fehlgeschlagen = false

    var body: some View {
        if let geladen {
            DrawingStudioView(
                artworkID: geladen.id, library: TeilenModell.shared.bibliothek, person: person,
                nurAnsehen: true, stand: geladen.stand
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
