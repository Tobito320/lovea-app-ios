import SwiftUI

/// Das Idee-Blatt für die Render-Tafel: gleiche Bausteine (Chips, Abschnittstitel) wie das Blatt, aber ohne
/// TextField, Toggle, Buttons und MapKit (ImageRenderer zeichnet die nicht). Die Karte ist eine graue Fläche.
struct DateIdeeBlattRenderInhalt: View {
    let idee: DateIdee

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            kopf
            Text(idee.titel).font(.title.weight(.bold))
            HStack(spacing: 8) {
                ForEach(DateKategorie.allCases.prefix(5), id: \.self) { art in
                    DatesChip(titel: art.titel, aktiv: idee.kategorie == art)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .clipped()
            ort
            links
            VStack(spacing: 0) {
                DatesHaarlinie()
                HStack {
                    Text("Erledigt").font(.body.weight(.semibold))
                    Spacer()
                    Capsule().fill(idee.erledigt ? Color.loveaRose : DatesStil.haarlinie)
                        .frame(width: 51, height: 31)
                }
                .frame(minHeight: 52)
                DatesHaarlinie()
                HStack {
                    Text("Notiz").font(.body.weight(.semibold))
                    Spacer()
                    Text(idee.notiz ?? "Hinzufügen").foregroundStyle(.secondary)
                }
                .frame(minHeight: 52)
                DatesHaarlinie()
            }
            Label("Idee löschen", systemImage: "trash").font(.body.weight(.semibold)).foregroundStyle(.red)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
        .frame(width: 393, height: 780, alignment: .top)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipped()
    }

    private var kopf: some View {
        HStack {
            Text("Abbrechen").foregroundStyle(Color.loveaRose)
            Spacer()
            Text("Idee").font(.body.weight(.bold))
            Spacer()
            Text("Fertig").fontWeight(.semibold).foregroundStyle(Color.loveaRose)
        }
        .frame(height: 52)
    }

    @ViewBuilder private var ort: some View {
        if let ort = idee.ort {
            VStack(alignment: .leading, spacing: 8) {
                DatesAbschnittsTitel(text: "Ort")
                Color.secondary.opacity(0.12)
                    .frame(height: 170)
                    .overlay {
                        Image(systemName: "mappin")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundStyle(.red)
                            .offset(y: -15)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(ort.name).font(.body.weight(.semibold))
                        if let adresse = ort.adresse { Text(adresse).font(.subheadline).foregroundStyle(.secondary) }
                    }
                    Spacer(minLength: 8)
                    Label("Ort suchen", systemImage: "magnifyingglass")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.loveaRose)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 44)
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.loveaRose.opacity(0.4), lineWidth: 1))
                }
                HStack(spacing: 0) {
                    Label("Karte zeigen", systemImage: "map").frame(maxWidth: .infinity)
                    Divider().frame(height: 24)
                    Label("In Karten öffnen", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
                }
                .font(.subheadline)
                .foregroundStyle(Color.loveaRose)
            }
        }
    }

    private var links: some View {
        VStack(alignment: .leading, spacing: 8) {
            DatesAbschnittsTitel(text: "Links")
            ZyklusFlussLayout {
                ForEach(idee.links) { DateLinkChip(link: $0) }
                DateLinkNeuChip()
            }
        }
    }
}
