import MapKit
import SwiftUI

/// Z-27.4 "Unsere Orte": a small heart pin for a `GemeinsamerOrt` on the full-screen map.
struct GemeinsamerOrtPin: View {
    var body: some View {
        Image(systemName: "heart.fill")
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(.white)
            .padding(8)
            .background(Color.loveaRose, in: Circle())
            .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
    }
}

/// Detail sheet for one pin: the day it happened, plus that day's chat photos (Spec 9).
struct GemeinsamerOrtDetail: View {
    let ort: GemeinsamerOrt

    private var fotos: [ChatModell.Nachricht] {
        let tag = Datum.datum(ort.datum)
        return ChatModell.shared.nachrichten.filter { n in
            !n.geloescht && !ChatModell.verschlossen(n)
                && n.medien.contains { $0.typ == "foto" }
                && Calendar.berlin.isDate(n.zeit, inSameDayAs: tag)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(Datum.anzeige(ort.datum)).font(.title3.bold())
                    if !fotos.isEmpty {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 6)], spacing: 6) {
                            ForEach(fotos) { n in
                                ForEach(n.medien.filter { $0.typ == "foto" }, id: \.id) { medium in
                                    MedienKachel(medium: medium, eigene: n.von == Raum.shared.ich)
                                        .frame(height: 90)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                            }
                        }
                    } else {
                        Text("Keine Fotos von diesem Tag im Chat.").foregroundStyle(.secondary)
                    }
                }
                .padding()
            }
            .navigationTitle("Zusammen unterwegs")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }
}
