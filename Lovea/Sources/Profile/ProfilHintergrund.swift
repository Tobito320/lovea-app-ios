import PhotosUI
import SwiftUI
import UIKit

/// Z-25.2: `profil.hintergrund` per person — `{art:"foto"|"backdrop", medienId?|id?}` (Zielplan
/// Schnittstellen). Each person sets only their own; unlike the old `profilWallpaper` (shared,
/// `ProfilBlaetter.swift`), which stays exactly as-is for the partner-profile header.
enum ProfilHintergrund {
    enum Wert: Equatable {
        case foto(medienId: String)
        case backdrop(id: String)
        case keiner
    }

    static func lesen(_ person: Person) -> Wert {
        guard case .object(let o)? = EinstellungenModell.shared.werte[person]?["profil.hintergrund"],
              case .string(let art)? = o["art"] else { return .keiner }
        switch art {
        case "foto":
            guard case .string(let id)? = o["medienId"] else { return .keiner }
            return .foto(medienId: id)
        case "backdrop":
            guard case .string(let id)? = o["id"] else { return .keiner }
            return .backdrop(id: id)
        default: return .keiner
        }
    }

    static func fotoSetzen(_ medienId: String) {
        EinstellungenModell.shared.setzen("profil.hintergrund", .object(["art": .string("foto"), "medienId": .string(medienId)]))
    }

    static func backdropSetzen(_ id: String) {
        EinstellungenModell.shared.setzen("profil.hintergrund", .object(["art": .string("backdrop"), "id": .string(id)]))
    }
}

/// The own profile header's background: `person`'s own `profil.hintergrund`, falling back to the
/// old shared `profilWallpaper` (so nobody sees a blank header before picking one), then the plain
/// Lovea gradient (`BackdropView(id: nil)`).
struct EigenerHintergrund: View {
    let person: Person

    var body: some View {
        switch ProfilHintergrund.lesen(person) {
        case .foto(let medienId): ProfilFoto(medienId: medienId)
        case .backdrop(let id): BackdropView(id: id)
        case .keiner:
            if let alt = ProfilWallpaper.medienId { ProfilFoto(medienId: alt) } else { BackdropView(id: nil) }
        }
    }
}

/// Loads and shows one uploaded/own-drawing photo by media id — the same loading dance
/// `ProfilWallpaper` already does, factored out so both backgrounds can show a photo.
struct ProfilFoto: View {
    let medienId: String
    @State private var bild: UIImage?

    var body: some View {
        Color.clear
            .overlay { if let bild { Image(uiImage: bild).resizable().scaledToFill() } }
            .clipped()
            .accessibilityHidden(true)
            .task(id: medienId) { await laden() }
    }

    private func laden() async {
        var url = ChatMedien.eigeneQuellen[medienId] ?? Medien.lokal(medienId)
        if url == nil { url = try? await Medien.holen(medienId) }
        guard let url else { return }
        bild = await Bilddatei.laden(url, maxPixel: 2000)
    }
}

/// Z-25.2 picker: a photo (reuses `WallpaperAuswahl`'s upload flow via its `speichern` closure),
/// ≥12 free backdrops, and purchased `backdrop.*` ones this person owns.
struct EigenerHintergrundAuswahl: View {
    let person: Person
    @Environment(\.dismiss) private var dismiss
    @State private var fotoOffen = false
    @State private var gewaehlt = 0

    private var besitz: BesitzLogik.Ergebnis {
        PunkteModell.shared.einkaufsStand(preis: { ShopKatalog.artikel($0)?.preis }).besitz
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Button {
                        fotoOffen = true
                    } label: {
                        Label("Foto wählen", systemImage: "photo.on.rectangle")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.bordered)
                    .tint(Color.loveaRose)

                    gruppe("Backdrops", BackdropKatalog.kostenlos)

                    let gekauft = BackdropKatalog.gekauft.filter { besitz.besitzt($0.id, person) }
                    if !gekauft.isEmpty {
                        gruppe("Deine gekauften Backdrops", gekauft)
                    }
                }
                .padding(16)
            }
            .navigationTitle("Hintergrund")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } }
            }
            .sensoryFeedback(.selection, trigger: gewaehlt)
            .sheet(isPresented: $fotoOffen) {
                WallpaperAuswahl(partner: person.partner, speichern: { ProfilHintergrund.fotoSetzen($0) }, zeigtEntfernen: false)
            }
        }
    }

    private func gruppe(_ titel: String, _ eintraege: [BackdropEintrag]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(titel).font(.headline)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 84), spacing: 10)], spacing: 10) {
                ForEach(eintraege) { e in
                    Button {
                        ProfilHintergrund.backdropSetzen(e.id)
                        gewaehlt += 1
                        dismiss()
                    } label: {
                        BackdropView(id: e.id)
                            .frame(width: 84, height: 84)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(aktiv(e.id) ? Color.loveaRose : .clear, lineWidth: 3))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(e.name)
                    .accessibilityAddTraits(aktiv(e.id) ? .isSelected : [])
                }
            }
        }
    }

    private func aktiv(_ id: String) -> Bool {
        if case .backdrop(let aktuell) = ProfilHintergrund.lesen(person) { return aktuell == id }
        return false
    }
}
