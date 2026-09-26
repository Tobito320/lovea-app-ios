import SwiftUI

/// Ziel für die Produktseite eines gespeicherten Eintrags (`EssenEintrag` selbst ist nicht Hashable).
struct EintragZiel: Hashable, Identifiable {
    let id: String
}

/// Eine Mahlzeit eines Tages, wie in YAZIO eine Ebene unter dem Tagebuch. Tipp auf ein Essen öffnet
/// die Produktseite zum Ändern, Wischen löscht.
struct MahlzeitView: View {
    let mahlzeit: Mahlzeit
    let tag: String
    let person: Person

    @State private var offen: EintragZiel?
    @State private var neuOffen = false

    private var modell: ErnaehrungModell { ErnaehrungModell.shared }
    private var bearbeitbar: Bool { person == modell.ich }

    var body: some View {
        let liste = modell.eintraege(person, tag, mahlzeit)
        List {
            Section {
                MahlzeitKopf(tag: tag, summe: ErnaehrungLogik.summe(liste))
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 8, trailing: 0))
            }
            Section {
                if liste.isEmpty {
                    Text(bearbeitbar ? "Noch nichts eingetragen. Scann einfach die Packung." : "Noch nichts eingetragen.")
                        .foregroundStyle(.secondary)
                }
                ForEach(liste) { e in
                    EssenZeile(eintrag: e) { offen = EintragZiel(id: e.id) }
                        .swipeActions {
                            if bearbeitbar {
                                Button("Löschen", systemImage: "trash", role: .destructive) { modell.loeschen(e) }
                            }
                        }
                }
            }
        }
        .fontDesign(.rounded)
        .navigationTitle(mahlzeit.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if bearbeitbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Von gestern übernehmen", systemImage: "arrow.uturn.backward") {
                            modell.kopieren(von: Datum.addTage(tag, -1), nach: tag, mahlzeit: mahlzeit)
                            Haptik.erfolg()
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                    .accessibilityLabel("Mehr")
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if bearbeitbar {
                Button { neuOffen = true } label: {
                    Label("Hinzufügen", systemImage: "plus").font(.headline).frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
        }
        .navigationDestination(item: $offen) { ziel in
            EintragSeite(id: ziel.id, person: person, tag: tag) { offen = nil }
        }
        .sheet(isPresented: $neuOffen) { HinzufuegenBlatt(mahlzeit: mahlzeit, datum: tag) }
    }
}

/// Alle Mahlzeiten eines Tages untereinander ("Mehr" im Tagebuch): Kalorien je Mahlzeit, darunter das Essen.
struct MahlzeitenUebersicht: View {
    let tag: String
    let person: Person

    @State private var offen: EintragZiel?

    private var modell: ErnaehrungModell { ErnaehrungModell.shared }
    private var bearbeitbar: Bool { person == modell.ich }

    var body: some View {
        List {
            ForEach(Mahlzeit.allCases) { m in
                let liste = modell.eintraege(person, tag, m)
                Section {
                    if liste.isEmpty {
                        Text("Nichts eingetragen").foregroundStyle(.secondary)
                    }
                    ForEach(liste) { e in
                        EssenZeile(eintrag: e) { offen = EintragZiel(id: e.id) }
                            .swipeActions {
                                if bearbeitbar {
                                    Button("Löschen", systemImage: "trash", role: .destructive) { modell.loeschen(e) }
                                }
                            }
                    }
                } header: {
                    HStack {
                        Label(m.name, systemImage: m.symbol).font(.headline)
                        Spacer()
                        Text("\(Int(ErnaehrungLogik.summe(liste).kcal.rounded())) kcal").font(.subheadline.weight(.semibold)).monospacedDigit()
                    }
                    .foregroundStyle(Color.primary)
                    .textCase(nil)
                }
            }
        }
        .fontDesign(.rounded)
        .navigationTitle(tagTitel(tag))
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(item: $offen) { ziel in
            EintragSeite(id: ziel.id, person: person, tag: tag) { offen = nil }
        }
    }
}

/// Produktseite eines gespeicherten Eintrags; bei Annikas Einträgen nur ansehen.
private struct EintragSeite: View {
    let id: String
    let person: Person
    let tag: String
    let fertig: () -> Void

    var body: some View {
        if let e = ErnaehrungModell.shared.eintraege(person, tag).first(where: { $0.id == id }) {
            if person == ErnaehrungModell.shared.ich {
                LebensmittelDetailView(lebensmittel: e.lebensmittel, mahlzeit: e.mahlzeit, datum: e.datum, bearbeiten: e, fertig: fertig)
            } else {
                LebensmittelDetailView(lebensmittel: e.lebensmittel, mahlzeit: e.mahlzeit, datum: e.datum, fertig: fertig)
            }
        } else {
            ContentUnavailableView("Eintrag gelöscht", systemImage: "trash")
        }
    }
}

/// Kalorien groß, darunter Kohlenhydrate, Eiweiß, Fett.
private struct MahlzeitKopf: View {
    let tag: String
    let summe: Naehrwerte

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(tagTitel(tag)).font(.subheadline).foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(ernaehrungZahl(Int(summe.kcal.rounded()))).font(.largeTitle.weight(.heavy)).monospacedDigit()
                Text("kcal").font(.headline).foregroundStyle(.secondary)
            }
            HStack(spacing: 0) {
                wert(summe.kohlenhydrate, "Kohlenhydrate")
                wert(summe.protein, "Eiweiß")
                wert(summe.fett, "Fett")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func wert(_ g: Double, _ titel: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(ErnaehrungLogik.zahl(g)) g").font(.headline.weight(.bold)).monospacedDigit()
            Text(titel).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// Name, Menge, kcal. Tipp öffnet die Produktseite.
private struct EssenZeile: View {
    let eintrag: EssenEintrag
    let oeffnen: () -> Void

    var body: some View {
        Button(action: oeffnen) {
            HStack(spacing: 12) {
                LebensmittelBild(url: eintrag.lebensmittel.bildKlein, groesse: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(eintrag.lebensmittel.anzeigeName).font(.body.weight(.semibold)).foregroundStyle(Color.primary)
                    Text(ErnaehrungLogik.mengeText(eintrag.menge, eintrag.einheit, eintrag.lebensmittel))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Text("\(ernaehrungZahl(Int(eintrag.naehrwerte.kcal.rounded()))) kcal")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.primary)
                    .monospacedDigit()
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
            }
            .frame(minHeight: 44)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

/// "Heute", "Gestern", "Morgen" oder das Datum.
func tagTitel(_ tag: String) -> String {
    let heute = Datum.text(Date())
    if tag == heute { return "Heute" }
    if tag == Datum.addTage(heute, -1) { return "Gestern" }
    if tag == Datum.addTage(heute, 1) { return "Morgen" }
    return Datum.anzeige(tag)
}

/// Ganze Zahl mit deutschem Tausenderpunkt.
func ernaehrungZahl(_ n: Int) -> String { n.formatted(.number.locale(Locale(identifier: "de_DE"))) }

/// Produktfoto aus Open Food Facts; ohne geprüftes Foto ein neutrales Feld, nie ein geratenes Bild.
struct LebensmittelBild: View {
    let url: URL?
    var groesse: CGFloat = 44

    var body: some View {
        let form = RoundedRectangle(cornerRadius: groesse * 0.22, style: .continuous)
        Group {
            if let url {
                AsyncImage(url: url) { phase in
                    if let bild = phase.image {
                        bild.resizable().scaledToFit()
                    } else {
                        platzhalter(laedt: phase.error == nil)
                    }
                }
            } else {
                platzhalter(laedt: false)
            }
        }
        .frame(width: groesse, height: groesse)
        .background(Color.white, in: form)
        .clipShape(form)
        .overlay(form.strokeBorder(Color.primary.opacity(0.08)))
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func platzhalter(laedt: Bool) -> some View {
        ZStack {
            Color(uiColor: .tertiarySystemFill)
            if laedt {
                ProgressView()
            } else {
                Image(systemName: "fork.knife").font(.body).foregroundStyle(.secondary)
            }
        }
    }
}
