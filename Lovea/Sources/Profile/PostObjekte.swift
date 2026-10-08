import SwiftUI

/// p67 B: Briefkasten und Telefon als antippbare Objekte in der Profil-Szene. Roter Punkt bei neuer
/// Post. Briefkasten: Briefe lesen und schreiben. Telefon: Sprachpost hören und aufnehmen.
struct PostObjekte: View {
    let ich: Person
    var chat = ChatModell.shared
    @AppStorage("lovea.post.briefeGesehen") private var briefeGesehen: Double = 0
    @AppStorage("lovea.post.sprachGesehen") private var sprachGesehen: Double = 0
    @State private var offen: PostArt?

    private var partner: Person { ich == .ahmed ? .annika : .ahmed }

    var body: some View {
        let briefe = PostLogik.neu(PostLogik.briefe(chat.nachrichten, von: partner), seit: Date(timeIntervalSince1970: briefeGesehen))
        let sprache = PostLogik.neu(PostLogik.sprachpost(chat.nachrichten, von: partner), seit: Date(timeIntervalSince1970: sprachGesehen))
        PostObjektLeiste(briefeNeu: briefe > 0, sprachNeu: sprache > 0) { offen = $0 }
            .sheet(item: $offen) { art in
                PostBlatt(art: art, ich: ich, partner: partner, chat: chat)
                    .onAppear { gesehen(art) }
            }
    }

    private func gesehen(_ art: PostArt) {
        let jetzt = Date().timeIntervalSince1970
        if art == .briefe { briefeGesehen = jetzt } else { sprachGesehen = jetzt }
    }
}

enum PostArt: String, Identifiable { case briefe, sprache; var id: String { rawValue } }

/// Nur die Bilder, ohne Modell: Render-Galerie und Profil zeigen dasselbe.
struct PostObjektLeiste: View {
    let briefeNeu: Bool
    let sprachNeu: Bool
    var tippen: (PostArt) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            objekt(.briefe, "tray.full.fill", "Briefkasten", neu: briefeNeu)
            objekt(.sprache, "phone.fill", "Telefon", neu: sprachNeu)
        }
        .padding(.leading, 16)
        .padding(.top, 64)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func objekt(_ art: PostArt, _ symbol: String, _ name: String, neu: Bool) -> some View {
        Button { tippen(art) } label: {
            Image(systemName: symbol)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(.black.opacity(0.35), in: .circle)
                .overlay(alignment: .topTrailing) {
                    if neu { Circle().fill(.red).frame(width: 14, height: 14).overlay(Circle().stroke(.white, lineWidth: 2)) }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(name)
        .accessibilityValue(neu ? "neue Post" : "")
    }
}

/// Lesen, Hören, Schreiben.
struct PostBlatt: View {
    let art: PostArt
    let ich: Person
    let partner: Person
    let chat: ChatModell
    @State private var entwurf = ""
    @State private var sprachVorschau: SprachEntwurf?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if art == .briefe { briefeListe } else { sprachListe }
            }
            .navigationTitle(art == .briefe ? "Briefkasten" : "Telefon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
    }

    @ViewBuilder private var briefeListe: some View {
        Section("Schreiben") {
            TextField("Brief an \(partner.name)", text: $entwurf, axis: .vertical).lineLimit(3...8)
            Button("Abschicken") {
                guard let text = PostLogik.briefText(entwurf) else { return }
                chat.nachrichtSenden(text: text)
                entwurf = ""
            }
            .disabled(PostLogik.briefText(entwurf) == nil)
        }
        Section("Lesen") {
            let alle = PostLogik.briefe(chat.nachrichten, von: partner).reversed()
            if alle.isEmpty { Text("Noch keine Briefe.").foregroundStyle(.secondary) }
            ForEach(Array(alle)) { n in
                VStack(alignment: .leading, spacing: 4) {
                    Text(n.zeit.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary)
                    Text(PostLogik.lesetext(n))
                }
            }
        }
    }

    @ViewBuilder private var sprachListe: some View {
        Section("Aufnehmen") {
            SprachAufnahmeButton(ich: ich, antwortAuf: nil, onGesendet: {}, vorschau: $sprachVorschau)
        }
        Section("Hören") {
            let alle = PostLogik.sprachpost(chat.nachrichten, von: partner).reversed()
            if alle.isEmpty { Text("Noch keine Sprachpost.").foregroundStyle(.secondary) }
            ForEach(Array(alle)) { n in
                if let medium = n.medien.first {
                    SprachBlase(medium: medium, quelle: SprachQuelle(nachrichtID: n.id, von: n.von))
                }
            }
        }
    }
}
