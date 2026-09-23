import PhotosUI
import SwiftUI
import UIKit

struct DrawingStudioView: View {
    @StateObject private var session: DrawingSession
    @StateObject private var palette: ColorPaletteStore
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("studio.glass") private var glass = true
    @AppStorage("profile.performanceHUD") private var showsHUD = false
    @State private var showsLayers = true
    @State private var showsLayerSheet = false
    @State private var showsText = false
    @State private var showsExport = false
    @State private var adjustment: Adjustment?
    @State private var viewMirrored = false
    @State private var imageItem: PhotosPickerItem?
    @State private var templateItem: PhotosPickerItem?
    @State private var templateData: Data?

    /// `fremd`: a partner drawing from the shared library, `stand` the stand it was loaded from.
    init(artworkID: UUID, library: ArtworkLibrary, person: Person, templateData: Data? = nil,
         fremd: Bool = false, stand: ZeichnungStand? = nil) {
        _session = StateObject(wrappedValue: {
            let session = DrawingSession(artworkID: artworkID, library: library, fremd: fremd)
            session.live.geladen = stand
            return session
        }())
        _palette = StateObject(wrappedValue: ColorPaletteStore(person: person.rawValue))
        _templateData = State(initialValue: templateData)
    }

    private var compact: Bool { sizeClass == .compact }

    var body: some View {
        ZStack {
            Color(uiColor: .secondarySystemBackground).ignoresSafeArea()
            CanvasRepresentable(session: session).ignoresSafeArea()
            CanvasOverlay(state: session.canvasState, session: session).ignoresSafeArea()
            PartnerStiftOverlay(state: session.canvasState, live: session.live).ignoresSafeArea()
            GemeinsamOverlay(state: session.canvasState, live: session.live).ignoresSafeArea()
            if session.isTransforming {
                TransformOverlay(state: session.canvasState, session: session).ignoresSafeArea(edges: .bottom)
            }
        }
        .overlay(alignment: .top) { topMessages }
        .overlay {
            PartnerFigurAmRand(zeichnungId: session.live.zeichnungId, state: session.canvasState)
                .animation(reduceMotion ? nil : .snappy, value: LiveZeichnung.shared.partnerDrin)
        }
        .overlay(alignment: .topTrailing) {
            if showsHUD { PerformanceHUD(session: session).padding(12) }
        }
        .overlay(alignment: .leading) {
            if !compact, !session.isTransforming, !session.nurAnsehen {
                SizeOpacityRail(session: session, compact: false, glass: glass).padding(.leading, 12)
            }
        }
        .overlay(alignment: .bottom) { bottomControls }
        .overlay { QuickMenuOverlay(state: session.canvasState, session: session, palette: palette) }
        .overlay(alignment: .trailing) {
            if !compact, showsLayers {
                ArtworkLayersView(session: session)
                    .disabled(session.nurAnsehen)
                    .frame(width: 320)
                    .background(.background)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.12), radius: 12)
                    .padding(12)
                    .transition(.move(edge: .trailing))
            }
        }
        .navigationTitle(session.document.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar { studioToolbar }
        .sheet(isPresented: $showsLayerSheet) { LayersSheet(session: session).disabled(session.nurAnsehen) }
        .sheet(isPresented: $showsText) { TextSheet(session: session) }
        .sheet(isPresented: $showsExport) {
            ArtworkExportSheet(artwork: session.document, library: session.library)
        }
        .sheet(isPresented: compact ? $session.showsColorPanel : .constant(false)) {
            colorPanel.presentationDetents([.medium, .large])
        }
        .alert("Speicher voll", isPresented: Binding(get: { session.memoryFull }, set: { if !$0 { session.dismissMemoryNotice() } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Speicher voll – Ebenen zusammenführen oder kleinere Leinwand wählen.")
        }
        .onAppear {
            session.live.betreten()
            if session.nurAnsehen { session.show("Nur ansehen – Werkzeuge sind gesperrt") }
            session.onColorUsed = { [weak palette] in palette?.use($0) }
            if let templateData {
                self.templateData = nil
                Task { await session.importPhoto(templateData, asTemplate: true) }
            }
        }
        .onChange(of: imageItem) { _, item in load(item, asTemplate: false) }
        .onChange(of: templateItem) { _, item in load(item, asTemplate: true) }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { session.saveNow() }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)) { _ in
            session.engine?.handleMemoryWarning()
        }
        .onDisappear {
            session.saveNow()
            session.live.verlassen()
        }
        .onChange(of: Raum.shared.verbunden) { _, an in if an { session.live.ankuendigen() } }
        .onChange(of: Raum.shared.partnerDa) { _, da in if da { session.live.ankuendigen() } }
    }

    // MARK: Top bar

    @ToolbarContentBuilder
    private var studioToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            if LiveZeichnung.shared.partnerIstDrin(session.live.zeichnungId) {
                Button { LiveZeichnung.shared.fertigDruecken() } label: {
                    Image(systemName: LiveZeichnung.shared.ichFertig ? "checkmark.circle.fill" : "checkmark.circle")
                }
                .accessibilityLabel("Gemeinsam fertig")
                .accessibilityHint("Wenn ihr beide fertig drückt, landet das Bild im Chat")
            }
            if session.nurAnsehen {
                FolgenKnopf(state: session.canvasState)
            } else {
                Button { session.undo() } label: { Image(systemName: "arrow.uturn.backward") }
                    .accessibilityLabel("Rückgängig")
                    .disabled(!session.canUndo)
                Button { session.redo() } label: { Image(systemName: "arrow.uturn.forward") }
                    .accessibilityLabel("Wiederholen")
                    .disabled(!session.canRedo)
            }
            Button {
                if compact { showsLayerSheet = true } else { withAnimation(reduceMotion ? nil : .snappy) { showsLayers.toggle() } }
            } label: { Image(systemName: "square.3.layers.3d") }
                .accessibilityLabel("Ebenen")
            moreMenu
        }
    }

    private var moreMenu: some View {
        Menu {
            if session.nurAnsehen {
                viewMenu
            } else {
                editMenu
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .accessibilityLabel("Mehr")
        .onChange(of: viewMirrored) { _, value in session.canvasState.setMirrored(value) }
    }

    @ViewBuilder
    private var viewMenu: some View {
        Toggle(isOn: $viewMirrored) { Label("Ansicht spiegeln", systemImage: "arrow.left.and.right.righttriangle.left.righttriangle.right") }
        Button { session.canvasState.resetView() } label: { Label("Ansicht zurücksetzen", systemImage: "arrow.up.left.and.down.right.magnifyingglass") }
    }

    @ViewBuilder
    private var editMenu: some View {
        Menu {
            ForEach(Adjustment.allCases) { item in
                Button(item.title) {
                    adjustment = item
                    session.previewAdjustment(item, amount: item.range.map { ($0.lowerBound + $0.upperBound) / 2 } ?? 0)
                }
            }
        } label: { Label("Anpassen", systemImage: "slider.horizontal.3") }
        Menu {
            ForEach(ShapeKind.allCases) { kind in
                Button {
                    session.shapeKind = kind
                    session.tool = .shape
                } label: { Label(kind.title, systemImage: kind.symbol) }
            }
            Toggle("Gefüllt", isOn: $session.shapeFilled)
        } label: { Label("Formen", systemImage: "square.on.circle") }
        Toggle(isOn: $session.lassoRectangle) { Label("Rechteck-Auswahl", systemImage: "rectangle.dashed") }
        Toggle(isOn: $session.symmetry) { Label("Spiegelachse", systemImage: "square.split.2x1") }
        Divider()
        viewMenu
        Toggle(isOn: $session.drawsWithFinger) { Label("Mit Finger zeichnen", systemImage: "hand.draw") }
        Divider()
        Button { showsExport = true } label: { Label("Exportieren", systemImage: "square.and.arrow.up") }
        Button { session.alsBildSenden() } label: { Label("Als Bild senden", systemImage: "paperplane") }
        if !session.fremd {
            Button { session.einladen() } label: { Label("Zum Mitzeichnen einladen", systemImage: "person.2") }
        }
    }

    // MARK: Floating controls

    @ViewBuilder
    private var bottomControls: some View {
        if session.nurAnsehen {
            EmptyView()
        } else if let adjustment {
            AdjustPanel(session: session, adjustment: adjustment, glass: glass) { self.adjustment = nil }
                .padding(.bottom, 12)
        } else if !session.isTransforming {
            FloatingBarGroup {
                VStack(spacing: 10) {
                    if session.hasSelection { selectionBar }
                    if session.tool == .fill { fillOptions }
                    if compact, session.tool == .brush || session.tool == .eraser {
                        SizeOpacityRail(session: session, compact: true, glass: glass)
                    }
                    ToolRail(
                        session: session, compact: compact, glass: glass,
                        templateItem: $templateItem, imageItem: $imageItem,
                        onText: { showsText = true },
                        onColor: { session.showsColorPanel = true },
                        onLayers: { showsLayerSheet = true }
                    )
                    .popover(isPresented: compact ? .constant(false) : $session.showsColorPanel, arrowEdge: .bottom) {
                        colorPanel.frame(width: 340, height: 560)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
    }

    private var colorPanel: some View {
        ColorPanel(
            color: Binding(get: { session.color }, set: { session.setColor($0) }),
            palette: palette,
            onEyedropper: {
                session.showsColorPanel = false
                session.tool = .eyedropper
            }
        )
    }

    private var selectionBar: some View {
        HStack(spacing: 2) {
            ToolButton(title: "Auswahl aufheben", symbol: "xmark.circle") { session.clearSelection() }
            ToolButton(title: "Auswahl umkehren", symbol: "circle.lefthalf.filled") { session.invertSelection() }
            ToolButton(title: "Inhalt löschen", symbol: "trash") { session.deleteSelection() }
            ToolButton(title: "Auf neue Ebene kopieren", symbol: "plus.square.on.square") { session.copySelection(cut: false) }
            ToolButton(title: "Auf neue Ebene ausschneiden", symbol: "scissors") { session.copySelection(cut: true) }
            ToolButton(title: "Transformieren", symbol: StudioTool.transform.symbol) {
                session.tool = .transform
                session.beginTransform()
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .floatingBar(glass: glass)
    }

    private var fillOptions: some View {
        HStack(spacing: 12) {
            Picker("Bezug", selection: $session.fillReference) {
                ForEach(FillReference.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 240)
            Text("Toleranz")
                .font(.caption)
            Slider(value: $session.fillTolerance, in: 0...0.5)
                .frame(maxWidth: 180)
                .accessibilityLabel("Toleranz")
            Text("\(Int(session.fillTolerance * 100)) %")
                .font(.caption.monospacedDigit())
                .frame(minWidth: 40)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 44)
        .floatingBar(glass: glass)
    }

    @ViewBuilder
    private var topMessages: some View {
        VStack(spacing: 8) {
            if let notice = session.notice {
                HStack(spacing: 12) {
                    Text(notice).font(.subheadline.weight(.medium))
                    if session.noticeOffersRasterize {
                        Button("Rastern") { session.rasterize(session.activeLayerID) }
                            .buttonStyle(.bordered)
                    }
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 44)
                .background(.regularMaterial, in: Capsule())
            }
            if session.isBusy {
                ProgressView().padding(10).background(.regularMaterial, in: Circle())
            }
            if let fertig = fertigHinweis {
                Text(fertig)
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 16)
                    .frame(minHeight: 44)
                    .background(.regularMaterial, in: Capsule())
            }
        }
        .padding(.top, 8)
        .animation(reduceMotion ? nil : .snappy, value: session.notice)
    }

    private var fertigHinweis: String? {
        let hub = LiveZeichnung.shared
        guard hub.partnerIstDrin(session.live.zeichnungId), let partner = Raum.shared.ich?.partner.name else { return nil }
        if hub.ichFertig { return "Wartet auf \(partner) …" }
        if hub.partnerFertig { return "\(partner) ist fertig – du auch?" }
        return nil
    }

    // MARK: Photos

    private func load(_ item: PhotosPickerItem?, asTemplate: Bool) {
        guard let item else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self) {
                await session.importPhoto(data, asTemplate: asTemplate)
            }
            if asTemplate { templateItem = nil } else { imageItem = nil }
        }
    }

}

/// Live preview with one slider. "Fertig" writes into the layer, "Abbrechen" throws it away.
private struct AdjustPanel: View {
    @ObservedObject var session: DrawingSession
    let adjustment: Adjustment
    let glass: Bool
    let onClose: () -> Void
    @State private var amount = 0.0

    var body: some View {
        VStack(spacing: 8) {
            Text(adjustment.title).font(.subheadline.weight(.semibold))
            if let range = adjustment.range {
                Slider(value: $amount, in: range)
                    .accessibilityLabel(adjustment.title)
                    .onChange(of: amount) { _, value in session.previewAdjustment(adjustment, amount: value) }
            }
            HStack {
                Button("Abbrechen", role: .cancel) {
                    session.cancelAdjustment()
                    onClose()
                }
                .frame(minHeight: 44)
                Spacer()
                Button("Fertig") {
                    session.commitAdjustment()
                    onClose()
                }
                .buttonStyle(.borderedProminent)
                .frame(minHeight: 44)
            }
        }
        .padding(16)
        .frame(maxWidth: 420)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
        .padding(.horizontal, 12)
        .onAppear {
            amount = adjustment.range.map { ($0.lowerBound + $0.upperBound) / 2 } ?? 0
            session.previewAdjustment(adjustment, amount: amount)
        }
    }
}

/// Text entry: 4 fonts and a size. The text then appears as transform content.
private struct TextSheet: View {
    @ObservedObject var session: DrawingSession
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var font: TextFont = .system
    @State private var size = 96.0

    var body: some View {
        NavigationStack {
            Form {
                TextField("Text", text: $text, axis: .vertical)
                    .lineLimit(1...5)
                Picker("Schrift", selection: $font) {
                    ForEach(TextFont.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                LabeledContent("Größe") {
                    Slider(value: $size, in: 16...400, step: 4)
                }
                Text("\(Int(size)) px").font(.caption).foregroundStyle(.secondary)
            }
            .navigationTitle("Text")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Einfügen") {
                        session.tool = .transform
                        session.insertText(text, font: font, size: size)
                        dismiss()
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview("Studio – iPad") {
    NavigationStack {
        DrawingStudioView(
            artworkID: UUID(),
            library: ArtworkLibrary(rootURL: FileManager.default.temporaryDirectory.appendingPathComponent("preview")),
            person: .annika
        )
    }
    .environment(\.horizontalSizeClass, .regular)
}

#Preview("Studio – iPhone") {
    NavigationStack {
        DrawingStudioView(
            artworkID: UUID(),
            library: ArtworkLibrary(rootURL: FileManager.default.temporaryDirectory.appendingPathComponent("preview")),
            person: .annika
        )
    }
    .environment(\.horizontalSizeClass, .compact)
}

/// Opened by squeezing the Apple Pencil: last 3 brushes and 8 colors at the pencil tip.
private struct QuickMenuOverlay: View {
    @ObservedObject var state: CanvasViewState
    @ObservedObject var session: DrawingSession
    @ObservedObject var palette: ColorPaletteStore

    var body: some View {
        if let point = state.quickMenu {
            ZStack {
                Color.black.opacity(0.001)
                    .onTapGesture { state.quickMenu = nil }
                VStack(spacing: 8) {
                    HStack(spacing: 4) {
                        ForEach(session.recentBrushes) { preset in
                            Button(preset.title) {
                                session.brush = preset
                                session.tool = .brush
                                state.quickMenu = nil
                            }
                            .buttonStyle(.bordered)
                            .frame(minHeight: 44)
                        }
                    }
                    HStack(spacing: 4) {
                        ForEach(Array(palette.recent.prefix(8).enumerated()), id: \.offset) { _, color in
                            ColorSwatchButton(color: color) {
                                session.setColor(color)
                                state.quickMenu = nil
                            }
                        }
                    }
                }
                .padding(12)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
                .position(point)
            }
        }
    }
}
