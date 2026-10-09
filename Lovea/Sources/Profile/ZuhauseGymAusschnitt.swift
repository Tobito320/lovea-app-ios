import SwiftUI

/// Kontextszene Gym: the right half of the panorama becomes a small gym cutout while one of the two
/// trains (`ZuhauseKontext.gymGeteilt`); the left half stays the room with the partner at home. The
/// training figure uses the existing `.gym` pose of `FigurView`. Nothing is drawn in any other context.
struct ZuhauseGymAusschnitt: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let kontext = ZuhauseKontext.bestimme(ahmed: FigurenModell.shared.zustand[.ahmed]?.haupt, annika: FigurenModell.shared.zustand[.annika]?.haupt)
        GeometryReader { geo in
            if case .gymGeteilt(_, let weg) = kontext {
                let s = geo.size.width / ProfilSlots.weltBreite
                let oben = geo.size.height - ZuhauseZeichnung.hoehe * s
                let r = ZuhauseKontext.gymAusschnitt
                let hoehe = ZuhauseOrte.figurHoehe * s
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 18 * s)
                        .fill(LinearGradient(colors: [Color(white: 0.20), Color(white: 0.11)], startPoint: .top, endPoint: .bottom))
                    Rectangle().fill(Color(white: 0.30)).frame(height: 36 * s)
                        .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 18 * s, bottomTrailingRadius: 18 * s))
                    FigurView(FigurenModell.shared.aussehen(weg), zustand: .gym, groesse: hoehe,
                              animiert: scenePhase == .active && !reduceMotion, bildrate: ZuhauseSzeneLogik.leerlaufRate,
                              ganzkoerper: true, extras: [.hanteln])
                        .padding(.bottom, 20 * s)
                    Text("\(weg.name) im Gym")
                        .font(.footnote.weight(.semibold)).foregroundStyle(.white.opacity(0.85))
                        .frame(maxHeight: .infinity, alignment: .top).padding(.top, 10 * s)
                }
                .frame(width: r.width * s, height: r.height * s)
                .position(x: r.midX * s, y: oben + r.midY * s)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(weg.name) trainiert im Gym")
            }
        }
    }
}
