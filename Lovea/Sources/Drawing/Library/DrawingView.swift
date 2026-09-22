import SwiftUI
import UIKit

struct DrawingView: View {
    let person: LoveaPerson
    @StateObject private var library: ArtworkLibrary
    @StateObject private var sharing: LoveaSharingService
    @State private var sort: ArtworkSort = .newest
    @State private var showsNewArtwork = false
    @State private var showsNewProject = false
    @State private var showsSharingConnection = false
    @State private var showsSharingManager = false
    @State private var newProjectName = ""

    init(person: LoveaPerson) {
        self.person = person
        _library = StateObject(wrappedValue: ArtworkLibrary())
        _sharing = StateObject(wrappedValue: LoveaSharingService(person: person))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 22) {
                    if let latest = library.artworks.max(by: { $0.updatedAt < $1.updatedAt }) {
                        sectionTitle("Zuletzt bearbeitet")
                        NavigationLink {
                            DrawingStudioView(artworkID: latest.id, library: library, sharing: sharing)
                        } label: {
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
                                NavigationLink {
                                    ProjectGalleryView(
                                        projectID: project.id,
                                        library: library,
                                        sharing: sharing,
                                        sort: $sort
                                    )
                                } label: {
                                    ProjectCard(project: project, library: library)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    sectionTitle("Ohne Projekt")
                    let ungrouped = sorted(library.artworks.filter { $0.projectID == nil })
                    if ungrouped.isEmpty {
                        ContentUnavailableView(
                            "Noch keine Zeichnung",
                            systemImage: "paintbrush",
                            description: Text("Erstelle eine Zeichnung oder importiere ein Foto als Schablone.")
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                    } else {
                        LazyVGrid(columns: galleryColumns, spacing: 14) {
                            ForEach(ungrouped) { artwork in
                                ArtworkCard(artwork: artwork, library: library, sharing: sharing)
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

    private func sorted(_ values: [ArtworkDocument]) -> [ArtworkDocument] {
        switch sort {
        case .newest: values.sorted { $0.updatedAt > $1.updatedAt }
        case .name: values.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .oldest: values.sorted { $0.createdAt < $1.createdAt }
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
    @ObservedObject var sharing: LoveaSharingService
    @Binding var sort: ArtworkSort
    @State private var showsNewArtwork = false
    @State private var renameText = ""
    @State private var showsRename = false
    @State private var showsDelete = false

    private var project: ArtworkProject? {
        library.projects.first(where: { $0.id == projectID })
    }

    private var artworks: [ArtworkDocument] {
        let values = library.artworks.filter { $0.projectID == projectID }
        switch sort {
        case .newest: return values.sorted { $0.updatedAt > $1.updatedAt }
        case .name: return values.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .oldest: return values.sorted { $0.createdAt < $1.createdAt }
        }
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150, maximum: 230), spacing: 14)], spacing: 14) {
                ForEach(artworks) { artwork in
                    ArtworkCard(artwork: artwork, library: library, sharing: sharing)
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
            Button("Projekt löschen, Zeichnungen behalten", role: .destructive) {
                library.deleteProject(projectID, deleteArtworks: false)
            }
            Button("Projekt und Zeichnungen löschen", role: .destructive) {
                library.deleteProject(projectID, deleteArtworks: true)
            }
            Button("Abbrechen", role: .cancel) {}
        }
    }
}

private struct ArtworkCard: View {
    let artwork: ArtworkDocument
    @ObservedObject var library: ArtworkLibrary
    @ObservedObject var sharing: LoveaSharingService
    @State private var renameText = ""
    @State private var showsRename = false
    @State private var showsDelete = false

    var body: some View {
        NavigationLink {
            DrawingStudioView(artworkID: artwork.id, library: library, sharing: sharing)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                preview
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
            Button("Umbenennen") {
                renameText = artwork.name
                showsRename = true
            }
            Button("Duplizieren") { _ = library.duplicateArtwork(artwork.id) }
            Menu("In Projekt verschieben") {
                Button("Ohne Projekt") { library.moveArtwork(artwork.id, to: nil) }
                ForEach(library.projects) { project in
                    Button(project.name) { library.moveArtwork(artwork.id, to: project.id) }
                }
            }
            Button("Löschen", role: .destructive) { showsDelete = true }
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

    @ViewBuilder
    private var preview: some View {
        if let image = library.previewImage(for: artwork.id) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                backgroundColor(artwork.background)
                Image(systemName: "paintbrush.pointed")
                    .font(.title)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct LatestArtworkCard: View {
    let artwork: ArtworkDocument
    @ObservedObject var library: ArtworkLibrary

    var body: some View {
        HStack(spacing: 14) {
            Group {
                if let image = library.previewImage(for: artwork.id) {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    backgroundColor(artwork.background)
                }
            }
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
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(.thinMaterial)
                let items = Array(library.artworks.filter { $0.projectID == project.id }.prefix(4))
                if items.isEmpty {
                    Image(systemName: "folder")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                } else {
                    HStack(spacing: 2) {
                        ForEach(items) { artwork in
                            if let image = library.previewImage(for: artwork.id) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .clipped()
                            } else {
                                backgroundColor(artwork.background)
                            }
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
            Text("\(library.artworks.filter { $0.projectID == project.id }.count) Zeichnungen")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

private struct NewArtworkSheet: View {
    @ObservedObject var library: ArtworkLibrary
    let preselectedProjectID: UUID?
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var format: ArtworkFormat = .square
    @State private var background: BackgroundChoice = .white
    @State private var projectID: UUID?
    @State private var customWidth = 2048.0
    @State private var customHeight = 2048.0

    init(library: ArtworkLibrary, preselectedProjectID: UUID?) {
        self.library = library
        self.preselectedProjectID = preselectedProjectID
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
                    TextField("Breite", value: $customWidth, format: .number)
                        .keyboardType(.numberPad)
                    TextField("Höhe", value: $customHeight, format: .number)
                        .keyboardType(.numberPad)
                }

                Picker("Hintergrund", selection: $background) {
                    ForEach(BackgroundChoice.allCases) { choice in
                        Text(choice.title).tag(choice)
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
                            background: background.canvasBackground
                        )
                        dismiss()
                    }
                }
            }
        }
    }
}

private enum BackgroundChoice: String, CaseIterable, Identifiable {
    case white
    case dark
    case transparent

    var id: String { rawValue }
    var title: String {
        switch self {
        case .white: "Weiß"
        case .dark: "Dunkel"
        case .transparent: "Transparent"
        }
    }
    var canvasBackground: CanvasBackground {
        switch self {
        case .white: .white
        case .dark: .dark
        case .transparent: .transparent
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
        ZStack {
            Color.white
            Image(systemName: "square.grid.3x3.fill")
                .resizable()
                .scaledToFill()
                .foregroundStyle(.gray.opacity(0.15))
        }
    case .color(let color):
        Color(uiColor: color.uiColor)
    }
}
