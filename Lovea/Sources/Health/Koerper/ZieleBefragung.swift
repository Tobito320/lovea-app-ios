import SwiftUI

/// Rechnet aus den Antworten der Befragung die Reihenfolge und die Wochensätze. Regeln wie `zieleRechnen()`
/// in `design/erholung/erholung.html`.
enum ZieleLogik {
    struct Wahl: Identifiable, Sendable {
        let id: String
        let name: String
        let hinweis: String
        let gruppen: [MuskelGruppe]
    }

    static let optionen: [Wahl] = [
        Wahl(id: "po", name: "Po und Beine formen", hinweis: "Po, Beinbeuger, Quadrizeps", gruppen: [.beine, .bauch]),
        Wahl(id: "stark", name: "Stärker werden", hinweis: "Mehr Gewicht bei den Grundübungen", gruppen: [.beine, .ruecken, .brust]),
        Wahl(id: "straff", name: "Straffen", hinweis: "Ganzer Körper, Muskeln halten", gruppen: [.beine, .ruecken, .schulter]),
        Wahl(id: "haltung", name: "Rücken und Haltung", hinweis: "Oberer Rücken, Schulter hinten, Rumpf", gruppen: [.ruecken, .schulter, .bauch]),
    ]

    static let auffuellen: [MuskelGruppe] = [.beine, .ruecken, .schulter, .bauch, .brust]

    /// `prio`: bis zu 5 Gruppen, wichtigste zuerst. `saetze`: alle Gruppen. Die ersten 2 der Prio 12, 14 oder 16
    /// (2, 3, 4+ Tage), der Rest der Prio 10, alle anderen 6.
    static func rechnen(ziele: Set<String>, tageProWoche: Int) -> (prio: [MuskelGruppe], saetze: [MuskelGruppe: Int]) {
        var prio: [MuskelGruppe] = []
        for g in optionen.filter({ ziele.contains($0.id) }).flatMap(\.gruppen) where !prio.contains(g) { prio.append(g) }
        for g in auffuellen where prio.count < 5 && !prio.contains(g) { prio.append(g) }
        prio = Array(prio.prefix(5))
        let hoch = tageProWoche >= 4 ? 16 : tageProWoche == 3 ? 14 : 12
        var saetze: [MuskelGruppe: Int] = [:]
        for g in MuskelGruppe.allCases {
            saetze[g] = prio.firstIndex(of: g).map { $0 < 2 ? hoch : 10 } ?? 6
        }
        return (prio, saetze)
    }

    /// Rang 1 bis 5 in `ziel.prio.<gruppe>`, 0 für Gruppen ohne Rang (überschreibt eine frühere Befragung).
    @MainActor
    static func speichern(prio: [MuskelGruppe], saetze: [MuskelGruppe: Int]) {
        for g in MuskelGruppe.allCases {
            HealthModell.shared.setzeZiel("ziel.prio.\(g.rawValue)", (prio.firstIndex(of: g) ?? -1) + 1)
            HealthModell.shared.setzeZiel("ziel.saetze.\(g.rawValue)", saetze[g] ?? 6)
        }
    }
}

/// Sheet mit 3 Schritten: Ziele, Tage pro Woche, Reihenfolge.
struct ZieleBefragung: View {
    @Environment(\.dismiss) private var dismiss
    @State private var schritt = 0
    @State private var ziele: Set<String> = []
    @State private var tage: Int?

    private var ich: Person { Raum.shared.ich ?? .ahmed }
    private var ergebnis: (prio: [MuskelGruppe], saetze: [MuskelGruppe: Int]) {
        ZieleLogik.rechnen(ziele: ziele, tageProWoche: tage ?? 3)
    }
    private var kannWeiter: Bool { schritt == 0 ? !ziele.isEmpty : schritt == 1 ? tage != nil : true }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Frage \(schritt + 1) von 3").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
            kopf
            inhalt
            Spacer(minLength: 12)
            weiterKnopf
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
        .animation(Feder.schnell, value: schritt)
    }

    @ViewBuilder private var kopf: some View {
        switch schritt {
        case 0: titel("Was willst du im Gym erreichen?", "Mehrere gehen.")
        case 1: titel("Wie oft trainierst du pro Woche?", "Danach richtet sich, wie viele Sätze pro Muskel realistisch sind.")
        default: titel("Das ist deine Reihenfolge", "Daraus rechnet die App deine Satzziele pro Woche. Ändern geht jederzeit.")
        }
    }

    private func titel(_ text: String, _ untertitel: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(text).font(.title2.bold())
            Text(untertitel).font(.subheadline).foregroundStyle(.secondary)
        }
        .padding(.bottom, 8)
    }

    @ViewBuilder private var inhalt: some View {
        switch schritt {
        case 0:
            liste { ForEach(ZieleLogik.optionen) { o in
                zeile(o.name, o.hinweis, an: ziele.contains(o.id)) {
                    if ziele.contains(o.id) { ziele.remove(o.id) } else { ziele.insert(o.id) }
                }
            } }
        case 1:
            liste { ForEach(2...5, id: \.self) { n in
                zeile("\(n)× pro Woche", nil, an: tage == n) { tage = n }
            } }
        default:
            liste { ForEach(Array(ergebnis.prio.enumerated()), id: \.element) { i, g in
                HStack {
                    Text("\(i + 1). \(g.name)").font(.body.weight(.semibold))
                    Spacer()
                    Text("\(ergebnis.saetze[g] ?? 0) Sätze").font(.body.monospacedDigit()).foregroundStyle(.secondary)
                }
                .padding(16)
            } }
        }
    }

    private func liste<V: View>(@ViewBuilder _ zeilen: () -> V) -> some View {
        VStack(spacing: 0) { zeilen() }
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func zeile(_ name: String, _ hinweis: String?, an: Bool, _ tippen: @escaping () -> Void) -> some View {
        Button {
            Haptik.auswahl()
            tippen()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(name).font(.body.weight(.semibold)).foregroundStyle(.primary)
                    if let hinweis { Text(hinweis).font(.footnote).foregroundStyle(.secondary) }
                }
                Spacer()
                Image(systemName: "checkmark").fontWeight(.bold).foregroundStyle(Color.person(ich)).opacity(an ? 1 : 0)
            }
            .padding(16)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(an ? .isSelected : [])
    }

    private var weiterKnopf: some View {
        Button {
            if schritt < 2 {
                schritt += 1
            } else {
                Haptik.erfolg()
                ZieleLogik.speichern(prio: ergebnis.prio, saetze: ergebnis.saetze)
                dismiss()
            }
        } label: {
            Text(schritt < 2 ? "Weiter" : "Ziele speichern")
                .font(.headline).foregroundStyle(Color.personText(ich))
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(Color.person(ich), in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!kannWeiter)
        .opacity(kannWeiter ? 1 : 0.4)
    }
}
