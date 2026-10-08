import SwiftUI

/// p69: one pill of a strip under the scene (zone or tab). 30 pt to look at, the whole strip height (44 pt)
/// to hit. One view for both strips, so the render gallery draws the very thing the app shows.
struct ProfilPille: View {
    let titel: String
    let aktiv: Bool
    let tun: () -> Void

    var body: some View {
        Button(action: tun) {
            Text(titel)
                .font(.footnote.weight(.semibold))
                .lineLimit(1)
                .foregroundStyle(aktiv ? Color.loveaRose : .secondary)
                .padding(.horizontal, 14)
                .frame(minHeight: 30)
                .background(aktiv ? Color.loveaRose.opacity(0.16) : .clear, in: Capsule())
                .frame(minHeight: ProfilLayout.leistenHoehe)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(titel)
        .accessibilityAddTraits(aktiv ? [.isButton, .isSelected] : .isButton)
    }
}

/// p69: the zone tabs right under the scene (Schlafen, Wohnen, Regal). Chrome: its letters stop growing with
/// Dynamic Type so it never breaks.
struct ProfilZonenLeiste: View {
    let zone: ProfilZone
    let waehle: (ProfilZone) -> Void

    var body: some View {
        HStack(spacing: 6) {
            ForEach(ProfilZone.allCases, id: \.self) { z in
                ProfilPille(titel: z.titel, aktiv: z == zone) { waehle(z) }
            }
        }
        .dynamicTypeSize(ProfilLayout.leistenSchrift)
        .frame(maxWidth: .infinity)
        .frame(height: ProfilLayout.leistenHoehe)
    }
}

/// p69: the tab strip of the part that scrolls (Zimmer, Wir, Erinnerungen, Quests). Wide letters that do not
/// fit in a row slide sideways instead of breaking the strip.
struct ProfilReiterLeiste: View {
    let reiter: [ProfilReiter]
    let aktiv: ProfilReiter?
    let waehle: (ProfilReiter) -> Void

    var body: some View {
        let knoepfe = HStack(spacing: 6) {
            ForEach(reiter) { r in ProfilPille(titel: r.titel, aktiv: r == aktiv) { waehle(r) } }
        }
        ViewThatFits(in: .horizontal) {
            knoepfe.padding(.horizontal, 16)
            ScrollView(.horizontal) { knoepfe.padding(.horizontal, 16) }
                .scrollIndicators(.hidden)
                // The slide is the strip's, not the tab's.
                .simultaneousGesture(
                    DragGesture(minimumDistance: 20).onChanged { wert in
                        if abs(wert.translation.width) > abs(wert.translation.height) { TabWischSperre.shared.beanspruchen() }
                    }
                )
        }
        .dynamicTypeSize(ProfilLayout.leistenSchrift)
        .frame(maxWidth: .infinity)
        .frame(minHeight: ProfilLayout.reiterHoehe)
        .background(Color(uiColor: .systemGroupedBackground))
    }
}
