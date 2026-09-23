import SwiftUI
import UIKit

/// Z-41.2 "Unsere Orte": a shared place as a round photo bubble with its name underneath, like Snap
/// Map's place bubbles. The photo is that day's first chat photo, else a heart. Content layer, so
/// material instead of glass.
struct OrtBlase: View {
    let ort: GemeinsamerOrt
    let tippen: () -> Void
    @State private var bild: UIImage?

    // ponytail: saved place name, else the day - no POI lookup per bubble (rate-limited network
    // calls that can also guess a neighbour's shop). Add `OrtePOI` naming if dates feel too bare.
    private var name: String {
        OrteModell.shared.ortBei(lat: ort.lat, lon: ort.lon)?.name
            ?? Datum.datum(ort.datum).formatted(.dateTime.day().month(.wide).locale(Locale(identifier: "de_DE")))
    }

    var body: some View {
        Button(action: tippen) {
            VStack(spacing: 4) {
                foto
                    .frame(width: 56, height: 56)
                    .clipShape(.circle)
                    .overlay { Circle().stroke(.white, lineWidth: 3) }
                    .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                Text(name)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.regularMaterial, in: .capsule)
            }
        }
        .buttonStyle(.federnd)
        .accessibilityLabel("Unser Ort: \(name)")
        .accessibilityHint("Zeigt die Fotos von diesem Tag")
        .task(id: ort.id) { await fotoLaden() }
    }

    @ViewBuilder
    private var foto: some View {
        if let bild {
            Image(uiImage: bild).resizable().scaledToFill()
        } else {
            Color.loveaRose.overlay {
                Image(systemName: "heart.fill").font(.title3.bold()).foregroundStyle(.white)
            }
        }
    }

    /// The local file, else exactly one download - never a retry loop per bubble.
    private func fotoLaden() async {
        let erstes = GemeinsamerOrtDetail.fotos(am: ort.datum).first?.medien.first { $0.typ == "foto" }
        guard let erstes, let url = try? await Medien.holen(erstes.id) else { return }
        bild = await Bilddatei.laden(url, maxPixel: 240)
    }
}

/// Detail sheet for one place: the day it happened, plus that day's chat photos (Spec 9).
struct GemeinsamerOrtDetail: View {
    let ort: GemeinsamerOrt

    /// Chat messages with photos from that Berlin day. Former time-capsule messages count like any
    /// other (Runde 3: the capsule is gone, Spec 2.10).
    static func fotos(am datum: String) -> [ChatModell.Nachricht] {
        let tag = Datum.datum(datum)
        return ChatModell.shared.nachrichten.filter { n in
            !n.geloescht && n.medien.contains { $0.typ == "foto" } && Calendar.berlin.isDate(n.zeit, inSameDayAs: tag)
        }
    }

    var body: some View {
        let fotos = Self.fotos(am: ort.datum)
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
