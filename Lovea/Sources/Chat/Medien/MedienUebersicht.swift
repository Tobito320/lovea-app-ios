import SwiftUI
import UIKit

/// Media overview (Z-5.4): photos/videos/links/voice as a date-sorted grid, "Mit Gesichtern" and
/// "Meine Sterne" filters.
struct MedienUebersicht: View {
    let ich: Person
    @Environment(\.dismiss) private var dismiss
    @State private var nurGesichter = false
    @State private var nurSterne = false

    private var eintraege: [ChatModell.Nachricht] {
        ChatModell.shared.nachrichten.filter { nachricht in
            guard !nachricht.geloescht else { return false }
            guard istRelevant(nachricht) else { return false }
            if nurSterne, !nachricht.gesternt.contains(ich) { return false }
            if nurGesichter {
                guard let medium = nachricht.medien.first(where: { $0.typ == "foto" }),
                      GesichtsFilter.hatGesichter(medium.id) == true
                else { return false }
            }
            return true
        }
        .sorted { $0.zeit > $1.zeit }
    }

    private func istRelevant(_ nachricht: ChatModell.Nachricht) -> Bool {
        if nachricht.medien.contains(where: { ["foto", "video", "sprache"].contains($0.typ) }) { return true }
        return ersterLink(in: nachricht.text ?? "") != nil
    }

    var body: some View {
        NavigationStack {
            Group {
                if eintraege.isEmpty {
                    ContentUnavailableView("Keine Medien", systemImage: "photo.on.rectangle.angled")
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 4) {
                            ForEach(eintraege) { nachricht in UebersichtKachel(nachricht: nachricht) }
                        }
                        .padding(4)
                    }
                }
            }
            .navigationTitle("Medien")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } }
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Toggle("Mit Gesichtern", isOn: $nurGesichter)
                        Toggle("Meine Sterne", isOn: $nurSterne)
                    } label: { Image(systemName: "line.3.horizontal.decrease.circle") }
                }
            }
        }
    }
}

private struct UebersichtKachel: View {
    let nachricht: ChatModell.Nachricht
    @State private var bild: UIImage?

    var body: some View {
        Group {
            if let medium = nachricht.medien.first(where: { $0.typ == "foto" || $0.typ == "video" }) {
                ZStack(alignment: .bottomTrailing) {
                    if let bild {
                        Image(uiImage: bild).resizable().aspectRatio(contentMode: .fill)
                    } else {
                        Rectangle().fill(.thinMaterial)
                    }
                    if medium.typ == "video" {
                        Image(systemName: "video.fill").font(.caption2).foregroundStyle(.white).padding(4)
                    }
                }
                .task(id: medium.id) { await laden(medium) }
            } else if nachricht.medien.contains(where: { $0.typ == "sprache" }) {
                VStack(spacing: 4) {
                    Image(systemName: "waveform")
                    Text(nachricht.zeit.formatted(date: .abbreviated, time: .omitted)).font(.caption2)
                }
                .foregroundStyle(.secondary)
            } else if let text = nachricht.text, let url = ersterLink(in: text) {
                VStack(alignment: .leading, spacing: 2) {
                    Image(systemName: "link")
                    Text(url.host ?? text).font(.caption2).lineLimit(2)
                }
                .foregroundStyle(.secondary)
                .padding(6)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .aspectRatio(1, contentMode: .fill)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func laden(_ medium: ChatModell.MedienEintrag) async {
        var url = ChatMedien.eigeneQuellen[medium.id] ?? Medien.lokal(medium.id)
        if url == nil { url = try? await Medien.holen(medium.id) }
        guard let url else { return }
        if medium.typ == "video" {
            bild = await Videobild.erstesBild(url)
        } else {
            bild = UIImage(contentsOfFile: url.path)
            await GesichtsFilter.pruefen(id: medium.id, dateiURL: url)
        }
    }
}

/// Pure: first URL in a text, or nil. Shared by the overview and the chat bubble's link preview.
func ersterLink(in text: String) -> URL? {
    guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return nil }
    let bereich = NSRange(text.startIndex..., in: text)
    return detector.firstMatch(in: text, range: bereich)?.url
}
