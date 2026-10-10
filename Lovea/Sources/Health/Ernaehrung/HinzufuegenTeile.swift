import SwiftUI

// MARK: - Typen

// Alle vier Enums unten haben keine Associated Values, deshalb synthetisiert Swift `Equatable` und
// `Hashable` schon ohne jede Deklaration (anders als bei Structs/Enums mit Payload). Trotzdem hier
// explizit angegeben, damit der `AuswahlKnopf<T: ... & Hashable>`-Constraint und `k == aktiv`
// (`HinzuKachel?`) beim Lesen sofort als beabsichtigt erkennbar sind, nicht nur "funktioniert zufällig".

enum HinzuTyp: String, CaseIterable, Hashable {
    case lebensmittel = "Lebensmittel", mahlzeiten = "Mahlzeiten", rezepte = "Rezepte"
}

enum HinzuSortierung: String, CaseIterable, Hashable {
    case haeufig = "Häufig", zuletzt = "Zuletzt", favoriten = "Favoriten"
}

enum SuchChip: Equatable {
    case favoriten, vonMir, vonPartner
}

enum HinzuKachel: String, CaseIterable, Identifiable, Hashable {
    case suche, kamera, barcode, sprache, mehr
    var id: String { rawValue }

    var titel: String {
        switch self {
        case .suche: "Suche"
        case .kamera: "Kamera"
        case .barcode: "Barcode"
        case .sprache: "Sprache/Text"
        case .mehr: "Mehr"
        }
    }

    var symbol: String {
        switch self {
        case .suche: "magnifyingglass"
        case .kamera: "camera.fill"
        case .barcode: "barcode.viewfinder"
        case .sprache: "text.bubble.fill"
        case .mehr: "ellipsis"
        }
    }
}

// MARK: - Kopf und Kacheln

/// Kreis mit Zähler links (schließt das Blatt), Mahlzeit-Name mittig.
struct HinzuKopf: View {
    let titel: String
    let zaehler: Int
    let schliessen: () -> Void

    var body: some View {
        HStack {
            Button(action: schliessen) {
                ZStack {
                    Circle().strokeBorder(Color.accentColor, lineWidth: 2)
                    Text("\(zaehler)").font(.footnote.weight(.semibold)).foregroundStyle(Color.accentColor)
                }
                .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            Spacer()
            Text(titel).font(.headline)
            Spacer()
            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}

/// Fünf Kacheln wie YAZIO: Suche, Kamera, Barcode, Sprache/Text, Mehr. `aktiv` zeigt Rand und Tönung.
struct KachelReihe: View {
    var aktiv: HinzuKachel?
    let tippen: (HinzuKachel) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(HinzuKachel.allCases) { k in
                    Button { tippen(k) } label: {
                        VStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(k == aktiv ? Color.accentColor.opacity(0.18) : Color(uiColor: .secondarySystemBackground))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .strokeBorder(k == aktiv ? Color.accentColor : .clear, lineWidth: 2)
                                )
                                .frame(width: 88, height: 80)
                                .overlay {
                                    Image(systemName: k.symbol)
                                        .font(.title2)
                                        .foregroundStyle(k == aktiv ? Color.accentColor : Color.primary)
                                }
                            Text(k.titel).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

/// Rahmen-Knopf mit Text und `chevron.down`, Menü mit Häkchen vor dem aktiven Wert.
struct AuswahlKnopf<T: RawRepresentable & CaseIterable & Hashable>: View where T.RawValue == String, T.AllCases: RandomAccessCollection {
    @Binding var wert: T

    var body: some View {
        Menu {
            ForEach(Array(T.allCases), id: \.self) { fall in
                Button { wert = fall } label: {
                    if fall == wert { Label(fall.rawValue, systemImage: "checkmark") } else { Text(fall.rawValue) }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(wert.rawValue).lineLimit(1)
                Image(systemName: "chevron.down").font(.caption)
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(.separator))
        }
    }
}

/// Öffnet den Such-Modus statt direkt zu tippen (eigenes Suchfeld wie YAZIO, kein `.searchable`).
struct SuchFeldKnopf: View {
    let platzhalter: String
    let tippen: () -> Void

    var body: some View {
        Button(action: tippen) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                Text(platzhalter).foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.separator))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}

// MARK: - Such-Modus

/// Eigenes Suchfeld im Such-Modus, mit Fokus beim Erscheinen und "Abbrechen".
struct SuchKopf: View {
    @Binding var text: String
    let abbrechen: () -> Void
    @FocusState private var fokussiert: Bool

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Suchen", text: $text).focused($fokussiert)
                if !text.isEmpty {
                    Button { text = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Suche leeren")
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color.accentColor))
            Button("Abbrechen", action: abbrechen)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .onAppear { fokussiert = true }
    }
}

/// "Favoriten", "Von mir erstellt", "Von <Partner>".
struct SuchChips: View {
    @Binding var auswahl: SuchChip?
    let partner: Person

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(.favoriten, "Favoriten", "star.fill")
                chip(.vonMir, "Von mir erstellt", "pencil")
                chip(.vonPartner, "Von \(partner.name)", "person.fill")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    private func chip(_ wert: SuchChip, _ titel: String, _ symbol: String) -> some View {
        let aktiv = auswahl == wert
        return Button { auswahl = aktiv ? nil : wert } label: {
            Label(titel, systemImage: symbol)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Capsule().fill(aktiv ? Color.accentColor.opacity(0.18) : Color(uiColor: .secondarySystemBackground)))
                .foregroundStyle(aktiv ? Color.accentColor : Color.primary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Zeilen und Karten (nur Werte, keine Singletons)

/// Name, Standardportion, kcal und ein Plus zum Direkt-Eintragen (Bild yazio-05).
struct HinzuZeile: View {
    let lebensmittel: Lebensmittel
    var eingetragen = false
    let tippen: () -> Void
    let plus: () -> Void
    /// Eigenes Lebensmittel/Rezept: lange drücken zeigt Bearbeiten/Löschen (YAZIO-Pendant zur alten
    /// "Eigene"-Sektion, siehe Review Task 10 Punkt 2).
    var istEigen = false
    var bearbeiten: () -> Void = {}
    var loeschen: () -> Void = {}

    @State private var loeschenFragen = false

    private var portionText: String {
        if let menge = lebensmittel.portionMenge {
            return "1 \(ErnaehrungLogik.einheitName(.portion, lebensmittel)) (\(ErnaehrungLogik.zahl(menge)) g)"
        }
        return "100 g"
    }

    private var kcalText: String {
        let kcal = lebensmittel.portionMenge.map { lebensmittel.pro100.kcal * $0 / 100 } ?? lebensmittel.pro100.kcal
        return "\(Int(kcal.rounded())) kcal"
    }

    var body: some View {
        HStack(spacing: 12) {
            Button(action: tippen) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(lebensmittel.name).foregroundStyle(.primary)
                    Text(portionText).font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Text(kcalText).font(.subheadline).foregroundStyle(.secondary)
            Button(action: plus) {
                Image(systemName: eingetragen ? "checkmark.circle.fill" : "plus.circle")
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("\(lebensmittel.name) eintragen")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) { Divider().padding(.leading, 16) }
        .contextMenu {
            if istEigen {
                Button("Bearbeiten", systemImage: "pencil", action: bearbeiten)
                Button("Löschen", systemImage: "trash", role: .destructive) { loeschenFragen = true }
            }
        }
        .confirmationDialog("\(lebensmittel.name) löschen?", isPresented: $loeschenFragen, titleVisibility: .visible) {
            Button("Löschen", role: .destructive, action: loeschen)
        }
    }
}

/// Karte im Such-Modus (Bild yazio-09): Name fett, Marke/Portion, unten Typ-Chip und kcal, oben Plus.
struct SuchKarte: View {
    let lebensmittel: Lebensmittel
    let typLabel: String
    let plus: () -> Void
    let tippen: () -> Void
    var kannKopieren = false
    var kopieren: () -> Void = {}
    var istFavorit = false
    var favoritUmschalten: () -> Void = {}
    /// Eigenes Lebensmittel/Rezept: Kontextmenü zeigt Bearbeiten/Löschen statt Kopieren/Favorit.
    var istEigen = false
    var bearbeiten: () -> Void = {}
    var loeschen: () -> Void = {}

    @State private var loeschenFragen = false

    private var untertitel: String {
        let marke = lebensmittel.marke ?? "Eigenes"
        let portion = lebensmittel.portionMenge.map { "1 \(ErnaehrungLogik.einheitName(.portion, lebensmittel)) (\(ErnaehrungLogik.zahl($0)) g)" } ?? "100 g"
        return "\(marke), \(portion)"
    }

    private var kcalText: String {
        let kcal = lebensmittel.portionMenge.map { lebensmittel.pro100.kcal * $0 / 100 } ?? lebensmittel.pro100.kcal
        return "\(Int(kcal.rounded())) kcal"
    }

    var body: some View {
        Button(action: tippen) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(lebensmittel.name).font(.body.weight(.semibold)).foregroundStyle(.primary)
                        Text(untertitel).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    Button(action: plus) {
                        Image(systemName: "plus.circle").font(.title2).foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.borderless)
                }
                HStack {
                    Text(typLabel)
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color(uiColor: .tertiarySystemBackground)))
                    Spacer()
                    Text(kcalText).font(.subheadline).foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color(uiColor: .secondarySystemBackground)))
        }
        .buttonStyle(.plain)
        .contextMenu {
            if istEigen {
                Button("Bearbeiten", systemImage: "pencil", action: bearbeiten)
                Button("Löschen", systemImage: "trash", role: .destructive) { loeschenFragen = true }
            } else if kannKopieren {
                Button("Zu mir kopieren", systemImage: "doc.on.doc", action: kopieren)
                Button(istFavorit ? "Favorit entfernen" : "Favorit", systemImage: istFavorit ? "star.slash" : "star", action: favoritUmschalten)
            }
        }
        .confirmationDialog("\(lebensmittel.name) löschen?", isPresented: $loeschenFragen, titleVisibility: .visible) {
            Button("Löschen", role: .destructive, action: loeschen)
        }
    }
}

// MARK: - Erstellen-Blatt (Bild yazio-04)

enum ErstellenEintrag: String, CaseIterable, Identifiable {
    case schnell, mitBarcode, ohneBarcode, mahlzeit, rezept
    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .schnell: "bolt.fill"
        case .mitBarcode: "barcode"
        case .ohneBarcode: "carrot.fill"
        case .mahlzeit: "takeoutbag.and.cup.and.straw.fill"
        case .rezept: "book.pages.fill"
        }
    }

    var titel: String {
        switch self {
        case .schnell: "Schnell hinzufügen"
        case .mitBarcode: "Neues Lebensmittel mit Barcode"
        case .ohneBarcode: "Neues Lebensmittel ohne Barcode"
        case .mahlzeit: "Neue Mahlzeit"
        case .rezept: "Neues Rezept"
        }
    }

    var untertitel: String {
        switch self {
        case .schnell: "Tracke Kalorien und Nährwerte ohne ein neues Lebensmittel zu erstellen"
        case .mitBarcode: "Einzelnes Lebensmittel (z. B. Cornflakes, Kellog's)"
        case .ohneBarcode: "Einzelnes Lebensmittel (z. B. Brötchen)"
        case .mahlzeit: "Lebensmittel, die du oft zusammen isst (z. B. Cornflakes mit Milch)"
        case .rezept: "Ein Rezept mit optionaler Anleitung (z. B. selbstgemachte Champignoncremesuppe)"
        }
    }
}

/// Die fünf Karten, nur eine Auswahl-Aktion, kein Singleton: für die Hinzufügen-Seite und die Render-Tafel.
struct ErstellenListe: View {
    let tippen: (ErstellenEintrag) -> Void

    var body: some View {
        VStack(spacing: 12) {
            ForEach(ErstellenEintrag.allCases) { eintrag in
                Button { tippen(eintrag) } label: {
                    HStack(spacing: 14) {
                        Image(systemName: eintrag.symbol).font(.title2).foregroundStyle(Color.accentColor).frame(width: 32)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(eintrag.titel).font(.body.weight(.semibold)).foregroundStyle(.primary)
                            Text(eintrag.untertitel).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color(uiColor: .secondarySystemBackground)))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
    }
}

/// "Was möchtest du erstellen?" als eigenes Blatt.
struct ErstellenBlatt: View {
    let tippen: (ErstellenEintrag) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView { ErstellenListe(tippen: { eintrag in dismiss(); tippen(eintrag) }) }
                .navigationTitle("Was möchtest du erstellen?")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Schließen") { dismiss() } } }
        }
    }
}

// MARK: - "Kommt bald" und Barcode-Vorschläge

/// Ein Satz, ein Knopf, Höhe 220 pt.
struct KommtBaldBlatt: View {
    let titel: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Text(titel).font(.title3.weight(.semibold))
            Text("Kommt bald.").foregroundStyle(.secondary)
            Button("Okay") { dismiss() }.buttonStyle(.borderedProminent)
        }
        .padding(24)
        .presentationDetents([.height(220)])
    }
}

/// "Meintest du …?" bei Namens-Vorschlägen aus der Barcode-Kette ohne eigenen Treffer.
struct VorschlaegeBlatt: View {
    let name: String
    let treffer: [Lebensmittel]
    let auswahl: (Lebensmittel) -> Void
    let keinesDavon: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(treffer) { l in
                        Button { dismiss(); auswahl(l) } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(l.name).font(.body.weight(.semibold)).foregroundStyle(.primary)
                                if let marke = l.marke { Text(marke).font(.caption).foregroundStyle(.secondary) }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color(uiColor: .secondarySystemBackground)))
                        }
                        .buttonStyle(.plain)
                    }
                    Button("Nichts davon, Nährwerte fotografieren") { dismiss(); keinesDavon() }
                        .buttonStyle(.bordered)
                        .padding(.top, 8)
                }
                .padding(16)
            }
            .navigationTitle("Meintest du \(name)?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } } }
        }
    }
}

// MARK: - Fertig

struct FertigKnopf: View {
    let aktion: () -> Void

    var body: some View {
        Button("Fertig", action: aktion)
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.bar)
    }
}
