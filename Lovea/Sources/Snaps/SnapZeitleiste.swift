import AVFoundation
import SwiftUI
import UIKit

/// CapCut-Zeitleiste des Snap-Editors: Filmstreifen aus Thumbnails, feste Abspiel-Linie in der
/// Mitte, der Streifen läuft darunter durch. Die Rechnung ist rein und getestet.

enum SnapZeitleisteRechnung {
    /// Breite einer Sekunde Video auf der Zeitleiste.
    static let punkteProSekunde: CGFloat = 56

    static func x(zeit: Double) -> CGFloat { CGFloat(max(zeit, 0)) * punkteProSekunde }

    /// Den Streifen nach rechts ziehen = zurück in der Zeit (wie CapCut).
    static func zeit(start: Double, verschiebung: CGFloat, dauer: Double) -> Double {
        min(max(start - Double(verschiebung / punkteProSekunde), 0), max(dauer, 0))
    }

    /// Linker Griff: neuer Anfang, nie hinter `ende - Mindestdauer`, nie vor 0.
    static func anfang(start: Double, verschiebung: CGFloat, plan: SnapSchnitt) -> Double {
        min(max(start + Double(verschiebung / punkteProSekunde), 0), max(plan.ende - SnapSchnitt.mindestdauer, 0))
    }

    /// Rechter Griff: neues Ende, nie vor `anfang + Mindestdauer`, nie hinter der Videolänge.
    static func ende(start: Double, verschiebung: CGFloat, plan: SnapSchnitt) -> Double {
        max(min(start + Double(verschiebung / punkteProSekunde), plan.dauer), min(plan.anfang + SnapSchnitt.mindestdauer, plan.dauer))
    }

    /// Wiedergabe außerhalb der bleibenden Teile springt zum nächsten bleibenden Teil, hinter dem
    /// letzten zurück an den Anfang (Schleife). `nil` = alles in Ordnung.
    static func sprungZiel(plan: SnapSchnitt, zeit: Double) -> Double? {
        let teile = plan.behalten
        guard let erster = teile.first else { return nil }
        if teile.contains(where: { zeit >= $0.von && zeit < $0.bis }) { return nil }
        return teile.first(where: { $0.von > zeit })?.von ?? erster.von
    }

    /// Abgedunkelte Stücke des Streifens: vor dem Anfang, nach dem Ende, entfernte Teile.
    static func luecken(plan: SnapSchnitt) -> [SnapSchnitt.Bereich] {
        var liste: [SnapSchnitt.Bereich] = []
        if plan.anfang > 0 { liste.append(SnapSchnitt.Bereich(von: 0, bis: plan.anfang)) }
        if plan.ende < plan.dauer { liste.append(SnapSchnitt.Bereich(von: plan.ende, bis: plan.dauer)) }
        return liste + plan.entfernt
    }
}

/// Thumbnails für den Filmstreifen: einmal pro Video, gleichmäßig über die Länge verteilt.
enum SnapFilmbilder {
    static func anzahl(dauer: Double) -> Int { min(max(Int(dauer.rounded(.up)), 1), 40) }

    @MainActor
    static func laden(url: URL, dauer: Double) async -> [UIImage] {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 160, height: 160)
        let n = anzahl(dauer: dauer)
        var bilder: [UIImage] = []
        for index in 0..<n where !Task.isCancelled {
            let zeit = CMTime(seconds: dauer * (Double(index) + 0.5) / Double(n), preferredTimescale: 600)
            if let ergebnis = try? await generator.image(at: zeit) { bilder.append(UIImage(cgImage: ergebnis.image)) }
        }
        return bilder
    }
}

/// Der Filmstreifen: Thumbnails, abgedunkelte Lücken, im markierten Zustand weißer Rahmen mit
/// Griffen zum Trimmen. Die Griffe melden den Vorschlag; `SnapSchnitt.kuerzen` entscheidet.
struct SnapFilmstreifen: View {
    let bilder: [UIImage]
    let plan: SnapSchnitt
    let ausgewaehlt: Bool
    let onKuerzen: (_ anfang: Double, _ ende: Double) -> Void

    @State private var griffStart: Double?

    static let hoehe: CGFloat = 52
    private static let griffBreite: CGFloat = 18

    var body: some View {
        let breite = SnapZeitleisteRechnung.x(zeit: plan.dauer)
        HStack(spacing: 0) {
            ForEach(bilder.indices, id: \.self) { index in
                Image(uiImage: bilder[index]).resizable().scaledToFill()
                    .frame(width: breite / CGFloat(bilder.count), height: Self.hoehe).clipped()
            }
        }
        .frame(width: breite, height: Self.hoehe, alignment: .leading)
        .background(Color(white: 0.2))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(alignment: .leading) {
            ForEach(Array(SnapZeitleisteRechnung.luecken(plan: plan).enumerated()), id: \.offset) { _, bereich in
                Color.black.opacity(0.65)
                    .frame(width: SnapZeitleisteRechnung.x(zeit: bereich.laenge))
                    .offset(x: SnapZeitleisteRechnung.x(zeit: bereich.von))
            }
            .allowsHitTesting(false)
        }
        .overlay(alignment: .leading) { if ausgewaehlt { rahmen } }
    }

    private var rahmen: some View {
        let von = SnapZeitleisteRechnung.x(zeit: plan.anfang)
        let bis = SnapZeitleisteRechnung.x(zeit: plan.ende)
        return ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 6).strokeBorder(Color.white, lineWidth: 2)
                .frame(width: max(bis - von, 2))
                .offset(x: von)
                .allowsHitTesting(false)
            griff(links: true).offset(x: von)
            griff(links: false).offset(x: bis - Self.griffBreite)
        }
    }

    private func griff(links: Bool) -> some View {
        RoundedRectangle(cornerRadius: 4).fill(Color.white)
            .frame(width: Self.griffBreite, height: Self.hoehe)
            .overlay(Image(systemName: links ? "chevron.compact.left" : "chevron.compact.right")
                .font(.system(size: 16, weight: .bold)).foregroundStyle(.black))
            .contentShape(Rectangle())
            .highPriorityGesture(
                // `.global`: der Griff wandert beim Ziehen mit, lokal würde die Strecke zurückspringen.
                DragGesture(minimumDistance: 1, coordinateSpace: .global)
                    .onChanged { wert in
                        let start = griffStart ?? (links ? plan.anfang : plan.ende)
                        griffStart = start
                        if links {
                            onKuerzen(SnapZeitleisteRechnung.anfang(start: start, verschiebung: wert.translation.width, plan: plan), plan.ende)
                        } else {
                            onKuerzen(plan.anfang, SnapZeitleisteRechnung.ende(start: start, verschiebung: wert.translation.width, plan: plan))
                        }
                    }
                    .onEnded { _ in griffStart = nil }
            )
            .accessibilityLabel(links ? "Anfang kürzen" : "Ende kürzen")
    }
}
