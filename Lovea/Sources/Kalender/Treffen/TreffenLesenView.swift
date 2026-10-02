import SwiftUI

/// Treffen lesen: Kopf (Datum, Titel, von bis mit Dauer), der Ablauf Punkt für Punkt, darunter die
/// Checkliste. Nimmt alle Daten als Parameter (kein `Raum`, keine ScrollView), damit die Render-Tafel
/// ihn zeigen kann. Auf dem iPad steht die Checkliste rechts neben dem Ablauf.
struct TreffenLesenInhalt: View {
    let datum: String
    let titel: String
    let von: String?
    let bis: String?
    let punkte: [TreffenPunkt]
    let ich: Person
    let jetzt: Date
    var vorherige: KalenderModell.TreffenEintrag.Vorherige?
    let checkliste: [KalenderModell.ChecklistEintrag]
    var abhaken: (KalenderModell.ChecklistEintrag) -> Void = { _ in }

    @Environment(\.horizontalSizeClass) private var groesse

    private var breit: Bool { groesse == .regular }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            kopf
            vorherigeFassung
            if breit {
                HStack(alignment: .top, spacing: 32) {
                    ablauf.frame(maxWidth: .infinity, alignment: .top)
                    if !checkliste.isEmpty {
                        VStack(spacing: 0) {
                            Divider()
                            ChecklistAbschnitt(eintraege: checkliste, abhaken: abhaken)
                        }
                        .frame(width: 260)
                    }
                }
            } else {
                ablauf
                if !checkliste.isEmpty {
                    Divider()
                    ChecklistAbschnitt(eintraege: checkliste, abhaken: abhaken)
                }
            }
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: breit ? 720 : .infinity, alignment: .leading)
        .frame(maxWidth: .infinity)
    }

    private var kopf: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 7) {
                Image(systemName: "heart.fill")
                    .foregroundStyle(Color.loveaRose)
                Text(Datum.anzeige(datum))
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline.weight(.semibold))
            Text(titel.isEmpty ? "Treffen" : titel)
                .font(.largeTitle.weight(.bold))
                .accessibilityAddTraits(.isHeader)
            if let zeile = TreffenAnsichtWerte.zeitKopf(von: von, bis: bis) {
                HStack(spacing: 8) {
                    Text(zeile)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    if let dauer = TreffenAnsichtWerte.dauerText(von: von, bis: bis) {
                        Text(dauer)
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 14)
    }

    @ViewBuilder
    private var vorherigeFassung: some View {
        if let vorherige {
            VStack(alignment: .leading, spacing: 4) {
                Text("Vorherige Fassung von \(vorherige.von.name)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(vorherige.text)
                    .font(.callout)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
            .padding(.bottom, 14)
        }
    }

    private var ablauf: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(punkte) { punkt in
                Divider()
                PunktZeile(punkt: punkt, ansicht: TreffenLogik.ansicht(punkt, ich: ich, jetzt: jetzt), jetzt: jetzt)
            }
        }
    }
}

/// „Checkliste, 2 von 4 erledigt" und die Aufgaben. Lesen: nur abhaken. Bearbeiten: löschen und neu.
struct ChecklistAbschnitt: View {
    let eintraege: [KalenderModell.ChecklistEintrag]
    var abhaken: (KalenderModell.ChecklistEintrag) -> Void = { _ in }
    var loeschen: ((KalenderModell.ChecklistEintrag) -> Void)?
    var neu: Binding<String>?
    var hinzufuegen: () -> Void = {}

    private var erledigt: Int { eintraege.filter(\.erledigt).count }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label("Checkliste", systemImage: "checklist")
                    .font(.headline)
                Spacer(minLength: 8)
                Text("\(erledigt) von \(eintraege.count) erledigt")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(minHeight: 52)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            ForEach(eintraege) { zeile($0) }
            if let neu {
                HStack {
                    TextField("Neuer Punkt", text: neu)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(hinzufuegen)
                    Button("Hinzufügen", action: hinzufuegen)
                        .disabled(neu.wrappedValue.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.bottom, 8)
            }
        }
    }

    private func zeile(_ aufgabe: KalenderModell.ChecklistEintrag) -> some View {
        HStack {
            Button { abhaken(aufgabe) } label: {
                Image(systemName: aufgabe.erledigt ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(aufgabe.erledigt ? Color.loveaRose : .secondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(aufgabe.text)
            .accessibilityValue(aufgabe.erledigt ? "erledigt" : "offen")
            Text(aufgabe.text)
                .strikethrough(aufgabe.erledigt)
                .foregroundStyle(aufgabe.erledigt ? .secondary : .primary)
                .accessibilityHidden(true)
            Spacer()
            if let loeschen {
                Button { loeschen(aufgabe) } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("„\(aufgabe.text)“ löschen")
            }
        }
        .buttonStyle(.plain)
    }
}
