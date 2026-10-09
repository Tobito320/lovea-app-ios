import SwiftUI

/// p70 (34): a bouquet as a gift for the other one, with a few words. One op `strauss.schenken`, one
/// gift per day and giver (the op ID carries both, like the cat's stroke in `KatzeLogik`), so a second
/// phone or a replay counts once. The giver gets points; the other one finds a note over the room and
/// can put the bouquet, fresh, into their vase. Optional in the log, an old app skips the op.
enum StraussGeschenkLogik {
    static let art = "strauss.schenken"
    static let punkte = 15
    static let grund = "Strauß verschenkt"
    static let maxZeichen = 120

    struct D: Codable { var tag: String; var strauss: String; var text: String? }

    struct Geschenk: Equatable, Identifiable, Sendable {
        let id: String
        let von: Person
        let tag: String
        let strauss: StraussArt
        let text: String?
    }

    static func opId(tag: String, von: Person) -> String { "strauss-\(tag)-\(von.rawValue)" }

    /// Only a well-formed gift counts: the ID must match day and giver, the bouquet must be one we know.
    static func geschenk(id: String, von: Person, d: D) -> Geschenk? {
        guard id == opId(tag: d.tag, von: von), let strauss = StraussArt(rawValue: d.strauss) else { return nil }
        return Geschenk(id: id, von: von, tag: d.tag, strauss: strauss, text: kurz(d.text))
    }

    static func eintraege(_ gaben: [Geschenk]) -> [PunkteLogik.Eintrag] {
        gaben.map { PunkteLogik.Eintrag(datum: $0.tag, von: $0.von, grund: grund, punkte: punkte) }
    }

    /// The newest gift from the other one that is newer than the one this person took last. The ID starts
    /// with the zero-padded day, so comparing IDs is comparing days; older gifts are not offered afterwards.
    static func offen(_ gaben: [Geschenk], fuer ich: Person, angenommen: String?) -> Geschenk? {
        gaben.filter { $0.von != ich && $0.id > (angenommen ?? "") }.max { $0.id < $1.id }
    }

    /// Trimmed, empty becomes nil, cut at `maxZeichen`.
    static func kurz(_ text: String?) -> String? {
        guard let t = text?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty else { return nil }
        return String(t.prefix(maxZeichen))
    }

    static func op(tag: String, von: Person, strauss: StraussArt, text: String?) -> Op {
        let neu = Op.neu(art, D(tag: tag, strauss: strauss.rawValue, text: kurz(text)), von: von)
        return Op(id: opId(tag: tag, von: von), seq: nil, art: art, von: von, zeit: neu.zeit, d: neu.d)
    }
}

/// The giver's sheet: pick one of the five, add a few words, give. Once a day.
struct StraussSchenkenBlatt: View {
    private let punkte = PunkteModell.shared
    @Environment(\.dismiss) private var dismiss
    @State private var wahl: StraussArt?
    @State private var text = ""

    private var name: String { Raum.shared.ich?.partner.name ?? "dem Schatz" }
    private var heuteSchon: Bool { Raum.shared.ich.map { punkte.straussVerschenkt($0) } ?? false }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(heuteSchon ? "Heute hast du schon einen Strauß verschenkt. Morgen wieder." : "Welcher Strauß soll es für \(name) sein?")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 10)], spacing: 10) {
                        ForEach(StraussArt.allCases) { art in kachel(art) }
                    }
                    TextField("Ein paar Worte dazu", text: $text, axis: .vertical)
                        .lineLimit(2...4)
                        .padding(12)
                        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .onChange(of: text) { _, neu in
                            if neu.count > StraussGeschenkLogik.maxZeichen { text = String(neu.prefix(StraussGeschenkLogik.maxZeichen)) }
                        }
                }
                .padding()
            }
            .navigationTitle("Strauß schenken")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Schließen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Schenken", action: schenken).disabled(wahl == nil || heuteSchon) }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func kachel(_ art: StraussArt) -> some View {
        let an = wahl == art
        return Button {
            Haptik.auswahl()
            wahl = art
        } label: {
            StraussBild(art: art, breite: 76)
                .frame(maxWidth: .infinity)
                .padding(6)
                .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(an ? Color.loveaRose : .clear, lineWidth: 3))
                .frame(minHeight: 44)
        }
        .buttonStyle(.federnd)
        .accessibilityLabel(art.name)
        .accessibilityAddTraits(an ? .isSelected : [])
    }

    private func schenken() {
        guard let wahl, punkte.straussSchenken(wahl, text: text) > 0 else { return }
        Haptik.erfolg()
        FigurenModell.shared.gesteSenden("herz")
        dismiss()
    }
}

/// The receiver's sheet: the bouquet, the words, and the vase.
struct StraussAnnehmenBlatt: View {
    let geschenk: StraussGeschenkLogik.Geschenk
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                StraussBild(art: geschenk.strauss, breite: 180)
                Text("\(geschenk.von.name) schenkt dir einen Strauß")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                if let text = geschenk.text {
                    Text("\u{201E}\(text)\u{201C}")
                        .font(.system(.body, design: .serif))
                        .italic()
                        .multilineTextAlignment(.center)
                }
                Spacer(minLength: 0)
                Button(action: annehmen) {
                    Text("In die Vase stellen")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.loveaRose)
            }
            .padding()
            .navigationTitle("Ein Geschenk")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Später") { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
    }

    private func annehmen() {
        guard let ich = Raum.shared.ich else { return }
        var z = ZimmerStraeusse.von(ich)
        z.annehmen(geschenk.strauss, geschenk: geschenk.id)
        z.sichern()
        Haptik.erfolg()
        dismiss()
    }
}
