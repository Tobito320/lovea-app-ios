import SwiftUI

/// Das Blatt unter dem Raster für den gewählten Tag: Datum, „Tag öffnen ›", dann die gemeinsame
/// `TagesListe`. Kein Sheet mit Haltepunkten, Home ist eine ScrollView; es liegt einfach darunter.
struct TagesBlatt: View {
    let tag: String
    let daten: KalenderDaten
    let ich: Person?
    var aktionen = TagesAktionen()
    var oeffnen: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Capsule()
                .fill(Color(uiColor: .tertiaryLabel))
                .frame(width: 36, height: 5)
                .frame(maxWidth: .infinity)
                .accessibilityHidden(true)
            kopf
            TagesListe(tag: tag, daten: daten, ich: ich, aktionen: aktionen)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 26))
    }

    private var kopf: some View {
        HStack {
            Text(Datum.anzeige(tag))
                .font(.title3.weight(.bold))
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            Button(action: oeffnen) {
                HStack(spacing: 3) {
                    Text("Tag öffnen")
                    Image(systemName: "chevron.right").font(.caption.weight(.bold))
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.loveaRose)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.federnd)
            .accessibilityLabel("Tag öffnen")
        }
    }
}
