import SwiftUI
import UIKit

/// Still first frame of an exercise GIF (a list thumbnail), loaded via `UebungsMedien`.
/// `UIImage(contentsOfFile:)` on a GIF gives its first frame. `bild` seeds it for the render board.
struct UebungVorschau: View {
    let id: String
    @State private var bild: UIImage?

    init(id: String, bild: UIImage? = nil) {
        self.id = id
        _bild = State(initialValue: bild)
    }

    var body: some View {
        ZStack {
            Color.white
            if let bild {
                Image(uiImage: bild).resizable().scaledToFit()
            } else if !UebungsKatalog.hatVideo(id) {
                Image(systemName: "figure.strengthtraining.traditional").font(.title3).foregroundStyle(Color.gray)
            }
        }
        .task(id: id) {
            guard bild == nil, let url = await UebungsMedien.datei(id) else { return }
            bild = await Task.detached(priority: .userInitiated) { UIImage(contentsOfFile: url.path) }.value
        }
        .accessibilityHidden(true)
    }
}

/// Thumbnail, German name, "Brust · Langhantel".
struct UebungZeile: View {
    let uebung: Uebung
    var bild: UIImage? = nil

    var body: some View {
        HStack(spacing: 12) {
            UebungVorschau(id: uebung.id, bild: bild)
                .frame(width: 56, height: 56)
                .clipShape(.rect(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(uebung.name).font(.body.weight(.medium)).lineLimit(2)
                Text("\(uebung.muskel) · \(uebung.geraet)").font(.footnote).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}

/// Search the catalog (German or English), filter by body part, open a row to watch the GIF,
/// plus adds right away. Stays open so a whole day can be filled in one go.
/// Ohne `hinzufuegen`: die Übungsliste zum Stöbern (Gym-Seite), eingebettet im Stapel von Health,
/// ohne Plus, ohne "Erstellen". Eine Übung öffnet Historie und Rekorde.
struct UebungsSuche: View {
    var hinzufuegen: ((PlanUebung) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    /// nil = Hanteln & Maschinen (Standard), `UebungsKatalog.alleGeraete` oder ein einzelnes Gerät.
    @State private var geraet: String?
    @State private var muskel: String?
    @State private var filterOffen: FilterArt?
    @State private var hinzugefuegt: Set<String> = []
    @State private var eigeneOffen = false
    @State private var eigenerName = ""

    var body: some View {
        if hinzufuegen == nil {
            seite
        } else {
            NavigationStack { seite }
        }
    }

    private var seite: some View {
        liste
            .searchable(text: $text, placement: .navigationBarDrawer(displayMode: .always), prompt: "Übung suchen")
            .navigationTitle("Übungen")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: String.self) { id in
                if let u = UebungsKatalog.nachId[id] {
                    if hinzufuegen == nil {
                        UebungDetail(uebung: u)
                    } else {
                        UebungDetail(uebung: u) { waehlen(u) }
                    }
                }
            }
            .toolbar {
                if hinzufuegen != nil {
                    ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } }
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Erstellen") { eigeneOffen = true }
                    }
                }
            }
            .alert("Eigene Übung", isPresented: $eigeneOffen) {
                TextField("Name", text: $eigenerName)
                Button("Abbrechen", role: .cancel) { eigenerName = "" }
                Button("Hinzufügen") { eigeneHinzufuegen() }
            }
    }

    private func passt(_ u: Uebung, geraet: String?, muskel: String?) -> Bool {
        UebungsKatalog.passtGeraet(u, wahl: geraet) && (muskel.map { u.muskel == $0 } ?? true)
    }

    private var liste: some View {
        let basis = UebungsKatalog.alle.filter { passt($0, geraet: geraet, muskel: muskel) }
        let treffer = UebungsKatalog.suchen(text, in: basis)
        let weitere = weitereTreffer(text, muskel: muskel)
        let zuletzt = text.isEmpty ? zuletztBenutzt(geraet: geraet, muskel: muskel) : []
        let bekannt = Set(zuletzt.map(\.id))
        let vorschlaege = text.isEmpty ? UebungsKatalog.vorschlaege(in: basis).filter { !bekannt.contains($0.id) } : []
        return List {
            Section {
                filter.listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16)).listRowBackground(Color.clear).listRowSeparator(.hidden)
            }
            if !zuletzt.isEmpty {
                Section("Zuletzt benutzt") {
                    ForEach(zuletzt) { u in zeile(u) }
                }
            }
            if !vorschlaege.isEmpty {
                Section("Beliebte Übungen") {
                    ForEach(vorschlaege) { u in zeile(u) }
                }
            }
            Section(treffer.isEmpty && weitere.isEmpty ? "Nichts gefunden" : text.isEmpty ? "\(treffer.count) Übungen" : "Suchergebnisse") {
                ForEach(treffer) { u in zeile(u) }
            }
            if !weitere.isEmpty {
                Section("Mit anderem Gerät") {
                    ForEach(weitere) { u in zeile(u) }
                }
            }
        }
        .sheet(item: $filterOffen) { art in
            switch art {
            case .geraet:
                FilterBlatt(titel: "Gerät", gruppen: [
                    ("", [UebungsKatalog.standardTitel, UebungsKatalog.alleGeraete]),
                    ("Freihanteln und Maschinen", UebungsKatalog.geraete.filter(UebungsKatalog.standardGeraete.contains)),
                    ("Weitere Geräte", UebungsKatalog.geraete.filter { !UebungsKatalog.standardGeraete.contains($0) }),
                ], auswahl: $geraet, vorgabe: UebungsKatalog.standardTitel) { g in
                    UebungsKatalog.alle.filter { passt($0, geraet: g, muskel: muskel) }.count
                }
            case .muskel:
                FilterBlatt(titel: "Muskelgruppe", gruppen: UebungsKatalog.koerperteile.map { ($0, UebungsKatalog.muskeln($0)) }, auswahl: $muskel) { m in
                    UebungsKatalog.alle.filter { passt($0, geraet: geraet, muskel: m) }.count
                }
            }
        }
    }

    /// Mit Suchtext zeigt die Suche unter den Standard-Treffern auch andere Geräte (Band, Kettlebell …).
    private func weitereTreffer(_ text: String, muskel: String?) -> [Uebung] {
        guard !text.isEmpty, geraet == nil else { return [] }
        let rest = UebungsKatalog.alle.filter { u in !UebungsKatalog.standardGeraete.contains(u.geraet) && (muskel.map { u.muskel == $0 } ?? true) }
        return Array(UebungsKatalog.suchen(text, in: rest).prefix(15))
    }

    /// Die eigenen letzten Übungen, auch nach Gerät und Muskel gefiltert; ohne Gerätewahl jedes Gerät.
    private func zuletztBenutzt(geraet: String?, muskel: String?) -> [Uebung] {
        UebungsKatalog.zuletzt(TrainingModell.shared.sessions(Raum.shared.ich ?? .ahmed)).filter { passt($0, geraet: geraet ?? UebungsKatalog.alleGeraete, muskel: muskel) }
    }

    /// Wie in Hevy: zwei gleich breite Knöpfe, jeder öffnet ein Blatt mit Kacheln.
    private var filter: some View {
        HStack(spacing: 10) {
            filterKnopf(geraet ?? UebungsKatalog.standardTitel, an: geraet != nil) { filterOffen = .geraet }
            filterKnopf(muskel ?? "Alle Muskeln", an: muskel != nil) { filterOffen = .muskel }
        }
    }

    private func filterKnopf(_ titel: String, an: Bool, _ aktion: @escaping () -> Void) -> some View {
        Button(action: aktion) {
            Text(titel)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(an ? Color.accentColor : Color(uiColor: .tertiarySystemFill), in: .rect(cornerRadius: 12, style: .continuous))
                .foregroundStyle(an ? Color.white : Color.primary)
        }
        .buttonStyle(.federnd)
        .accessibilityAddTraits(an ? .isSelected : [])
    }

    private func zeile(_ u: Uebung) -> some View {
        let drin = hinzugefuegt.contains(u.id)
        return HStack(spacing: 4) {
            NavigationLink(value: u.id) { UebungZeile(uebung: u) }
            if hinzufuegen != nil {
                Button { waehlen(u) } label: {
                    Image(systemName: drin ? "checkmark.circle.fill" : "plus.circle.fill")
                        .font(.title2)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(drin ? Color.green : Color.accentColor)
                        .contentTransition(.symbolEffect(.replace))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(drin ? "\(u.name) nochmal hinzufügen" : "\(u.name) hinzufügen")
            }
        }
    }

    private func waehlen(_ u: Uebung) {
        hinzufuegen?(.neu(u))
        hinzugefuegt.insert(u.id)
        Haptik.erfolg()
    }

    private func eigeneHinzufuegen() {
        let name = eigenerName.trimmingCharacters(in: .whitespacesAndNewlines)
        eigenerName = ""
        guard !name.isEmpty else { return }
        hinzufuegen?(.eigene(name))
        Haptik.erfolg()
    }
}

/// The looping GIF of one exercise on white; loads it on first view (`UebungsMedien`).
struct UebungGif: View {
    let id: String
    @State private var url: URL?
    @State private var fehlt = false

    var body: some View {
        ZStack {
            Color.white
            if let url {
                AnimiertesGif(url: url, fuellen: false)
            } else if !UebungsKatalog.hatVideo(id) {
                Label("Kein Video für diese Übung", systemImage: "figure.strengthtraining.traditional")
                    .font(.footnote)
                    .foregroundStyle(Color.gray)
                    .padding()
            } else if fehlt {
                Label("Video lädt, sobald du Netz hast", systemImage: "wifi.slash")
                    .font(.footnote)
                    .foregroundStyle(Color.gray)
                    .padding()
            } else {
                ProgressView().tint(Color.gray)
            }
        }
        .task(id: id) {
            url = await UebungsMedien.datei(id)
            fehlt = url == nil && UebungsKatalog.hatVideo(id)
        }
    }
}

enum FilterArt: String, Identifiable {
    case geraet, muskel
    var id: String { rawValue }
}

/// Das Filter-Blatt aus Hevy: Kacheln in zwei Spalten, unten "Filter löschen" und die laufende
/// Trefferzahl. Ein Tipp wählt, noch ein Tipp wählt ab.
struct FilterBlatt: View {
    let titel: String
    /// Überschrift (leer = keine) und ihre Einträge.
    let gruppen: [(String, [String])]
    @Binding var auswahl: String?
    /// Eintrag, der gilt, solange nichts gewählt ist (`auswahl == nil`); ein Tipp darauf löscht die Wahl.
    var vorgabe: String? = nil
    let zahl: (String?) -> Int

    @Environment(\.dismiss) private var dismiss
    private static let spalten = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(gruppen, id: \.0) { gruppe in
                        VStack(alignment: .leading, spacing: 10) {
                            if !gruppe.0.isEmpty {
                                Text(gruppe.0).font(.subheadline).foregroundStyle(.secondary)
                            }
                            LazyVGrid(columns: Self.spalten, spacing: 10) {
                                ForEach(gruppe.1, id: \.self) { eintrag in kachel(eintrag) }
                            }
                        }
                    }
                }
                .padding(16)
            }
            .navigationTitle(titel)
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                HStack(spacing: 10) {
                    Button { auswahl = nil } label: {
                        Text("Filter löschen").frame(maxWidth: .infinity, minHeight: 36)
                    }
                    .buttonStyle(.bordered)
                    Button { dismiss() } label: {
                        Text("\(zahl(auswahl)) Ergebnisse anzeigen").monospacedDigit().frame(maxWidth: .infinity, minHeight: 36)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.bar)
            }
        }
        .presentationDetents([.large])
    }

    private func kachel(_ eintrag: String) -> some View {
        let an = auswahl == eintrag || (auswahl == nil && eintrag == vorgabe)
        return Button {
            auswahl = an || eintrag == vorgabe ? nil : eintrag
            Haptik.auswahl()
        } label: {
            Text(eintrag)
                .font(.body.weight(.medium))
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                .padding(.horizontal, 14)
                .background(an ? Color.accentColor : Color(uiColor: .secondarySystemGroupedBackground), in: .rect(cornerRadius: 14, style: .continuous))
                .foregroundStyle(an ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(an ? .isSelected : [])
    }
}
