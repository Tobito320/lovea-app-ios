import SwiftUI
import UIKit

/// Eight scenes with both figures, rendered to 320 x 320 PNG on demand.
enum FreundschaftsSticker: String, CaseIterable, Identifiable, Sendable {
    case umarmen, highFive, kuss, herzFormen, anstossen, tanzen, winken, schlafen

    static let alle: [FreundschaftsSticker] = allCases

    var id: String { rawValue }

    var titel: String {
        switch self {
        case .umarmen: "Umarmen"
        case .highFive: "High-Five"
        case .kuss: "Kuss"
        case .herzFormen: "Herz formen"
        case .anstossen: "Anstoßen"
        case .tanzen: "Tanzen"
        case .winken: "Winken"
        case .schlafen: "Schlafen"
        }
    }

    @MainActor
    func ansicht(ahmed: FigurAussehen, annika: FigurAussehen) -> some View {
        StickerSzene(sticker: self, ahmed: ahmed, annika: annika)
    }

    @MainActor
    func png(ahmed: FigurAussehen, annika: FigurAussehen) -> Data? {
        let renderer = ImageRenderer(content: ansicht(ahmed: ahmed, annika: annika))
        renderer.proposedSize = ProposedViewSize(width: 320, height: 320)
        renderer.scale = 1
        return renderer.uiImage?.pngData()
    }

    fileprivate var szene: (zustand: FigurZustand, abstand: CGFloat, spiegeln: Bool, neigung: Double, symbol: String?) {
        switch self {
        case .umarmen: (.naehe, 48, false, 4, "heart.fill")
        case .highFive: (.imChat, 64, true, 0, "sparkle")
        case .kuss: (.kuss, 50, true, 4, "heart.fill")
        case .herzFormen: (.herz, 60, false, 0, "heart.fill")
        case .anstossen: (.anstossen, 62, true, 0, "sparkles")
        case .tanzen: (.gut, 66, false, 9, "music.note")
        case .winken: (.imChat, 76, false, 0, nil)
        case .schlafen: (.schlaeft, 58, false, 6, "moon.stars.fill")
        }
    }
}

private struct StickerSzene: View {
    let sticker: FreundschaftsSticker
    let ahmed: FigurAussehen
    let annika: FigurAussehen

    private static let rose = Color(red: 1, green: 59 / 255, blue: 92 / 255)

    var body: some View {
        let s = sticker.szene
        ZStack {
            RoundedRectangle(cornerRadius: 64).fill(Color(red: 1, green: 0.92, blue: 0.94))
            FigurView(ahmed, zustand: s.zustand, groesse: 230, animiert: false)
                .rotationEffect(.degrees(s.neigung))
                .offset(x: -s.abstand, y: 45)
            FigurView(annika, zustand: s.zustand, groesse: 230, animiert: false)
                .scaleEffect(x: s.spiegeln ? -1 : 1, y: 1)
                .rotationEffect(.degrees(-s.neigung))
                .offset(x: s.abstand, y: 45)
            if let symbol = s.symbol {
                Image(systemName: symbol)
                    .font(.system(size: sticker == .herzFormen ? 64 : 40, weight: .bold))
                    .foregroundStyle(sticker == .schlafen ? Color(red: 0.42, green: 0.37, blue: 0.66) : Self.rose)
                    .offset(y: sticker == .herzFormen ? -96 : -120)
            }
        }
        .frame(width: 320, height: 320)
        .clipShape(RoundedRectangle(cornerRadius: 64))
    }
}

#Preview("Freundschafts-Sticker") {
    ScrollView {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 170))], spacing: 12) {
            ForEach(FreundschaftsSticker.alle) { s in
                s.ansicht(ahmed: .standard(for: .ahmed), annika: .standard(for: .annika))
                    .scaleEffect(0.5)
                    .frame(width: 160, height: 160)
            }
        }
        .padding()
    }
}
