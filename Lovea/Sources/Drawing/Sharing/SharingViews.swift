// ponytail: Level 2 eingefroren bis Level-1-Abnahme
import SwiftUI
import UIKit

struct SharingConnectionView: View {
    @ObservedObject var sharing: LoveaSharingService
    @Environment(\.dismiss) private var dismiss
    @State private var month = ""
    @State private var day = ""
    @State private var pin = ""
    @State private var errorText: String?
    @State private var connecting = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Lovea verbinden") {
                    Text("Melde \(sharing.person.rawValue) am privaten Lovea-Server an. Das wird nur für Teilen und Live-Ansehen gebraucht.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    HStack {
                        TextField("Monat", text: $month)
                            .keyboardType(.numberPad)
                        Text("–")
                        TextField("Tag", text: $day)
                            .keyboardType(.numberPad)
                    }
                    SecureField("4-stellige PIN", text: $pin)
                        .keyboardType(.numberPad)

                    if let errorText {
                        Text(errorText)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                }
            }
            .navigationTitle("Teilen verbinden")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(connecting ? "Verbinde…" : "Verbinden") {
                        connect()
                    }
                    .disabled(connecting || Int(month) == nil || Int(day) == nil || pin.count != 4)
                }
            }
        }
    }

    private func connect() {
        guard let month = Int(month), let day = Int(day) else { return }
        connecting = true
        errorText = nil
        Task {
            do {
                try await sharing.connect(month: month, day: day, pin: pin)
                dismiss()
            } catch {
                errorText = error.localizedDescription
            }
            connecting = false
        }
    }
}

struct SharingInboxSection: View {
    @ObservedObject var sharing: LoveaSharingService
    let partner: LoveaPerson

    var body: some View {
        if sharing.state == .connected {
            if !sharing.liveArtworks.isEmpty || !sharing.snapshots.isEmpty || !sharing.sharedProjects.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Von \(partner.rawValue)")
                        .font(.title3.bold())

                    if !sharing.sharedProjects.isEmpty {
                        ForEach(sharing.sharedProjects) { project in
                            Label(project.name, systemImage: "folder.badge.person.crop")
                                .font(.subheadline.weight(.semibold))
                        }
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(sharing.liveArtworks) { artwork in
                                SharedArtworkCard(
                                    name: artwork.name,
                                    badge: "Live · nur ansehen",
                                    dataURL: artwork.bild
                                )
                            }
                            ForEach(sharing.snapshots) { snapshot in
                                SharedArtworkCard(
                                    name: snapshot.name,
                                    badge: "Bild",
                                    dataURL: snapshot.bild
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct SharedArtworkCard: View {
    let name: String
    let badge: String
    let dataURL: String
    @State private var showsImage = false

    private var image: UIImage? {
        LoveaSharingService.image(from: dataURL)
    }

    var body: some View {
        Button {
            showsImage = true
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Group {
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Color.secondary.opacity(0.15)
                            .overlay(Image(systemName: "photo"))
                    }
                }
                .frame(width: 160, height: 120)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 14))

                Text(name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(badge)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 160, alignment: .leading)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showsImage) {
            NavigationStack {
                Group {
                    if let image {
                        ZoomableSharedImage(image: image)
                    } else {
                        ContentUnavailableView("Bild nicht verfügbar", systemImage: "photo.badge.exclamationmark")
                    }
                }
                .navigationTitle(name)
                .navigationBarTitleDisplayMode(.inline)
            }
        }
    }
}

private struct ZoomableSharedImage: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss
    @State private var scale = 1.0
    @State private var lastScale = 1.0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .scaleEffect(scale)
                .gesture(
                    MagnifyGesture()
                        .onChanged { value in
                            scale = min(max(lastScale * value.magnification, 1), 8)
                        }
                        .onEnded { _ in
                            lastScale = scale
                        }
                )
                .onTapGesture(count: 2) {
                    withAnimation(.snappy) {
                        scale = scale > 1 ? 1 : 2
                        lastScale = scale
                    }
                }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Fertig") { dismiss() }
                    .foregroundStyle(.white)
            }
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: Image(uiImage: image), preview: SharePreview("Zeichnung", image: Image(uiImage: image)))
                    .foregroundStyle(.white)
            }
        }
    }
}
