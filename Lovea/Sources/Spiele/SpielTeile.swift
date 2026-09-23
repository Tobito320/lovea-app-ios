import SwiftUI
import UIKit

/// Everything a game view needs for the running round: both players' moves of this `partie`
/// only (older snapshots are ignored), and who starts. Built fresh on every render.
struct SpielKontext: Sendable {
    let spiel: SpieleModell.Spiel
    let ich: Person
    let partie: Int
    let meinZug: Zug?
    let partnerZug: Zug?

    var partner: Person { ich.partner }
    var mein: [Int] { meinZug?.zuege ?? [] }
    var partnerZuege: [Int] { partnerZug?.zuege ?? [] }
    var zuege: [Person: [Int]] { [ich: mein, partner: partnerZuege] }
    /// The inviter starts even rounds, the other one odd rounds ("Nochmal" swaps).
    var starter: Person { partie % 2 == 0 ? spiel.von : spiel.von.partner }
    var seed: UInt64 { Zufall.seed("\(spiel.id)#\(partie)") }

    @MainActor
    static func aus(_ spiel: SpieleModell.Spiel, ich: Person, modell: SpieleModell) -> SpielKontext {
        let partie = modell.partie(spiel.id)
        let aktuell: (Zug?) -> Zug? = { z in z.flatMap { $0.partie == partie ? $0 : nil } }
        return SpielKontext(spiel: spiel, ich: ich, partie: partie, meinZug: aktuell(modell.zug(spiel.id, ich)), partnerZug: aktuell(modell.zug(spiel.id, ich.partner)))
    }

    /// Appends one move, but only if nothing else was appended since this render (double taps).
    @MainActor
    func setzen(_ wert: Int) {
        let n = mein.count
        SpieleModell.shared.ziehen(spiel.id) { if $0.zuege.count == n { $0.zuege.append(wert) } }
    }

    @MainActor
    func ziehen(_ aendern: (inout Zug) -> Void) {
        SpieleModell.shared.ziehen(spiel.id, aendern)
    }
}

/// Just the head of a figure, round. Used as XO marks and in small places.
struct FigurKopf: View {
    let person: Person
    var groesse: CGFloat = 60
    var zustand: FigurZustand = .ruhig

    var body: some View {
        FigurView(FigurenModell.shared.aussehen(person), zustand: zustand, groesse: groesse * 1.35, animiert: false)
            .frame(width: groesse, height: groesse, alignment: .top)
            .clipShape(Circle())
            .background(Circle().fill(Color.person(person).opacity(0.18)))
            .accessibilityLabel(person.name)
    }
}

/// A synced picture (chat photo, Duell drawing). Loads through `Medien`, retries while the
/// sender is still uploading.
struct SpielBild: View {
    let medienId: String
    @State private var bild: UIImage?

    var body: some View {
        ZStack {
            Rectangle().fill(Color(.tertiarySystemFill))
            if let bild {
                Image(uiImage: bild).resizable().scaledToFill()
            } else {
                ProgressView()
            }
        }
        .clipped()
        .task(id: medienId) {
            guard !medienId.isEmpty else { return }
            for _ in 0..<20 {
                if let url = try? await Medien.holen(medienId), let b = await Bilddatei.laden(url, maxPixel: 800) {
                    bild = b
                    return
                }
                try? await Task.sleep(for: .seconds(2))
                if Task.isCancelled { return }
            }
        }
    }
}

/// A Memory motif: "m:<medienId>" or "s:<FreundschaftsSticker>".
struct MotivView: View {
    let motiv: String

    var body: some View {
        let wert = String(motiv.dropFirst(2))
        if motiv.hasPrefix("m:") {
            SpielBild(medienId: wert)
        } else if let sticker = FreundschaftsSticker(rawValue: wert) {
            GeometryReader { geo in
                sticker.ansicht(ahmed: FigurenModell.shared.aussehen(.ahmed), annika: FigurenModell.shared.aussehen(.annika))
                    .frame(width: 320, height: 320)
                    .scaleEffect(geo.size.width / 320)
                    .frame(width: geo.size.width, height: geo.size.height)
            }
        } else {
            Color(.tertiarySystemFill)
        }
    }
}

/// Simple confetti rain, about four seconds. Skipped with Reduce Motion.
struct SpielKonfetti: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date()
    @State private var vorbei = false
    @State private var teile = SpielKonfetti.erzeugen()

    private struct Teil {
        let x, tempo, drift, phase, dreh, breite: Double
        let farbe: Color
    }

    private static func erzeugen() -> [Teil] {
        let farben: [Color] = [.loveaRose, .pink, .orange, .yellow, .mint, .purple, .white]
        return (0..<110).map { _ in
            Teil(
                x: .random(in: 0...1), tempo: .random(in: 0.22...0.45), drift: .random(in: 8...28),
                phase: .random(in: 0...(2 * .pi)), dreh: .random(in: -6...6), breite: .random(in: 6...11),
                farbe: farben.randomElement() ?? .loveaRose
            )
        }
    }

    var body: some View {
        Group {
            if !reduceMotion && !vorbei {
                TimelineView(.animation) { kontext in
                    Canvas { g, size in
                        let t = kontext.date.timeIntervalSince(start)
                        for p in teile {
                            let y = -20 + t * p.tempo * size.height * 1.4 - (1 - p.x) * 30
                            guard y > -30, y < size.height + 30 else { continue }
                            var c = g
                            c.translateBy(x: p.x * size.width + sin(t * 2 + p.phase) * p.drift, y: y)
                            c.rotate(by: .radians(t * p.dreh + p.phase))
                            c.opacity = max(0, min(1, 4.2 - t))
                            c.fill(Path(CGRect(x: -p.breite / 2, y: -p.breite / 4, width: p.breite, height: p.breite / 2)), with: .color(p.farbe))
                        }
                    }
                }
                .task {
                    try? await Task.sleep(for: .seconds(4.5))
                    vorbei = true
                }
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

/// Small tally per game type, for the profile ("Die Bilanz steht im Profil").
struct SpieleBilanz: View {
    var body: some View {
        let modell = SpieleModell.shared
        let arten = SpielArt.allCases.filter { (modell.gespielt[$0] ?? 0) > 0 }
        if arten.isEmpty {
            Text("Noch keine Spiele. Starte eins im Chat.").foregroundStyle(.secondary)
        } else {
            ForEach(arten) { art in
                LabeledContent {
                    Text((modell.bilanz[art] ?? SpielPunkte()).text).monospacedDigit()
                } label: {
                    Label("\(art.titel) · \(modell.gespielt[art] ?? 0)×", systemImage: art.symbol)
                }
            }
        }
    }
}
