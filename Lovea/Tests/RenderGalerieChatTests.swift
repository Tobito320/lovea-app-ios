import SwiftUI
import XCTest
@testable import Lovea

/// Render boards for the chat (Z-32.4, Z-33.1, Z-33.2): bubble groups on three backdrops, every
/// figure reaction, the effects mid-flight. Visual check in the CI artifact `render-galerie`.
@MainActor
final class RenderGalerieChatTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    private var beispiel: [ChatModell.Nachricht] {
        let roh: [(String, Person, Double, String)] = [
            ("1", .annika, 0, "Hey du 🙂"),
            ("2", .annika, 10, "Bist du schon wach?"),
            ("3", .ahmed, 60, "Guten Morgen!"),
            ("4", .ahmed, 70, "Ja, gerade aufgestanden, schon beim Kaffee ☕️. Heute wird ein langer Tag, aber ich freu mich auf heute Abend mit dir."),
            ("5", .ahmed, 80, "❤️"),
            ("6", .annika, 200, "😂😂"),
            ("7", .annika, 205, "Bis später, hdl"),
        ]
        return roh.map { ChatModell.Nachricht(id: $0.0, von: $0.1, zeit: t0.addingTimeInterval($0.2), text: $0.3) }
    }

    func testBlasenAufDreiBackdrops() {
        let zellen = Backdrops.alle.prefix(3).map { backdrop in
            (titel: backdrop.name, ansicht: AnyView(blasen(backdrop)))
        }
        RenderTafel.speichern("chat-blasen", spalten: 3, zellen: Array(zellen))
    }

    func testChatListenZeile() {
        let zeilen: [(titel: String, ansicht: AnyView)] = [ColorScheme.light, .dark].map { schema in
            let zeile = ChatListenZeile(
                partner: .annika, vorschau: "Bis später, hdl", zeit: "vor 5 Minuten",
                ungelesen: 2, ort: "Schule", online: true, animiert: false
            )
            return (titel: schema == .dark ? "dunkel" : "hell", ansicht: AnyView(
                zeile
                    .padding(16)
                    .frame(width: 390)
                    .background(Color(uiColor: .systemGroupedBackground))
                    .environment(\.colorScheme, schema)
            ))
        }
        RenderTafel.speichern("chat-liste", spalten: 2, zellen: zeilen)
    }

    func testFigurReaktionen() {
        let zellen = FigurReaktionen.alle.map { reaktion in
            (titel: reaktion.titel, ansicht: AnyView(
                FigurReaktionAnsicht(reaktion: reaktion, person: .annika, ahmed: .standard(for: .ahmed), annika: .standard(for: .annika))
                    .frame(width: 180, height: 130)
            ))
        }
        RenderTafel.speichern("chat-reaktionen", spalten: 6, zellen: zellen)
    }

    func testEffekte() {
        let zellen = ChatEffekt.allCases.map { effekt in
            (titel: effekt.titel, ansicht: AnyView(
                ChatEffektAnsicht(effekt: effekt, zeit: 1.2)
                    .frame(width: 200, height: 360)
                    .background(Color(white: 0.2))
            ))
        }
        RenderTafel.speichern("chat-effekte", spalten: 4, zellen: zellen)
    }

    private func blasen(_ backdrop: Backdrop) -> some View {
        let liste = beispiel
        return VStack(spacing: 0) {
            ForEach(Array(liste.enumerated()), id: \.offset) { index, nachricht in
                let layout = ZeilenLayout(
                    vorher: index > 0 ? liste[index - 1] : nil, erste: nachricht, letzte: nachricht,
                    nachher: index + 1 < liste.count ? liste[index + 1] : nil
                )
                HStack(spacing: 0) {
                    if nachricht.von == .ahmed { Spacer(minLength: 40) }
                    NachrichtBlase(nachricht: nachricht, ich: .ahmed, schwanz: layout.gruppenEnde)
                    if nachricht.von != .ahmed { Spacer(minLength: 40) }
                }
                .padding(.top, layout.gruppenAnfang ? 8 : 2)
            }
        }
        .padding(12)
        .frame(width: 330, height: 520, alignment: .top)
        .background(hintergrund(backdrop))
        .environment(\.chatBackdrop, backdrop)
        .environment(\.chatVerlaufHoehe, 520)
        .environment(\.chatBreite, 330)
    }

    @ViewBuilder private func hintergrund(_ backdrop: Backdrop) -> some View {
        if backdrop.ersatz.count == 9 {
            MeshGradient(
                width: 3, height: 3,
                points: [[0, 0], [0.5, 0], [1, 0], [0, 0.5], [0.5, 0.5], [1, 0.5], [0, 1], [0.5, 1], [1, 1]],
                colors: backdrop.ersatz
            )
        } else {
            LinearGradient(colors: backdrop.ersatz, startPoint: .top, endPoint: .bottom)
        }
    }
}
