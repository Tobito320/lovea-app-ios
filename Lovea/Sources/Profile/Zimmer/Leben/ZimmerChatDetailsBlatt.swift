import SwiftUI

/// Die Chat-Einstellungen (Backdrop, Wallpaper, Medien, Sterne, Suche), die vorher als Zeile im Profil standen.
/// Das Profil ist jetzt nur die Szene; der Weg hierher ist der Knopf im Kopf der Szene. Gleiche Ziele wie früher.
struct ZimmerChatDetailsBlatt: View {
    let ich: Person
    /// Wechselt in den Chat (Tab "chat"), `suche` öffnet dort die Suche, `ziel` springt zu einer Nachricht.
    let zumChat: (_ suche: Bool, _ ziel: String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var backdropOffen = false
    @State private var wallpaperOffen = false
    @State private var medienOffen = false
    @State private var sterneOffen = false

    var body: some View {
        NavigationStack {
            List {
                zeile("photo.artframe", "Backdrop", untertitel) { backdropOffen = true }
                zeile("photo.on.rectangle.angled", "Wallpaper", "Du und \(ich.partner.name) seht das Wallpaper.") { wallpaperOffen = true }
                zeile("photo.stack", "Medien", nil) { medienOffen = true }
                zeile("star", "Sterne", nil) { sterneOffen = true }
                zeile("magnifyingglass", "Im Chat suchen", nil) { dismiss(); zumChat(true, nil) }
            }
            .navigationTitle("Chat-Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
        }
        .sheet(isPresented: $wallpaperOffen) { WallpaperAuswahl(partner: ich.partner) }
        .sheet(isPresented: $medienOffen) { MedienUebersicht(ich: ich) }
        .sheet(isPresented: $sterneOffen) { SterneBlatt(ich: ich) { id in dismiss(); zumChat(false, id) } }
        .fullScreenCover(isPresented: $backdropOffen) { BackdropAuswahl() }
    }

    private var untertitel: String {
        switch Backdrops.wahl {
        case .vorlage(let id)?: Backdrops.von(id)?.name ?? Backdrops.neutral.name
        case .foto?: "Eigenes Foto"
        case .zeichnung?: "Eigene Zeichnung"
        case nil: "Für euch beide"
        }
    }

    private func zeile(_ symbol: String, _ titel: String, _ text: String?, _ tun: @escaping () -> Void) -> some View {
        Button(action: tun) {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(titel)
                    if let text { Text(text).font(.footnote).foregroundStyle(.secondary) }
                }
            } icon: {
                Image(systemName: symbol).foregroundStyle(Color.loveaRose)
            }
            .frame(minHeight: 44, alignment: .leading)
        }
        .buttonStyle(.plain)
    }
}
