import SwiftUI
import UIKit

/// Still first frame of an exercise GIF (a list thumbnail). `UIImage(contentsOfFile:)` on a GIF
/// gives its first frame. `bild` seeds it for the render board.
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
            if let bild { Image(uiImage: bild).resizable().scaledToFit() }
        }
        .task(id: id) {
            guard bild == nil, let url = UebungsKatalog.gif(id) else { return }
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
struct UebungsSuche: View {
    let hinzufuegen: (PlanUebung) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var koerper: String?
    @State private var hinzugefuegt: Set<String> = []
    @State private var eigeneOffen = false
    @State private var eigenerName = ""

    var body: some View {
        NavigationStack {
            liste
                .searchable(text: $text, placement: .navigationBarDrawer(displayMode: .always), prompt: "z. B. Bankdrücken")
                .navigationTitle("Übung hinzufügen")
                .navigationBarTitleDisplayMode(.inline)
                .navigationDestination(for: String.self) { id in
                    if let u = UebungsKatalog.nachId[id] { UebungDetail(uebung: u) { waehlen(u) } }
                }
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } }
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Eigene Übung", systemImage: "square.and.pencil") { eigeneOffen = true }
                    }
                }
                .alert("Eigene Übung", isPresented: $eigeneOffen) {
                    TextField("Name", text: $eigenerName)
                    Button("Abbrechen", role: .cancel) { eigenerName = "" }
                    Button("Hinzufügen") { eigeneHinzufuegen() }
                }
        }
    }

    private var liste: some View {
        let basis = koerper.map { k in UebungsKatalog.alle.filter { $0.koerper == k } } ?? UebungsKatalog.alle
        let treffer = UebungsKatalog.suchen(text, in: basis)
        return List {
            Section {
                filter.listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
            }
            Section(treffer.isEmpty ? "Nichts gefunden" : "\(treffer.count) Übungen") {
                ForEach(treffer) { u in zeile(u) }
            }
        }
    }

    private var filter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip("Alle", an: koerper == nil) { koerper = nil }
                ForEach(UebungsKatalog.koerperteile, id: \.self) { k in chip(k, an: koerper == k) { koerper = k } }
            }
            .padding(.horizontal, 16)
        }
    }

    private func chip(_ titel: String, an: Bool, _ aktion: @escaping () -> Void) -> some View {
        Button {
            Haptik.auswahl()
            aktion()
        } label: {
            Text(titel)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 14)
                .frame(minHeight: 36)
                .background(Capsule().fill(an ? Color.accentColor : Color(uiColor: .tertiarySystemFill)))
                .foregroundStyle(an ? Color.white : Color.primary)
                .frame(minHeight: 44)
        }
        .buttonStyle(.federnd)
        .accessibilityAddTraits(an ? .isSelected : [])
    }

    private func zeile(_ u: Uebung) -> some View {
        let drin = hinzugefuegt.contains(u.id)
        return HStack(spacing: 4) {
            NavigationLink(value: u.id) { UebungZeile(uebung: u) }
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

    private func waehlen(_ u: Uebung) {
        hinzufuegen(.neu(u))
        hinzugefuegt.insert(u.id)
        Haptik.erfolg()
    }

    private func eigeneHinzufuegen() {
        let name = eigenerName.trimmingCharacters(in: .whitespacesAndNewlines)
        eigenerName = ""
        guard !name.isEmpty else { return }
        hinzufuegen(.eigene(name))
        Haptik.erfolg()
    }
}

/// The silent looping GIF (grey body, working muscle red), name and muscles.
struct UebungDetail: View {
    let uebung: Uebung
    var hinzufuegen: (() -> Void)? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                video
                VStack(alignment: .leading, spacing: 4) {
                    Text(uebung.name).font(.title2.bold())
                    Text(uebung.en.capitalized).font(.subheadline).foregroundStyle(.secondary)
                }
                fakten
                if let hinzufuegen {
                    Button(action: hinzufuegen) {
                        Label("Zum Plan hinzufügen", systemImage: "plus").frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(16)
        }
        .navigationTitle(uebung.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var video: some View {
        if let url = UebungsKatalog.gif(uebung.id) {
            AnimiertesGif(url: url, fuellen: false)
                .aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .background(Color.white)
                .clipShape(.rect(cornerRadius: 20, style: .continuous))
                .accessibilityLabel("Animation: \(uebung.name)")
        }
    }

    private var fakten: some View {
        VStack(spacing: 0) {
            fakt("Zielmuskel", uebung.muskel)
            Divider()
            fakt("Gerät", uebung.geraet)
            if !uebung.neben.isEmpty {
                Divider()
                fakt("Hilft mit", uebung.neben.joined(separator: ", "))
            }
        }
        .padding(.horizontal, 14)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: .rect(cornerRadius: 16, style: .continuous))
    }

    private func fakt(_ titel: String, _ wert: String) -> some View {
        LabeledContent(titel, value: wert).padding(.vertical, 12)
    }
}
