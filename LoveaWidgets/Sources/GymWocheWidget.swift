import AppIntents
import Foundation
import SwiftUI
import WidgetKit

/// Mo–So als Punkte, erledigte Tage gefüllt mit Haken, heute umrandet. Auch vom Gym-Duell genutzt.
struct GymTageReihe: View {
    let tage: [WidgetStand.TagEintrag]
    let heute: String
    let farbe: Color
    let groesse: CGFloat

    var body: some View {
        HStack(spacing: 3) {
            ForEach(tage, id: \.datum) { tag in
                ZStack {
                    Circle().fill(tag.erledigt ? farbe : Color.secondary.opacity(0.18))
                    if tag.erledigt {
                        Image(systemName: "checkmark").font(.system(size: groesse * 0.5, weight: .bold)).foregroundStyle(.white)
                    }
                    if tag.datum == heute { Circle().stroke(farbe, lineWidth: 1.5).padding(-2) }
                }
                .frame(width: groesse, height: groesse)
                .widgetAccentable(tag.erledigt)
            }
        }
    }
}
