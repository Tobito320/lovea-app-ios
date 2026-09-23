import PhotosUI
import SwiftUI
import UIKit

extension Color {
    init(_ rgba: RGBAColor) { self.init(red: rgba.red, green: rgba.green, blue: rgba.blue, opacity: rgba.alpha) }
}

extension RGBAColor {
    init(_ farbe: Color) {
        let aufgeloest = farbe.resolve(in: EnvironmentValues())
        self.init(red: Double(aufgeloest.red), green: Double(aufgeloest.green), blue: Double(aufgeloest.blue), alpha: Double(aufgeloest.opacity))
    }
}

/// Renders behind the chat (Z-5.4): a flat color, an uploaded photo, or one of the person's own
/// drawings (via `ArtworkLibrary`'s cached preview), optionally darkened for text contrast.
struct ChatHintergrundAnsicht: View {
    let ich: Person
    @State private var bild: UIImage?

    private var einstellung: ChatEinstellungen.Hintergrund { ChatEinstellungen.shared.hintergrund(ich) }

    var body: some View {
        ZStack {
            switch einstellung.art {
            case .farbe:
                (einstellung.farbe.map(Color.init) ?? Color(uiColor: .systemBackground))
            case .foto, .zeichnung:
                if let bild {
                    Image(uiImage: bild).resizable().aspectRatio(contentMode: .fill)
                } else {
                    Color(uiColor: .systemBackground)
                }
            }
            if einstellung.abgedunkelt { Color.black.opacity(0.35) }
        }
        .ignoresSafeArea()
        .task(id: einstellung) { await laden() }
    }

    private func laden() async {
        guard let medienId = einstellung.medienId else { bild = nil; return }
        switch einstellung.art {
        case .foto:
            // Split from a `??`-chained `(try? await …)` on purpose: mixing `await` into a nil-
            // coalescing chain like that reads fine but doesn't type-check ("'async' call in a
            // function that does not support concurrency").
            var url = ChatMedien.eigeneQuellen[medienId] ?? Medien.lokal(medienId)
            if url == nil { url = try? await Medien.holen(medienId) }
            guard let url else { bild = nil; return }
            bild = await Bilddatei.laden(url, maxPixel: 2800) // screen-sized, decoded off the main actor
        case .zeichnung:
            guard let id = UUID(uuidString: medienId) else { return }
            bild = await Bilddatei.laden(ArtworkLibrary().previewURL(for: id), maxPixel: 2800)
        case .farbe:
            bild = nil
        }
    }
}

/// Settings sheet for the above (Z-5.4), reached from `ChatKopfzeile`'s menu.
struct ChatHintergrundEinstellung: View {
    let ich: Person
    @Environment(\.dismiss) private var dismiss

    @State private var art: ChatEinstellungen.HintergrundArt
    @State private var farbe: Color
    @State private var abgedunkelt: Bool
    @State private var fotoAuswahl: PhotosPickerItem?
    @State private var fotoMedienId: String?
    @State private var laedt = false
    @State private var zeichnungen: [ArtworkDocument] = []
    @State private var gewaehlteZeichnung: UUID?

    init(ich: Person) {
        self.ich = ich
        let aktuell = ChatEinstellungen.shared.hintergrund(ich)
        _art = State(initialValue: aktuell.art)
        _farbe = State(initialValue: aktuell.farbe.map(Color.init) ?? .white)
        _abgedunkelt = State(initialValue: aktuell.abgedunkelt)
        _fotoMedienId = State(initialValue: aktuell.art == .foto ? aktuell.medienId : nil)
        _gewaehlteZeichnung = State(initialValue: aktuell.art == .zeichnung ? aktuell.medienId.flatMap(UUID.init) : nil)
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Art", selection: $art) {
                    Text("Farbe").tag(ChatEinstellungen.HintergrundArt.farbe)
                    Text("Foto").tag(ChatEinstellungen.HintergrundArt.foto)
                    Text("Eigene Zeichnung").tag(ChatEinstellungen.HintergrundArt.zeichnung)
                }
                switch art {
                case .farbe:
                    ColorPicker("Farbe", selection: $farbe)
                case .foto:
                    PhotosPicker("Foto wählen", selection: $fotoAuswahl, matching: .images)
                    if laedt { ProgressView() }
                case .zeichnung:
                    if zeichnungen.isEmpty {
                        Text("Keine Zeichnungen vorhanden").foregroundStyle(.secondary)
                    } else {
                        Picker("Zeichnung", selection: $gewaehlteZeichnung) {
                            ForEach(zeichnungen) { z in Text(z.name).tag(Optional(z.id)) }
                        }
                    }
                }
                Toggle("Abgedunkelt", isOn: $abgedunkelt)
            }
            .navigationTitle("Chat-Hintergrund")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Fertig") { speichern(); dismiss() } }
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
            }
            .onAppear { zeichnungen = ArtworkLibrary().artworks }
            .onChange(of: fotoAuswahl) { _, neu in ladeFoto(neu) }
        }
    }

    private func ladeFoto(_ item: PhotosPickerItem?) {
        guard let item else { return }
        laedt = true
        Task {
            defer { laedt = false }
            guard let daten = try? await item.loadTransferable(type: Data.self) else { return }
            let id = UUID().uuidString
            guard let ergebnis = await Task.detached(priority: .userInitiated, operation: { MedienKodierung.foto(daten, id: id) }).value
            else { return }
            ChatMedien.eigeneQuellen[id] = ergebnis.original
            fotoMedienId = id
            try? await Medien.hochladen(id: id, original: ergebnis.original, klein: ergebnis.klein)
        }
    }

    private func speichern() {
        let neu: ChatEinstellungen.Hintergrund
        switch art {
        case .farbe:
            neu = ChatEinstellungen.Hintergrund(art: .farbe, farbe: RGBAColor(farbe), medienId: nil, abgedunkelt: abgedunkelt)
        case .foto:
            neu = ChatEinstellungen.Hintergrund(art: .foto, farbe: nil, medienId: fotoMedienId, abgedunkelt: abgedunkelt)
        case .zeichnung:
            neu = ChatEinstellungen.Hintergrund(art: .zeichnung, farbe: nil, medienId: gewaehlteZeichnung?.uuidString, abgedunkelt: abgedunkelt)
        }
        ChatEinstellungen.shared.hintergrundSetzen(neu, ich: ich)
    }
}
