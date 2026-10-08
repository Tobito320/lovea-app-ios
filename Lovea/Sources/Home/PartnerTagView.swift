import SwiftUI

/// "<Name>s Tag": senkrechte Zeitleiste des Partners aus schon gesyncten Daten. Nach rechts wischen
/// zeigt gestern, nach links wieder heute. Keine eigenen Abfragen: alles kommt aus `TagModell`.
struct PartnerTagView: View {
    let person: Person
    @State private var seite = 1 // 0 = gestern, 1 = heute
    @State private var jetzt = Date()

    private var gestern: Date { Calendar.berlin.date(byAdding: .day, value: -1, to: jetzt) ?? jetzt }

    var body: some View {
        TabView(selection: $seite) {
            TagSeite(person: person, datum: gestern, heute: false).tag(0)
            TagSeite(person: person, datum: jetzt, heute: true).tag(1)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .navigationTitle(seite == 1 ? "Heute" : "Gestern")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { jetzt = Date() }
    }
}

private struct TagSeite: View {
    let person: Person
    let datum: Date
    let heute: Bool

    var body: some View {
        let ansicht = TagModell.shared.ansicht(person: person, tag: datum)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                kopf(ansicht)
                if heute, let lied = TagModell.shared.hoertGerade(person: person) {
                    Label(lied, systemImage: "music.note").font(.footnote).foregroundStyle(.secondary)
                }
                if ansicht.momente.isEmpty {
                    leer
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(ansicht.momente.enumerated()), id: \.element.id) { index, moment in
                            MomentZeile(moment: moment, letzte: index == ansicht.momente.count - 1, eigene: person == Raum.shared.ich)
                        }
                    }
                }
                if heute, person != Raum.shared.ich { DenkAnDichKnopf(partner: person) }
            }
            .padding(16)
        }
    }

    private func kopf(_ ansicht: TagAnsicht) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(TagLogik.titel(person: person, momente: ansicht.momente.count)).font(.title2.weight(.bold))
            HStack(spacing: 12) {
                Text(heute ? "Heute" : "Gestern").font(.subheadline).foregroundStyle(.secondary)
                if heute { Text(TagModell.shared.statusText(person: person)).font(.subheadline).foregroundStyle(.secondary) }
                Spacer()
                if ansicht.herzen > 0 {
                    Label("\(heute ? "heute" : "gestern") \(ansicht.herzen)×", systemImage: "heart.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.loveaRose)
                }
            }
        }
    }

    private var leer: some View {
        Text(heute ? "Noch nichts los. Sobald \(person.name) etwas macht, steht es hier." : "Gestern gab es hier nichts zu sehen.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 24)
    }
}

private struct MomentZeile: View {
    let moment: TagMoment
    let letzte: Bool
    let eigene: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(TagModell.uhrzeit(moment.zeit))
                .font(.footnote.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 44, alignment: .trailing)
                .padding(.top, 6)
            VStack(spacing: 0) {
                Image(systemName: moment.symbol)
                    .font(.footnote)
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(farbe))
                if !letzte { Rectangle().fill(.quaternary).frame(width: 2).frame(maxHeight: .infinity) }
            }
            VStack(alignment: .leading, spacing: 8) {
                Text(moment.text).font(.body)
                if let id = moment.medienId {
                    MedienKachel(medium: ChatModell.MedienEintrag(id: id, typ: "foto", breite: 1, hoehe: 1), eigene: eigene)
                        .frame(width: 120, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
            .padding(.top, 4)
            .padding(.bottom, 16)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    private var farbe: Color {
        switch moment.sorte {
        case .schlaf: .indigo
        case .schritte: .green
        case .gym: .orange
        case .foto, .snap: .blue
        case .herz: Color.loveaRose
        }
    }
}
