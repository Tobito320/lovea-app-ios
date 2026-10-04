import SwiftUI

/// Zeitschätzung des gewählten Tages: "ca. 52 min, 7 min über deinem Slot (45 min)" mit Tipp. Reine Ansicht (Render-Tafel).
struct ZeitKarte: View {
    let urteil: ZeitUrteil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(urteil.titel, systemImage: urteil.warnt ? "exclamationmark.triangle.fill" : "clock")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(urteil.warnt ? Color.orange : Color.primary)
            if let tipp = urteil.tipp {
                Text(tipp.text).font(.footnote).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background((urteil.warnt ? Color.orange : Color.secondary).opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
