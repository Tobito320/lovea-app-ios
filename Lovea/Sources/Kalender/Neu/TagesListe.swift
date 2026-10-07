import SwiftUI
import TipKit
import UIKit

extension Color {
    /// „Gemeinsam frei": hell `#177A32`, dunkel das System-Grün.
    static let kalenderGruen = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? .systemGreen : UIColor(red: 0x17 / 255, green: 0x7A / 255, blue: 0x32 / 255, alpha: 1)
    })
}

/// Die Zeilen eines Tages, im Blatt unter dem Raster und in der Tagesansicht gleich: Gemeinsam frei,
/// Termine, Treffen, Alltag. Nimmt nur fertige Werte (`daten`, `ich`), damit die Render-Tafel sie
/// ohne Modell zeichnen kann; Tippen und langes Drücken laufen über `aktionen`.
struct TagesListe: View {
    let tag: String
    let daten: KalenderDaten
    let ich: Person?
    var aktionen = TagesAktionen()

    var body: some View {
        let ahmed = Wochenplan.tag(tag, person: Person.ahmed.rawValue, daten: daten)
        let annika = Wochenplan.tag(tag, person: Person.annika.rawValue, daten: daten)
        let termine = AnsichtWerte.tagesTermine(daten, tag: tag)
        let alltag = AnsichtWerte.alltag(daten, tag: tag)
        VStack(alignment: .leading, spacing: 0) {
            freiZeile(TagesWerte.freieZeiten(ahmed + annika))
            trenner
            if !termine.isEmpty { TipView(TerminMehrTip()) }
            ForEach(termine) { termin in
                terminZeile(termin)
                trenner
            }
            if termine.isEmpty {
                Text("Keine Termine")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }
            treffenZeile(daten.treffen.first { $0.datum == tag })
            if !alltag.isEmpty {
                Text("Alltag")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 12)
                    .accessibilityAddTraits(.isHeader)
                ForEach(Array(alltag.enumerated()), id: \.offset) { _, eintrag in
                    alltagZeile(eintrag)
                }
            }
        }
    }

    private var trenner: some View {
        Divider().accessibilityHidden(true)
    }

    private func freiZeile(_ fenster: [TagesFenster]) -> some View {
        Label(TagesWerte.freiText(fenster), systemImage: "sparkles")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(fenster.isEmpty ? AnyShapeStyle(.secondary) : AnyShapeStyle(Color.kalenderGruen))
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
    }

    // MARK: - Termin

    /// Tippen: bearbeiten. Langes Drücken: bearbeiten, zum iPhone-Kalender, löschen.
    private func terminZeile(_ termin: Termin) -> some View {
        Button { aktionen.bearbeiten(termin) } label: {
            HStack(alignment: .top, spacing: 11) {
                Text(AnsichtWerte.zeitSpalte(termin, tag: tag))
                    .font(.subheadline.monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(width: 54, alignment: .leading)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 7) {
                        Circle()
                            .fill(AnsichtWerte.terminPerson(termin).map { Color.person($0) } ?? Color.primary)
                            .frame(width: 6, height: 6)
                            .accessibilityHidden(true)
                        Text(termin.titel).font(.body.weight(.semibold))
                    }
                    Text(AnsichtWerte.terminUnterzeile(termin))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Bearbeiten", systemImage: "pencil") { aktionen.bearbeiten(termin) }
            Button("Zum iPhone-Kalender", systemImage: "calendar.badge.plus") { aktionen.zumIPhone(termin) }
            Button("Löschen", systemImage: "trash", role: .destructive) { aktionen.loeschen(termin) }
        }
        .accessibilityLabel("\(AnsichtWerte.zeitSpalte(termin, tag: tag)),\(termin.titel), \(AnsichtWerte.terminUnterzeile(termin))")
        .accessibilityHint("Bearbeiten. Weitere Aktionen: zum iPhone-Kalender, löschen")
        .accessibilityAction(named: "Zum iPhone-Kalender") { aktionen.zumIPhone(termin) }
        .accessibilityAction(named: "Löschen") { aktionen.loeschen(termin) }
    }

    // MARK: - Treffen

    /// Führt zum Treffen-Tag: ansehen, wenn es eins gibt, sonst planen.
    private func treffenZeile(_ treffen: Treffen?) -> some View {
        Button { aktionen.treffen() } label: {
            HStack(spacing: 11) {
                Text(treffen?.uhrzeit ?? "")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.primary)
                    .frame(width: 54, alignment: .leading)
                Image(systemName: treffen == nil ? "heart" : "heart.fill")
                    .foregroundStyle(Color.loveaRose)
                    .accessibilityHidden(true)
                Text(treffen == nil ? "Treffen planen" : (treffen?.wasMachenWir ?? "Treffen"))
                    .font(.body.weight(treffen == nil ? .regular : .semibold))
                    .foregroundStyle(treffen == nil ? Color.loveaRose : Color.primary)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(treffen == nil ? "Treffen planen" : "Treffen, \(treffen?.wasMachenWir ?? "Treffen")")
    }

    // MARK: - Alltag

    /// Eigene Arbeit: Arbeitszeit ändern. Sonst ein Block mit Ausnahme: Ausnahme ändern.
    /// Langes Drücken (mit Ausnahme): ändern oder zurücknehmen. Alles andere ist nur Text.
    @ViewBuilder
    private func alltagZeile(_ eintrag: AlltagEintrag) -> some View {
        let tippen = alltagAktion(eintrag)
        let zeile = Label(TagesWerte.alltagZeile(name: eintrag.person.name, block: eintrag.block),
                          systemImage: AnsichtWerte.alltagSymbol(eintrag.block))
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: tippen == nil ? 30 : 44, alignment: .leading)
            .contentShape(Rectangle())
        Group {
            if let tippen {
                Button(action: tippen) { zeile }.buttonStyle(.plain)
            } else {
                zeile
            }
        }
        .contextMenu {
            if let ausnahme = eintrag.block.ausnahme {
                Button("Ausnahme ändern", systemImage: "pencil") { aktionen.ausnahme(ausnahme) }
                Button("Ausnahme zurücknehmen", systemImage: "arrow.uturn.backward", role: .destructive) { aktionen.zuruecknehmen(ausnahme) }
            }
        }
    }

    /// Reihenfolge wie `TagesAnsicht.blockKarte`: erst eigene Arbeit mit Muster, dann Ausnahme.
    private func alltagAktion(_ eintrag: AlltagEintrag) -> (() -> Void)? {
        if eintrag.block.typ == "arbeit", eintrag.person == ich {
            return { aktionen.arbeitszeit(eintrag.block) }
        }
        if let ausnahme = eintrag.block.ausnahme {
            return { aktionen.ausnahme(ausnahme) }
        }
        return nil
    }
}
