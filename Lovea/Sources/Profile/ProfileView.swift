import SwiftUI

/// Z-15.1: Profil im Snapchat-Stil, für das eigene wie das Partner-Profil dasselbe Layout
/// (`ProfilInhalt`). Nur das eigene hat das Zahnrad zu den Einstellungen.
struct ProfileView: View {
    let person: Person
    @ObservedObject var session: PersonSession
    /// Spiele-Bilanz aus Block 14 (`SpieleModell`). Leer, bis der Controller sie verdrahtet —
    /// siehe Bericht "Integration: bilanz".
    var bilanz: [(spiel: String, ahmed: Int, annika: Int)] = []

    var body: some View {
        NavigationStack {
            ProfilInhalt(person: person, bilanz: bilanz)
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    if person == session.person {
                        ToolbarItem(placement: .primaryAction) {
                            NavigationLink { EinstellungenView(person: person, session: session) } label: {
                                Image(systemName: "gearshape.fill")
                            }
                        }
                    }
                }
        }
    }
}

/// Für Chat und Karte: gleiches Layout, ohne Zahnrad, als Sheet präsentierbar (ersetzt den
/// Platzhalter `PartnerProfilKarte` — siehe Bericht "Integration: Chat").
struct PartnerProfilView: View {
    let person: Person
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ProfilInhalt(person: person)
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } }
                }
        }
        .presentationDragIndicator(.visible)
    }
}

/// Geteiltes Layout: oben Figur groß und Name, beim Runterscrollen die Details (Z-15.1).
private struct ProfilInhalt: View {
    let person: Person
    var bilanz: [(spiel: String, ahmed: Int, annika: Int)] = []

    private var istPartnerAnsicht: Bool { person != Raum.shared.ich }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                kopf
                VStack(spacing: 20) {
                    kennengelernt
                    andichGedacht
                    spieleBilanz
                    puenktlichKrone
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 32)
        }
    }

    private var kopf: some View {
        VStack(spacing: 8) {
            Group {
                if istPartnerAnsicht {
                    FigurView(FigurenModell.shared.aussehen(person), zustand: anzeige.haupt, abzeichen: abzeichen, groesse: 220)
                        .figurGesten(person: person) { FigurenModell.shared.gesteSenden($0) }
                } else {
                    FigurView(FigurenModell.shared.aussehen(person), zustand: anzeige.haupt, abzeichen: abzeichen, groesse: 220)
                }
            }
            Text(person.name)
                .font(.largeTitle.bold())
            HStack(spacing: 6) {
                Text(Self.geburtsdatum(person))
                Text("·").foregroundStyle(.tertiary)
                Text("\(tageZusammen) Tage zusammen")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .padding(.top, 24)
    }

    private var kennengelernt: some View {
        Text("Kennengelernt am 04.07.2026")
            .font(.footnote)
            .foregroundStyle(.secondary)
    }

    private var andichGedacht: some View {
        HStack(spacing: 10) {
            Image(systemName: "heart.fill").foregroundStyle(Color.loveaRose)
            Text(andichGedachtText)
                .font(.subheadline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.loveaRose.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
    }

    /// Eigenes Profil: wie oft der Partner heute an mich gedacht hat. Partner-Profil: wie oft
    /// ich heute an ihn gedacht habe — sonst wäre die Zahl auf beiden Profilen identisch.
    private var andichGedachtText: String {
        if istPartnerAnsicht {
            let n = FigurenModell.shared.herzHeute[Raum.shared.ich ?? person.partner] ?? 0
            return "Heute \(n)× an \(person.name) gedacht"
        } else {
            let n = FigurenModell.shared.herzHeute[person.partner] ?? 0
            return "Heute \(n)× an dich gedacht"
        }
    }

    @ViewBuilder
    private var spieleBilanz: some View {
        if !bilanz.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Spiele").font(.headline)
                    Spacer()
                    if let krone = gesamtKrone {
                        Label(krone.name, systemImage: "crown.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.yellow)
                    }
                }
                ForEach(Array(bilanz.enumerated()), id: \.offset) { _, eintrag in
                    HStack {
                        Text(eintrag.spiel)
                        Spacer()
                        Text("Ahmed \(eintrag.ahmed) : \(eintrag.annika) Annika")
                            .foregroundStyle(.secondary)
                    }
                    .font(.subheadline)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private var gesamtKrone: Person? {
        let ahmedGesamt = bilanz.reduce(0) { $0 + $1.ahmed }
        let annikaGesamt = bilanz.reduce(0) { $0 + $1.annika }
        guard ahmedGesamt != annikaGesamt else { return nil }
        return ahmedGesamt > annikaGesamt ? .ahmed : .annika
    }

    @ViewBuilder
    private var puenktlichKrone: some View {
        if monatsKrone == person {
            Label("Pünktlichste\(person == .annika ? "" : "r") des Monats", systemImage: "crown.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.yellow)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Color.yellow.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Abzeichen (Z-15.3)

    private var anzeige: FigurenModell.Zustand { FigurenModell.shared.anzeige(person) }

    private var abzeichen: [String] {
        var alle = Set(anzeige.abzeichen)
        let kalender = KalenderModell.shared.zustand
        let jahrestag = kalender.jahrestag.map(Datum.datum)
        let dateHeute = kalender.daten.treffen.contains { $0.datum == Datum.text(Date()) }
        alle.formUnion(BesondereTage.abzeichen(person: person, datum: Date(), jahrestag: jahrestag, dateHeute: dateHeute))
        if monatsKrone == person { alle.insert("krone") }
        return Array(alle)
    }

    private var monatsKrone: Person? {
        let monat = String(Datum.text(Date()).prefix(7))
        return Puenktlich.monatsKrone(ops: KalenderModell.shared.alleOps, monat: monat)
    }

    private var tageZusammen: Int { Datum.tageZwischen("2026-08-26", Datum.text(Date())) }

    private static func geburtsdatum(_ person: Person) -> String {
        person == .ahmed ? "27.02.2008" : "06.06.2008"
    }
}
