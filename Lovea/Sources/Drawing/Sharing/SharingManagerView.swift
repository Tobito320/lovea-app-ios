import SwiftUI

struct SharingManagerView: View {
    @ObservedObject var library: ArtworkLibrary
    @ObservedObject var sharing: LoveaSharingService
    let partner: LoveaPerson
    @Environment(\.dismiss) private var dismiss
    @State private var busyID: UUID?
    @State private var message: String?

    var body: some View {
        NavigationStack {
            List {
                Section("Projekte") {
                    if library.projects.isEmpty {
                        Text("Noch keine Projekte")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(library.projects) { project in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(project.name)
                                Text(project.sharedReadOnly ? "\(partner.rawValue) darf ansehen" : "Privat")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Toggle("", isOn: projectShareBinding(project))
                                .labelsHidden()
                                .disabled(busyID == project.id)
                        }
                    }
                }

                Section("Einzelne Zeichnungen") {
                    if library.artworks.isEmpty {
                        Text("Noch keine Zeichnungen")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(library.artworks.sorted { $0.updatedAt > $1.updatedAt }) { artwork in
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(artwork.name)
                                Text(artwork.liveReadOnlyShare ? "Live freigegeben · nur ansehen" : "Privat")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Menu {
                                Button {
                                    sendSnapshot(artwork)
                                } label: {
                                    Label("Als Bild senden", systemImage: "photo")
                                }

                                if artwork.liveReadOnlyShare {
                                    Button(role: .destructive) {
                                        setLive(artwork, enabled: false)
                                    } label: {
                                        Label("Live-Freigabe beenden", systemImage: "eye.slash")
                                    }
                                } else {
                                    Button {
                                        setLive(artwork, enabled: true)
                                    } label: {
                                        Label("Live ansehen lassen", systemImage: "eye")
                                    }
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .frame(width: 44, height: 44)
                            }
                            .disabled(busyID == artwork.id)
                        }
                    }
                }

                if let message {
                    Section {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(message.hasPrefix("Fehler") ? .red : .secondary)
                    }
                }
            }
            .navigationTitle("Mit \(partner.rawValue) teilen")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }

    private func projectShareBinding(_ project: ArtworkProject) -> Binding<Bool> {
        Binding(
            get: {
                library.projects.first(where: { $0.id == project.id })?.sharedReadOnly ?? false
            },
            set: { enabled in
                setProject(project, enabled: enabled)
            }
        )
    }

    private func sendSnapshot(_ artwork: ArtworkDocument) {
        busyID = artwork.id
        message = nil
        Task {
            do {
                let image = ArtworkRenderer.render(document: artwork, library: library)
                try await sharing.sendSnapshot(document: artwork, image: image)
                message = "Bild an \(partner.rawValue) gesendet."
            } catch {
                message = "Fehler: \(error.localizedDescription)"
            }
            busyID = nil
        }
    }

    private func setLive(_ artwork: ArtworkDocument, enabled: Bool) {
        busyID = artwork.id
        message = nil
        Task {
            do {
                if enabled {
                    let project = artwork.projectID.flatMap { id in library.projects.first(where: { $0.id == id }) }
                    let image = ArtworkRenderer.render(document: artwork, library: library)
                    try await sharing.publishLive(document: artwork, project: project, image: image)
                } else {
                    try await sharing.stopLive(artworkID: artwork.id)
                }
                var updated = artwork
                updated.liveReadOnlyShare = enabled
                library.saveDocument(updated)
                message = enabled
                    ? "\(partner.rawValue) kann neue Änderungen sehen, aber nicht bearbeiten."
                    : "Live-Freigabe beendet."
            } catch {
                message = "Fehler: \(error.localizedDescription)"
            }
            busyID = nil
        }
    }

    private func setProject(_ project: ArtworkProject, enabled: Bool) {
        busyID = project.id
        message = nil
        Task {
            do {
                try await sharing.setProjectShared(project, enabled: enabled)
                library.setProjectShared(project.id, shared: enabled)

                let projectArtworks = library.artworks.filter { $0.projectID == project.id }
                if enabled {
                    for artwork in projectArtworks {
                        let image = ArtworkRenderer.render(document: artwork, library: library)
                        try await sharing.publishLive(document: artwork, project: project, image: image)
                    }
                } else {
                    for artwork in projectArtworks where artwork.liveReadOnlyShare {
                        try? await sharing.stopLive(artworkID: artwork.id)
                    }
                }
                message = enabled
                    ? "Projekt für \(partner.rawValue) freigegeben. Nur ansehen."
                    : "\(partner.rawValue) wurde aus dem Projekt entfernt."
            } catch {
                library.setProjectShared(project.id, shared: !enabled)
                message = "Fehler: \(error.localizedDescription)"
            }
            busyID = nil
        }
    }
}
