import PhotosUI
import SwiftUI
import UIKit

private enum GalleryRoute: Hashable {
    case artwork(UUID, templateData: Data? = nil)
    case project(UUID)
}

struct DrawingView: View {
    let person: LoveaPerson
    @StateObject private var library: ArtworkLibrary
    @StateObject private var sharing: LoveaSharingService
    @State private var path: [GalleryRoute] = []
    @State private var sort: ArtworkSort = .newest
    @State private var showsNewArtwork = false
    @State private var showsNewProject = false
    @State private var showsSharingConnection = false
    @State private var showsSharingManager = false
    @State private var newProjectName = ""
    @State private var templateItem: PhotosPickerItem?

    init(person: LoveaPerson) {
        self.person = person
        _library = StateObject(wrappedValue: ArtworkLibrary())
        _sharing = StateObject(wrappedValue: LoveaSharingService(person: person))
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 22) {
                    if let latest = library.sortedArtworks(.newest).first {
                        sectionTitle("Zuletzt bearbeitet")
                        NavigationLink(value: GalleryRoute.artwork(latest.id)) {
                            LatestArtworkCard(artwork: latest, library: library)
                        }
                        .buttonStyle(.plain)
                    }

                    SharingInboxSection(sharing: sharing, partner: person.partner)

                    HStack {
                        Button {
                            showsNewArtwork = true
                        } label: {
                            Label("Neue Zeichnung", systemImage: "plus")
                        }
                        .buttonStyle(.borderedProminent)

                        Button {
                            showsNewProject = true
                        } label: {
                            Label("Projekt", systemImage: "folder.badge.plus")
                        }
                        .buttonStyle(.bordered)

                        Spacer()

                        Picker("Sortierung", selection: $sort) {
                            ForEach(ArtworkSort.allCases) { option in
                                Text(option.title).tag(option)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    if !library.projects.isEmpty {
                        sectionTitle("Projekte")
                        LazyVGrid(columns: galleryColumns, spacing: 14) {
                            ForEach(library.projects) { project in
                                NavigationLink(value: GalleryRoute.project(project.id)) {
                                    ProjectCard(project: project, library: library)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    if library.artworks.isEmpty {
                        emptyState
                    } else {
                        sectionTitle("Ohne Projekt")
                        let ungrouped = library.sortedArtworks(sort).filter { $0.projectID == nil }
                        if ungrouped.isEmpty {
                            Text("Alle Zeichnungen liegen in Projekten.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            LazyVGrid(columns: galleryColumns, spacing: 14) {
                                ForEach(ungrouped) { artwork in
                                    ArtworkCard(artwork: artwork, library: library) {
                                        path.append(.artwork(artwork.id))
                                    }
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .refreshable {
                await sharing.refresh()
            }
            .navigationTitle("Meine Galerie")
            .navigationDestination(for: GalleryRoute.self) { route in
                switch route {
                case .artwork(let id, let templateData):
                    DrawingStudioView(artworkID: id, library: library, sharing: sharing, templateData: templateData)
                case .project(let id):
                    ProjectGalleryView(projectID: id, library: library, sort: $sort) { artworkID in
                        path.append(.artwork(artworkID))
                    }
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        openSharing()
                    } label: {
                        Image(systemName: sharingSymbol)
                    }
                    .accessibilityLabel("Mit \(person.partner.rawValue) teilen")

                    Text(person.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .sheet(isPresented: $showsNewArtwork) {
                NewArtworkSheet(library: library, preselectedProjectID: nil)
            }
            .sheet(isPresented: $showsSharingConnection) {
                SharingConnectionView(sharing: sharing)
            }
            .sheet(isPresented: $showsSharingManager) {
                SharingManagerView(library: library, sharing: sharing, partner: person.partner)
            }
            .alert("Neues Projekt", isPresented: $showsNewProject) {
                TextField("Name", text: $newProjectName)
                Button("Abbrechen", role: .cancel) { newProjectName = "" }
                Button("Erstellen") {
                    library.createProject(name: newProjectName)
                    newProjectName = ""
                }
            } message: {
                Text("Ein Projekt sammelt mehrere Zeichnungen. Du kannst es später mit \(person.partner.rawValue) teilen.")
            }
            .onChange(of: templateItem) { _, item in
                guard let item else { return }
                templateItem = nil
                Task { @MainActor in
                    guard let data = try? await item.loadTransferable(type: Data.self) else { return }
                    let artwork = library.createArtwork(name: "Schablone", projectID: nil, format: .square)
                    path.append(.artwork(artwork.id, templateData: data))
                }
            }
            .task {
                await sharing.checkSession()
                if sharing.state == .connected {
                    sharing.startAutoRefresh()
                }
            }
            .onChange(of: sharing.state) { _, state in
                if state == .connected {
                    sharing.startAutoRefresh()
                }
            }
            .onDisappear {
                sharing.stopAutoRefresh()
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Noch keine Zeichnung", systemImage: "paintbrush")
        } description: {
            Text("Fang mit einer leeren Seite an oder zeichne ein Foto nach.")
        } actions: {
            Button("Neue Zeichnung") { showsNewArtwork = true }
                .buttonStyle(.borderedProminent)
            PhotosPicker("Foto als Schablone", selection: $templateItem, matching: .images)
                .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private var galleryColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 150, maximum: 230), spacing: 14)]
    }

    private var sharingSymbol: String {
        switch sharing.state {
        case .connected: "person.2.fill"
        case .checking: "arrow.triangle.2.circlepath"
        case .disconnected, .failed: "person.2"
        }
    }

    private func openSharing() {
        if sharing.state == .connected {
            showsSharingManager = true
        } else {
            showsSharingConnection = true
        }
    }

    @ViewBuilder
    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.title3.bold())
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ProjectGalleryView: View {
    let projectID: UUID
    @ObservedObject var library: ArtworkLibrary
    @Binding var sort: ArtworkSort
    let open: (UUID) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var showsNewArtwork = false
    @State private var renameText = ""
    @State private var showsRename = false
    @State private var showsDelete = false

    private var project: ArtworkProject? {
        library.projects.first(where: { $0.id == projectID })
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150, maximum: 230), spacing: 14)], spacing: 14) {
                ForEach(library.sortedArtworks(sort).filter { $0.projectID == projectID }) { artwork in
                    ArtworkCard(artwork: artwork, library: library) { open(artwork.id) }
                }
            }
            .padding()
        }
        .navigationTitle(project?.name ?? "Projekt")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    showsNewArtwork = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Neue Zeichnung")
                Menu {
                    Button("Umbenennen") {
                        renameText = project?.name ?? ""
                        showsRename = true
                    }
                    Button("Projekt löschen", role: .destructive) {
                        showsDelete = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("Projekt")
            }
        }
        .sheet(isPresented: $showsNewArtwork) {
            NewArtworkSheet(library: library, preselectedProjectID: projectID)
        }
        .alert("Projekt umbenennen", isPresented: $showsRename) {
            TextField("Name", text: $renameText)
            Button("Abbrechen", role: .cancel) {}
            Button("Umbenennen") { library.renameProject(projectID, to: renameText) }
        }
        .confirmationDialog("Projekt löschen?", isPresented: $showsDelete, titleVisibility: .visible) {
            Button("Zeichnungen behalten", role: .destructive) {
                library.deleteProject(projectID, deleteArtworks: false)
                dismiss()
            }
            Button("Zeichnungen mit löschen", role: .destructive) {
                library.deleteProject(projectID, deleteArtworks: true)
                dismiss()
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Was passiert mit den Zeichnungen in diesem Projekt?")
        }
    }
}

private struct ArtworkThumbnail: View {
    let artwork: ArtworkDocument
    @ObservedObject var library: ArtworkLibrary
    @State private var image: UIImage?

    var body: some View {
        backgroundColor(artwork.background)
            .overlay {
                if let image {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    Image(systemName: "paintbrush.pointed")
                        .font(.title)
                        .foregroundStyle(.secondary)
                }
            }
            .clipped()
            .task(id: "\(artwork.id)-\(library.previewVersion)") {
                let url = library.previewURL(for: artwork.id)
                image = await Task.detached(priority: .utility) { () -> UIImage? in
                    guard let full = UIImage(contentsOfFile: url.path) else { return nil }
                    let scale = min(1, 480 / max(full.size.width, full.size.height, 1))
                    return full.preparingThumbnail(of: CGSize(
                        width: full.size.width * scale,
                        height: full.size.height * scale
                    ))
                }.value
            }
    }
}

private struct ArtworkCard: View {
    let artwork: ArtworkDocument
    @ObservedObject var library: ArtworkLibrary
    let open: () -> Void
    @State private var renameText = ""
    @State private var showsRename = false
    @State private var showsDelete = false
    @State private var showsExport = false

    var body: some View {
        Button(action: open) {
            VStack(alignment: .leading, spacing: 8) {
                ArtworkThumbnail(artwork: artwork, library: library)
                    .aspectRatio(CGFloat(artwork.canvasWidth / artwork.canvasHeight), contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                Text(artwork.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                HStack(spacing: 5) {
                    Text(artwork.updatedAt, format: .dateTime.day().month().hour().minute())
                    if artwork.liveReadOnlyShare {
                        Image(systemName: "eye.fill")
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Öffnen", systemImage: "arrow.up.forward.app", action: open)
            Button("Umbenennen", systemImage: "pencil") {
                renameText = artwork.name
                showsRename = true
            }
            Button("Duplizieren", systemImage: "plus.square.on.square") {
                _ = library.duplicateArtwork(artwork.id)
            }
            Menu("In Projekt verschieben", systemImage: "folder") {
                Button("Ohne Projekt") { library.moveArtwork(artwork.id, to: nil) }
                ForEach(library.projects) { project in
                    Button(project.name) { library.moveArtwork(artwork.id, to: project.id) }
                }
            }
            Button("Exportieren", systemImage: "square.and.arrow.up") { showsExport = true }
            Divider()
            Button("Löschen", systemImage: "trash", role: .destructive) { showsDelete = true }
        }
        .sheet(isPresented: $showsExport) {
            ArtworkExportSheet(artwork: artwork, library: library)
        }
        .alert("Zeichnung umbenennen", isPresented: $showsRename) {
            TextField("Name", text: $renameText)
            Button("Abbrechen", role: .cancel) {}
            Button("Umbenennen") { library.renameArtwork(artwork.id, to: renameText) }
        }
        .confirmationDialog("Zeichnung löschen?", isPresented: $showsDelete, titleVisibility: .visible) {
            Button("Löschen", role: .destructive) { library.deleteArtwork(artwork.id) }
            Button("Abbrechen", role: .cancel) {}
        }
    }
}

private struct LatestArtworkCard: View {
    let artwork: ArtworkDocument
    @ObservedObject var library: ArtworkLibrary

    var body: some View {
        HStack(spacing: 14) {
            ArtworkThumbnail(artwork: artwork, library: library)
                .frame(width: 92, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text(artwork.name).font(.headline)
                Text("Weiterzeichnen")
                    .font(.subheadline)
                    .foregroundStyle(.tint)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
    }
}

private struct ProjectCard: View {
    let project: ArtworkProject
    @ObservedObject var library: ArtworkLibrary

    var body: some View {
        let items = library.sortedArtworks(.newest).filter { $0.projectID == project.id }
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(.thinMaterial)
                if items.isEmpty {
                    Image(systemName: "folder")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                } else {
                    HStack(spacing: 2) {
                        ForEach(items.prefix(4)) { artwork in
                            ArtworkThumbnail(artwork: artwork, library: library)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
            .frame(height: 112)
            HStack(spacing: 5) {
                Text(project.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                if project.sharedReadOnly {
                    Image(systemName: "person.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Text(items.count == 1 ? "1 Zeichnung" : "\(items.count) Zeichnungen")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

private struct NewArtworkSheet: View {
    @ObservedObject var library: ArtworkLibrary
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var format: ArtworkFormat = .square
    @State private var background: BackgroundChoice = .white
    @State private var color = backgroundSwatches[0].color
    @State private var projectID: UUID?
    @State private var customWidth = 2048.0
    @State private var customHeight = 2048.0

    init(library: ArtworkLibrary, preselectedProjectID: UUID?) {
        self.library = library
        _projectID = State(initialValue: preselectedProjectID)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)

                Picker("Format", selection: $format) {
                    ForEach(ArtworkFormat.allCases) { format in
                        Text(format.title).tag(format)
                    }
                }

                if format == .custom {
                    Section {
                        TextField("Breite", value: $customWidth, format: .number)
                            .keyboardType(.numberPad)
                        TextField("Höhe", value: $customHeight, format: .number)
                            .keyboardType(.numberPad)
                    } footer: {
                        Text("64 bis 4096 Pixel pro Seite.")
                    }
                }

                Picker("Hintergrund", selection: $background) {
                    ForEach(BackgroundChoice.allCases) { choice in
                        Text(choice.title).tag(choice)
                    }
                }

                if background == .color {
                    HStack {
                        ForEach(0..<backgroundSwatches.count, id: \.self) { index in
                            let swatch = backgroundSwatches[index]
                            Button {
                                color = swatch.color
                            } label: {
                                Circle()
                                    .fill(Color(uiColor: swatch.color.uiColor))
                                    .frame(width: 30, height: 30)
                                    .overlay {
                                        Circle().stroke(Color.primary.opacity(color == swatch.color ? 1 : 0.15), lineWidth: 2)
                                    }
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel(swatch.name)
                            .accessibilityAddTraits(color == swatch.color ? .isSelected : [])
                            .frame(maxWidth: .infinity)
                        }
                    }
                }

                Picker("Projekt", selection: $projectID) {
                    Text("Ohne Projekt").tag(UUID?.none)
                    ForEach(library.projects) { project in
                        Text(project.name).tag(Optional(project.id))
                    }
                }
            }
            .navigationTitle("Neue Zeichnung")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Erstellen") {
                        _ = library.createArtwork(
                            name: name,
                            projectID: projectID,
                            format: format,
                            customWidth: format == .custom ? customWidth : nil,
                            customHeight: format == .custom ? customHeight : nil,
                            background: canvasBackground
                        )
                        dismiss()
                    }
                }
            }
        }
    }

    private var canvasBackground: CanvasBackground {
        switch background {
        case .white: .white
        case .dark: .dark
        case .transparent: .transparent
        case .color: .color(color)
        }
    }
}

private let backgroundSwatches: [(name: String, color: RGBAColor)] = [
    ("Creme", RGBAColor(red: 1, green: 0.96, blue: 0.88)),
    ("Rosa", RGBAColor(red: 1, green: 0.84, blue: 0.88)),
    ("Pfirsich", RGBAColor(red: 1, green: 0.8, blue: 0.65)),
    ("Gelb", RGBAColor(red: 1, green: 0.93, blue: 0.55)),
    ("Mint", RGBAColor(red: 0.75, green: 0.93, blue: 0.82)),
    ("Himmelblau", RGBAColor(red: 0.72, green: 0.86, blue: 1)),
    ("Lavendel", RGBAColor(red: 0.84, green: 0.8, blue: 1)),
    ("Grau", RGBAColor(red: 0.55, green: 0.56, blue: 0.6)),
]

private enum BackgroundChoice: String, CaseIterable, Identifiable {
    case white
    case dark
    case transparent
    case color

    var id: String { rawValue }
    var title: String {
        switch self {
        case .white: "Weiß"
        case .dark: "Dunkel"
        case .transparent: "Transparent"
        case .color: "Farbe"
        }
    }
}

@ViewBuilder
private func backgroundColor(_ background: CanvasBackground) -> some View {
    switch background {
    case .white:
        Color.white
    case .dark:
        Color(white: 0.07)
    case .transparent:
        Color.white
            .overlay {
                Image(systemName: "square.grid.3x3.fill")
                    .resizable()
                    .scaledToFill()
                    .foregroundStyle(.gray.opacity(0.15))
            }
            .clipped()
    case .color(let color):
        Color(uiColor: color.uiColor)
    }
}
