import SwiftUI

/// Einstieg im Home-Tab unter "Unsere Liste": eine Zeile, Tap öffnet `DatesView`.
struct DatesKarte: View {
    let speicher = DateSpeicher.shared

    var body: some View {
        let fortschritt = DateLogik.fortschritt(speicher.ideen)
        NavigationLink {
            DatesView()
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Date-Ideen").font(.headline)
                    Text("\(fortschritt.erledigt) von \(fortschritt.gesamt) erledigt")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
            }
            .padding(16)
            .frame(minHeight: 44)
            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
            .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Date-Ideen, \(fortschritt.erledigt) von \(fortschritt.gesamt) erledigt")
    }
}
