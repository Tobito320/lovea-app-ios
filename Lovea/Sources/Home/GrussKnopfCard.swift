import SwiftUI
import UIKit

/// Wann welcher Gruß-Knopf zu sehen ist (Berliner Stunde): "Guten Morgen" 4–9 Uhr einmal am Tag,
/// "Gute Nacht" ab 20 Uhr bis 4 Uhr, mehrmals, aber frühestens 5 Minuten nach dem letzten. Sonst keiner.
enum GrussFenster {
    static let abstand: TimeInterval = 5 * 60

    static func knopf(stunde: Int, jetzt: Date, letzteNacht: Date?, morgenGesendetHeute: Bool) -> String? {
        if (4..<9).contains(stunde) { return morgenGesendetHeute ? nil : "morgen" }
        guard stunde >= 20 || stunde < 4 else { return nil }
        if let letzteNacht, jetzt.timeIntervalSince(letzteNacht) < abstand { return nil }
        return "nacht"
    }
}

/// Z-27.1: "Gute Nacht"/"Guten Morgen" auf Home. Schickt `gruss`, der Partner bekommt eine Mitteilung
/// (server `regeln.js`). Die Figur schläft davon nicht mehr, das macht nur noch `Anwesenheit` automatisch.
struct GrussKnopfCard: View {
    // ponytail: pro Gerät gemerkt, nicht aus den Ops gefaltet; reicht, weil jeder nur sein Handy nutzt.
    @AppStorage("lovea.gruss.letzteNacht") private var letzteNacht: Double = 0
    @AppStorage("lovea.gruss.morgenTag") private var morgenTag = ""
    var body: some View {
        // Jede Minute neu bewerten, damit die Fenster (20 Uhr, 4 Uhr, 9 Uhr, 5-Minuten-Abstand) von selbst greifen.
        TimelineView(.everyMinute) { kontext in
            let jetzt = kontext.date
            if let art = GrussFenster.knopf(
                stunde: Calendar.berlin.component(.hour, from: jetzt), jetzt: jetzt,
                letzteNacht: letzteNacht > 0 ? Date(timeIntervalSince1970: letzteNacht) : nil,
                morgenGesendetHeute: morgenTag == Datum.text(jetzt)
            ) {
                knopf(art)
            }
        }
    }

    private func knopf(_ art: String) -> some View {
        let nacht = art == "nacht"
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            FigurenModell.shared.grussSenden(art)
            let gesendet = Date()
            if nacht { letzteNacht = gesendet.timeIntervalSince1970 } else { morgenTag = Datum.text(gesendet) }
        } label: {
            Label(nacht ? "Gute Nacht" : "Guten Morgen", systemImage: nacht ? "moon.stars.fill" : "sun.max.fill")
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
        .tint(nacht ? .indigo : .orange)
    }
}
