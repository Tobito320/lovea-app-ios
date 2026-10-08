import SwiftUI

enum PostArt: String, Identifiable { case briefe, sprache; var id: String { rawValue } }

/// p71 (aus p67 B): Briefkasten und Telefon als antippbare Objekte in der Profil-Szene, mit rotem Punkt bei neuer Post.
/// Der Briefkasten öffnet die Briefe (Öffne, wenn ...), das Telefon die Sprachpost; die Karte im Home-Tab ist dafür weggefallen.
struct PostObjekte: View {
    var briefe = BriefeSpeicher.shared
    var post = SprachpostSpeicher.shared
    @State private var offen: PostArt?

    var body: some View {
        PostObjektLeiste(briefeNeu: briefe.ungeoeffnet, sprachNeu: post.ungehoert) { offen = $0 }
            .sheet(item: $offen) { art in
                NavigationStack {
                    Group {
                        if art == .briefe { BriefeView() } else { SprachpostView() }
                    }
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { offen = nil } } }
                }
            }
    }
}

/// Nur die Bilder, ohne Modell: Render-Galerie und Profil zeigen dasselbe.
struct PostObjektLeiste: View {
    let briefeNeu: Int
    let sprachNeu: Int
    var tippen: (PostArt) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            objekt(.briefe, "tray.full.fill", "Briefkasten", neu: briefeNeu)
            objekt(.sprache, "phone.fill", "Telefon", neu: sprachNeu)
        }
        .padding(.leading, 16)
        .padding(.top, 120)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func objekt(_ art: PostArt, _ symbol: String, _ name: String, neu: Int) -> some View {
        Button { tippen(art) } label: {
            Image(systemName: symbol)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(.black.opacity(0.35), in: .circle)
                .overlay(alignment: .topTrailing) {
                    if PostLogik.punkt(neu) { Circle().fill(.red).frame(width: 14, height: 14).overlay(Circle().stroke(.white, lineWidth: 2)) }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(PostLogik.beschriftung(name, neu: neu))
    }
}
