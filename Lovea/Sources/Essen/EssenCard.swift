import SwiftUI

/// Karte im Health-Tab: Kalorien und Eiweiß von heute, Tipp führt in die Tagesansicht.
struct EssenCard: View {
    private var store: EssenStore { EssenStore.shared }
    private var heute: String { Datum.text(Date()) }
    private var ich: Person { Raum.shared.ich ?? .ahmed }

    var body: some View {
        let summe = store.summe(ich, tag: heute)
        let ziele = store.ziele(ich)
        NavigationLink {
            EssenTagView()
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Essen").font(.headline)
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                }
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(summe.kcal)").font(.title.bold()).monospacedDigit()
                    Text("von \(ziele.kcal) kcal").font(.subheadline).foregroundStyle(.secondary)
                }
                ProgressView(value: Swift.min(Double(summe.kcal), Double(ziele.kcal)), total: Double(Swift.max(ziele.kcal, 1)))
                    .tint(Color.person(ich))
                Text("Eiweiß \(Int(summe.protein.rounded())) von \(ziele.protein) g")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Essen heute: \(summe.kcal) von \(ziele.kcal) Kilokalorien, Eiweiß \(Int(summe.protein.rounded())) von \(ziele.protein) Gramm")
    }
}

private enum EssenBlatt: Identifiable {
    case neu
    case bearbeiten(EssenMahlzeit)
    case coach
    case bericht
    case ziele

    var id: String {
        switch self {
        case .neu: "neu"
        case .bearbeiten(let m): "bearbeiten-\(m.id)"
        case .coach: "coach"
        case .bericht: "bericht"
        case .ziele: "ziele"
        }
    }
}

/// Tagesansicht: Übersicht, Mahlzeiten von heute, Woche. Von hier aus Foto, Coach, Bericht, Ziele.
struct EssenTagView: View {
    private var store: EssenStore { EssenStore.shared }
    private var heute: String { Datum.text(Date()) }
    private var ich: Person { Raum.shared.ich ?? .ahmed }
    @State private var blatt: EssenBlatt?

    var body: some View {
        let ziele = store.ziele(ich)
        let summe = store.summe(ich, tag: heute)
        let mahlzeiten = store.liste(ich, tag: heute)
        List {
            Section {
                uebersicht(summe: summe, ziele: ziele)
            }
            Section("Heute") {
                if mahlzeiten.isEmpty {
                    Text("Noch nichts eingetragen. Fotografier deine nächste Mahlzeit.")
                        .foregroundStyle(.secondary)
                }
                ForEach(mahlzeiten) { m in
                    Button {
                        blatt = .bearbeiten(m)
                    } label: {
                        zeile(m)
                    }
                    .buttonStyle(.plain)
                }
                .onDelete { positionen in
                    for i in positionen { store.loeschen(mahlzeiten[i].id, fuer: ich) }
                }
            }
            Section("Diese Woche") {
                woche(ziele: ziele)
            }
        }
        .navigationTitle("Essen")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    blatt = .neu
                } label: {
                    Image(systemName: "camera.fill")
                }
                .accessibilityLabel("Mahlzeit fotografieren")
                Menu {
                    Button("Coach fragen", systemImage: "bubble.left.and.bubble.right") { blatt = .coach }
                    Button("Tagesbericht", systemImage: "doc.text") { blatt = .bericht }
                    Button("Ziele", systemImage: "target") { blatt = .ziele }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("Mehr")
            }
        }
        .sheet(item: $blatt) { b in
            switch b {
            case .neu: EssenNeuView()
            case .bearbeiten(let m): EssenNeuView(bestehend: m)
            case .coach: CoachView()
            case .bericht: BerichtView()
            case .ziele: EssenZieleView()
            }
        }
    }

    private func uebersicht(summe: EssenSumme, ziele: EssenZiele) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(summe.kcal)").font(.largeTitle.bold()).monospacedDigit()
                Text("von \(ziele.kcal) kcal").foregroundStyle(.secondary)
                Spacer()
                Text("noch \(Swift.max(ziele.kcal - summe.kcal, 0))").font(.subheadline.weight(.semibold)).monospacedDigit()
            }
            ProgressView(value: Swift.min(Double(summe.kcal), Double(ziele.kcal)), total: Double(Swift.max(ziele.kcal, 1)))
                .tint(Color.person(ich))
            HStack {
                makro("Eiweiß", summe.protein, ziel: Double(ziele.protein))
                makro("Kohlenhydrate", summe.kohlenhydrate, ziel: nil)
                makro("Fett", summe.fett, ziel: nil)
            }
            Text(EssenZiele.titel(ziele.ziel)).font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func makro(_ name: String, _ wert: Double, ziel: Double?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(name).font(.caption).foregroundStyle(.secondary)
            Text(ziel.map { "\(Int(wert.rounded())) / \(Int($0)) g" } ?? "\(Int(wert.rounded())) g")
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func zeile(_ m: EssenMahlzeit) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(m.titel).font(.subheadline.weight(.semibold)).lineLimit(1)
                Text("\(m.art.titel) · \(m.zeit.formatted(.dateTime.hour().minute().locale(Locale(identifier: "de_DE"))))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(m.kcal) kcal").font(.subheadline).monospacedDigit().foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
    }

    private func woche(ziele: EssenZiele) -> some View {
        let tage = HabitLogik.wochenTage(heute: heute)
        let werte = tage.map { store.summe(ich, tag: $0).kcal }
        let hoechst = Swift.max(werte.max() ?? 0, ziele.kcal, 1)
        return HStack(alignment: .bottom, spacing: 8) {
            ForEach(Array(tage.enumerated()), id: \.offset) { i, tag in
                VStack(spacing: 3) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(werte[i] > 0 ? Color.person(ich) : Color(uiColor: .tertiarySystemFill))
                        .frame(width: 18, height: Swift.max(3, CGFloat(werte[i]) / CGFloat(hoechst) * 56))
                    Text(["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"][Datum.wochentag(tag) - 1])
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 76, alignment: .bottom)
        .accessibilityHidden(true)
    }
}
