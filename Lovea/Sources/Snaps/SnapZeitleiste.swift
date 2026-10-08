import AVFoundation
import SwiftUI
import UIKit

/// CapCut-Zeitleiste des Snap-Editors: Filmstreifen aus Thumbnails, feste Abspiel-Linie in der
/// Mitte, der Streifen läuft darunter durch. Die Rechnung (Zeit <-> Position, Trim-Grenzen,
/// Abspiel-Sprünge) ist rein und getestet; die Views darunter halten keinen eigenen Zustand außer
/// dem Startwert eines Griff-Zugs.

enum SnapZeitleisteRechnung {
    /// Breite einer Sekunde Video auf der Zeitleiste.
    static let punkteProSekunde: CGFloat = 56

    static func x(zeit: Double) -> CGFloat { CGFloat(max(zeit, 0)) * punkteProSekunde }

    static func breite(dauer: Double) -> CGFloat { x(zeit: dauer) }

    /// Position auf dem Streifen -> Zeit, begrenzt auf 0...dauer.
    static func zeit(x: CGFloat, dauer: Double) -> Double {
        min(max(Double(x / punkteProSekunde), 0), max(dauer, 0))
    }

    /// Streifen unter der festen Mitte-Linie: bei `zeit` liegt dieser Punkt genau unter `mitte`.
    static func versatz(zeit: Double, mitte: CGFloat) -> CGFloat { mitte - x(zeit: zeit) }

    /// Den Streifen nach rechts ziehen = zurück in der Zeit (wie CapCut).
    static func zeit(start: Double, verschiebung: CGFloat, dauer: Double) -> Double {
        min(max(start - Double(verschiebung / punkteProSekunde), 0), max(dauer, 0))
    }

    /// Linker Griff: neuer Anfang, nie hinter `ende - Mindestdauer`, nie vor 0.
    static func anfang(start: Double, verschiebung: CGFloat, plan: SnapSchnitt) -> Double {
        let neu = start + Double(verschiebung / punkteProSekunde)
        return min(max(neu, 0), max(plan.ende - SnapSchnitt.mindestdauer, 0))
    }

    /// Rechter Griff: neues Ende, nie vor `anfang + Mindestdauer`, nie hinter der Videolänge.
    static func ende(start: Double, verschiebung: CGFloat, plan: SnapSchnitt) -> Double {
        let neu = start + Double(verschiebung / punkteProSekunde)
        return max(min(neu, plan.dauer), min(plan.anfang + SnapSchnitt.mindestdauer, plan.dauer))
    }

    /// "0:03 / 0:12"
    static func anzeige(zeit: Double, dauer: Double) -> String {
        SnapSchnitt.zeit(zeit) + " / " + SnapSchnitt.zeit(dauer)
    }

    /// Wiedergabe außerhalb der bleibenden Teile (gekürzt oder entfernt) springt zum nächsten
    /// bleibenden Teil, hinter dem letzten zurück an den Anfang (Schleife). `nil` = alles in Ordnung.
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
        liste.append(contentsOf: plan.entfernt)
        return liste
    }
}

/// Thumbnails für den Filmstreifen: einmal pro Video, gleichmäßig über die Länge verteilt.
enum SnapFilmbilder {
    static func anzahl(dauer: Double) -> Int { min(max(Int((dauer).rounded(.up)), 1), 40) }

    @MainActor
    static func laden(url: URL, dauer: Double) async -> [UIImage] {
        guard dauer > 0 else { return [] }
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 160, height: 160)
        let n = anzahl(dauer: dauer)
        var bilder: [UIImage] = []
        for index in 0..<n {
            if Task.isCancelled { break }
            let sekunde = dauer * (Double(index) + 0.5) / Double(n)
            if let ergebnis = try? await generator.image(at: CMTime(seconds: sekunde, preferredTimescale: 600)) {
                bilder.append(UIImage(cgImage: ergebnis.image))
            } else if let letztes = bilder.last {
                bilder.append(letztes)
            }
        }
        return bilder
    }
}

/// Der Filmstreifen selbst: Thumbnails, abgedunkelte Lücken, im markierten Zustand weißer Rahmen
/// mit Griffen links/rechts zum Trimmen. Die Griffe melden den vorgeschlagenen Bereich;
/// `SnapSchnitt.kuerzen` im Editor entscheidet, ob er gilt.
struct SnapFilmstreifen: View {
    let bilder: [UIImage]
    let plan: SnapSchnitt
    let ausgewaehlt: Bool
    let onKuerzen: (_ anfang: Double, _ ende: Double) -> Void

    @State private var anfangStart: Double?
    @State private var endeStart: Double?

    static let hoehe: CGFloat = 52
    private static let griffBreite: CGFloat = 18

    private var gesamtBreite: CGFloat { SnapZeitleisteRechnung.breite(dauer: plan.dauer) }

    var body: some View {
        ZStack(alignment: .leading) {
            streifen
            abdunkelung
            if ausgewaehlt { rahmen }
        }
        .frame(width: gesamtBreite, height: Self.hoehe, alignment: .leading)
    }

    private var streifen: some View {
        let kachelBreite = gesamtBreite / CGFloat(max(bilder.count, 1))
        return HStack(spacing: 0) {
            ForEach(bilder.indices, id: \.self) { index in
                Image(uiImage: bilder[index])
                    .resizable()
                    .scaledToFill()
                    .frame(width: kachelBreite, height: Self.hoehe)
                    .clipped()
            }
        }
        .frame(width: gesamtBreite, height: Self.hoehe, alignment: .leading)
        .background(Color(white: 0.2))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var abdunkelung: some View {
        let luecken = SnapZeitleisteRechnung.luecken(plan: plan)
        return ZStack(alignment: .leading) {
            ForEach(Array(luecken.enumerated()), id: \.offset) { _, bereich in
                Color.black.opacity(0.65)
                    .frame(width: SnapZeitleisteRechnung.x(zeit: bereich.laenge), height: Self.hoehe)
                    .offset(x: SnapZeitleisteRechnung.x(zeit: bereich.von))
            }
        }
        .frame(width: gesamtBreite, height: Self.hoehe, alignment: .leading)
        .allowsHitTesting(false)
    }

    private var rahmen: some View {
        let von = SnapZeitleisteRechnung.x(zeit: plan.anfang)
        let bis = SnapZeitleisteRechnung.x(zeit: plan.ende)
        return ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(Color.white, lineWidth: 2)
                .frame(width: max(bis - von, 2), height: Self.hoehe)
                .offset(x: von)
                .allowsHitTesting(false)
            griff(links: true).offset(x: von)
            griff(links: false).offset(x: bis - Self.griffBreite)
        }
        .frame(width: gesamtBreite, height: Self.hoehe, alignment: .leading)
    }

    private func griff(links: Bool) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color.white)
            .frame(width: Self.griffBreite, height: Self.hoehe)
            .overlay(Image(systemName: links ? "chevron.compact.left" : "chevron.compact.right")
                .font(.system(size: 16, weight: .bold)).foregroundStyle(.black))
            .contentShape(Rectangle())
            .highPriorityGesture(griffGeste(links: links))
            .accessibilityLabel(links ? "Anfang kürzen" : "Ende kürzen")
    }

    // `.global`: der Griff wandert beim Ziehen mit, im lokalen Raum würde die Strecke zurückspringen.
    private func griffGeste(links: Bool) -> some Gesture {
        DragGesture(minimumDistance: 1, coordinateSpace: .global)
            .onChanged { wert in
                if links {
                    if anfangStart == nil { anfangStart = plan.anfang }
                    onKuerzen(SnapZeitleisteRechnung.anfang(start: anfangStart ?? plan.anfang, verschiebung: wert.translation.width, plan: plan), plan.ende)
                } else {
                    if endeStart == nil { endeStart = plan.ende }
                    onKuerzen(plan.anfang, SnapZeitleisteRechnung.ende(start: endeStart ?? plan.ende, verschiebung: wert.translation.width, plan: plan))
                }
            }
            .onEnded { _ in anfangStart = nil; endeStart = nil }
    }
}

/// Farbiger Balken einer Spur (Text/Sticker) unter dem Clip. Ohne eigene Zeiten im Datenmodell
/// gilt das Element für den ganzen (bleibenden) Clip, der Balken zeigt das nur an.
struct SnapSpurBalken: View {
    let titel: String
    let farbe: Color
    let gewaehlt: Bool
    let von: CGFloat
    let breite: CGFloat
    let gesamtBreite: CGFloat
    let onAntippen: () -> Void

    var body: some View {
        ZStack(alignment: .leading) {
            Text(titel)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .padding(.horizontal, 8)
                .frame(width: max(breite, 2), height: 22, alignment: .leading)
                .background(farbe.opacity(gewaehlt ? 1 : 0.7), in: RoundedRectangle(cornerRadius: 5))
                .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Color.white, lineWidth: gewaehlt ? 2 : 0))
                .offset(x: von)
                .onTapGesture(perform: onAntippen)
        }
        .frame(width: gesamtBreite, height: 22, alignment: .leading)
    }
}
