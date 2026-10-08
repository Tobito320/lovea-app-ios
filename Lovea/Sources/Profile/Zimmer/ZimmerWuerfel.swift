import SwiftUI
import UIKit

/// p63: der Date-Würfel auf dem Tisch. Wurf = reine Logik; "Übernehmen" legt die Idee über den
/// bestehenden Weg (`DateSpeicher.anlegen`) in den Date-Ideen an.
enum WuerfelGruppe: String, CaseIterable, Sendable {
    case drinnen, draussen, guenstig, besonders

    var titel: String {
        switch self {
        case .drinnen: "Drinnen"
        case .draussen: "Draußen"
        case .guenstig: "Günstig"
        case .besonders: "Besonders"
        }
    }

    /// In welche Kategorie der Date-Ideen die Idee beim Übernehmen kommt.
    var kategorie: DateKategorie {
        switch self {
        case .drinnen: .zuhause
        case .draussen: .draussen
        case .guenstig: .aktivitaet
        case .besonders: .besonders
        }
    }

    var ideen: [String] {
        switch self {
        case .drinnen: [
            "Zusammen kochen, ohne Rezept", "Filmabend mit Decken und Popcorn", "Brettspiel-Turnier mit Einsatz",
            "Gemeinsam ein Puzzle legen", "Alte Fotos anschauen", "Pizza selber belegen",
        ]
        case .draussen: [
            "Sonnenuntergang auf einem Hügel", "Picknick im Park", "Fahrradtour ohne Ziel",
            "Spaziergang mit Eis", "Sterne gucken", "Im Regen spazieren gehen",
        ]
        case .guenstig: [
            "Flohmarkt bummeln", "Kaffee to go auf der Parkbank", "Schatzsuche in der Stadt",
            "Gemeinsam Kekse backen", "Buch füreinander aussuchen", "Fotospaziergang mit dem Handy",
        ]
        case .besonders: [
            "Abend im Restaurant mit Menü", "Spontaner Tagesausflug", "Konzert oder Theater",
            "Wellness-Tag zu zweit", "Fotoshooting zu zweit", "Wochenende wegfahren",
        ]
        }
    }
}

struct WuerfelWurf: Equatable, Sendable {
    let gruppe: WuerfelGruppe
    let text: String
}

enum ZimmerWuerfel {
    /// Ein Wurf aus einer Gruppe (`nil`: alle). `zahl` bestimmt das Ergebnis (im Spiel: Zufall), so ist es testbar.
    /// `ausser`: der letzte Wurf, er kommt nicht gleich noch einmal.
    static func wurf(_ gruppe: WuerfelGruppe?, zahl: Int, ausser: String? = nil) -> WuerfelWurf {
        let alle = WuerfelGruppe.allCases
        let g = gruppe ?? alle[zahl % alle.count]
        let ideen = g.ideen
        var i = (gruppe == nil ? zahl / alle.count : zahl) % ideen.count
        if ideen[i] == ausser { i = (i + 1) % ideen.count }
        return WuerfelWurf(gruppe: g, text: ideen[i])
    }

    /// Die Augenzahl, die der Würfel nach dem Wurf zeigt: 1 bis 6.
    static func augen(zahl: Int) -> Int { zahl % 6 + 1 }

    /// Legt die Idee an. `false`: gibt es schon (gleicher Titel, ohne Groß- und Kleinschreibung) oder kein Konto.
    @MainActor @discardableResult
    static func uebernehmen(_ w: WuerfelWurf, in speicher: DateSpeicher = .shared) -> Bool {
        let name = DateLogik.falten(w.text)
        guard !speicher.ideen.contains(where: { DateLogik.falten($0.titel) == name }) else { return false }
        return speicher.anlegen(titel: w.text, kategorie: w.gruppe.kategorie) != nil
    }
}

// MARK: - Zeichnung

enum ZimmerWuerfelZeichnung {
    /// Platz auf dem Tisch, rechts von der Vase.
    static let ort = CGPoint(x: ZuhauseZeichnung.tisch.x + 19, y: ZuhauseZeichnung.tisch.y - 3)
    static let kante: CGFloat = 12

    /// Ein Würfel von schräg oben: Vorderseite mit den Augen, Oberseite hell, rechte Seite dunkel.
    static func zeichne(_ g: GraphicsContext, mitte m: CGPoint, kante k: CGFloat, augen: Int, drehung: CGFloat = 0) {
        let weiss = Pal.weiss
        let h = k / 2
        let d = k * 0.34
        g.fill(oval(P(m.x + 2, m.y + h + 1), k * 0.8, 2.6), with: .color(.black.opacity(0.14)))
        var w = g
        w.translateBy(x: m.x, y: m.y)
        w.rotate(by: .radians(Double(drehung)))
        let vorn = box(-h, -h, k, k, 2.6)
        let oben = Path { p in
            p.move(to: P(-h, -h))
            p.addLine(to: P(-h + d, -h - d))
            p.addLine(to: P(h + d, -h - d))
            p.addLine(to: P(h, -h))
            p.closeSubpath()
        }
        let rechts = Path { p in
            p.move(to: P(h, -h))
            p.addLine(to: P(h + d, -h - d))
            p.addLine(to: P(h + d, h - d))
            p.addLine(to: P(h, h))
            p.closeSubpath()
        }
        teil(w, rechts, weiss.mal(0.86), 1.4)
        teil(w, oben, weiss.mal(0.96), 1.4)
        teil(w, vorn, weiss, 1.6)
        for (x, y) in punkte(augen) {
            w.fill(kreis(P(x * k * 0.27, y * k * 0.27), k * 0.075), with: .color(Pal.rose.farbe))
        }
    }

    /// Lage der Augen auf einem 3x3-Raster (-1, 0, 1).
    static func punkte(_ n: Int) -> [(CGFloat, CGFloat)] {
        switch n {
        case 1: [(0, 0)]
        case 2: [(-1, -1), (1, 1)]
        case 3: [(-1, -1), (0, 0), (1, 1)]
        case 4: [(-1, -1), (1, -1), (-1, 1), (1, 1)]
        case 5: [(-1, -1), (1, -1), (0, 0), (-1, 1), (1, 1)]
        default: [(-1, -1), (1, -1), (-1, 0), (1, 0), (-1, 1), (1, 1)]
        }
    }
}

// MARK: - Blatt

/// Das Blatt, das beim Tippen auf den Würfel aufgeht: würfeln, Gruppe wählen, übernehmen.
struct ZimmerWuerfelBlatt: View {
    @State private var gruppe: WuerfelGruppe?
    @State private var wurf: WuerfelWurf?
    @State private var augen = 5
    @State private var drehungen = 0
    @State private var drin = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 18) {
            Text("Date-Würfel").font(.headline).padding(.top, 20)
            Picker("Gruppe", selection: $gruppe) {
                Text("Alle").tag(WuerfelGruppe?.none)
                ForEach(WuerfelGruppe.allCases, id: \.self) { Text($0.titel).tag(WuerfelGruppe?.some($0)) }
            }
            .pickerStyle(.segmented)
            Canvas { g, groesse in
                ZimmerWuerfelZeichnung.zeichne(g, mitte: CGPoint(x: groesse.width / 2, y: groesse.height / 2 + 6), kante: 58, augen: augen)
            }
            .frame(height: 96)
            .rotationEffect(.degrees(Double(drehungen) * 360))
            .accessibilityHidden(true)
            Group {
                if let wurf {
                    VStack(spacing: 6) {
                        Text(wurf.gruppe.titel).font(.caption.weight(.semibold)).foregroundStyle(Color.loveaRose)
                        Text(wurf.text).font(.title3.weight(.semibold)).multilineTextAlignment(.center)
                    }
                } else {
                    Text("Tipp auf Würfeln").foregroundStyle(.secondary)
                }
            }
            .frame(minHeight: 64)
            HStack(spacing: 12) {
                Button { wuerfeln() } label: { Label("Würfeln", systemImage: "die.face.5").frame(maxWidth: .infinity) }
                    .buttonStyle(.bordered)
                Button { uebernehmen() } label: {
                    Label(drin ? "Steht drin" : "Übernehmen", systemImage: drin ? "checkmark" : "plus").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(wurf == nil || drin)
            }
            .controlSize(.large)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .presentationDetents([.medium])
        .onChange(of: gruppe) { wurf = nil; drin = false }
    }

    private func wuerfeln() {
        let zahl = Int.random(in: 0..<10_000)
        augen = ZimmerWuerfel.augen(zahl: zahl)
        wurf = ZimmerWuerfel.wurf(gruppe, zahl: zahl, ausser: wurf?.text)
        drin = false
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        guard !reduceMotion, !ProcessInfo.processInfo.isLowPowerModeEnabled else { return }
        withAnimation(.easeOut(duration: 0.5)) { drehungen += 1 }
    }

    private func uebernehmen() {
        guard let wurf else { return }
        drin = true
        if ZimmerWuerfel.uebernehmen(wurf) { dismiss() }
    }
}
