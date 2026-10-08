import SwiftUI

/// p70 (38): furnishing together. When the other one changes their room or their bouquets while you
/// look at the panorama, a small note says so for a few seconds. No extra sync: it compares the
/// partner's synced settings (`EinstellungenModell.werte`), so it works with what is already there.
enum ZimmerHinweisLogik {
    /// The settings that put something into the room.
    static let schluessel = ["profil.raeume", ZimmerStraeusse.schluessel]

    /// A string that changes exactly when one of those values changes; empty without any.
    static func fingerabdruck(_ werte: [String: JSONValue]?) -> String {
        guard let werte else { return "" }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return schluessel.map { key in
            werte[key].flatMap { try? encoder.encode($0) }.flatMap { String(data: $0, encoding: .utf8) } ?? "-"
        }.joined(separator: "|")
    }

    /// Seconds after the view appeared during which changes are still the log being replayed.
    static let einlaufSekunden: Double = 8
    static let sichtbarSekunden: Double = 5

    static func text(partner: Person) -> String { "\(partner.name) hat etwas gestellt" }
}

/// The notes at the bottom of the panorama: a gift waiting in the vase, and the live hint. Both are
/// glass capsules; nothing runs in the background but one short sleep per hint.
struct ZimmerHinweisLeiste: View {
    private let einstellungen = EinstellungenModell.shared
    private let punkte = PunkteModell.shared
    @State private var scharf = false
    @State private var live = false
    @State private var geschenkBlatt: StraussGeschenkLogik.Geschenk?

    var body: some View {
        let ich = Raum.shared.ich
        let partner = ich?.partner
        let abdruck = ZimmerHinweisLogik.fingerabdruck(partner.flatMap { einstellungen.werte[$0] })
        let geschenk = ich.flatMap { punkte.straussGeschenkOffen(fuer: $0, angenommen: ZimmerStraeusse.von($0).angenommen) }
        VStack(spacing: 6) {
            if let geschenk {
                Button {
                    Haptik.leicht()
                    geschenkBlatt = geschenk
                } label: {
                    kapsel("\(geschenk.von.name) schenkt dir einen Strauß", symbol: "gift.fill")
                }
                .buttonStyle(.plain)
                .accessibilityHint("Öffnet das Geschenk")
            }
            if live, let partner {
                kapsel(ZimmerHinweisLogik.text(partner: partner), symbol: "sparkles")
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .padding(.bottom, 8)
        .onChange(of: abdruck) { _, _ in
            guard scharf else { return }
            withAnimation(Feder.weich) { live = true }
        }
        .task {
            try? await Task.sleep(for: .seconds(ZimmerHinweisLogik.einlaufSekunden))
            scharf = true
            stempeln()
        }
        .task(id: live) {
            guard live else { return }
            try? await Task.sleep(for: .seconds(ZimmerHinweisLogik.sichtbarSekunden))
            withAnimation(Feder.weich) { live = false }
        }
        .sheet(item: $geschenkBlatt) { StraussAnnehmenBlatt(geschenk: $0) }
    }

    /// Bouquets from before p70 have no date: they start getting older from the first look, once the log is in.
    private func stempeln() {
        guard Raum.shared.verbunden, let ich = Raum.shared.ich else { return }
        var z = ZimmerStraeusse.von(ich)
        if z.stempelnFallsFehlt() { z.sichern() }
    }

    private func kapsel(_ text: String, symbol: String) -> some View {
        Label(text, systemImage: symbol)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Color.primary)
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .background(.ultraThinMaterial, in: Capsule())
            .contentShape(Capsule())
    }
}
