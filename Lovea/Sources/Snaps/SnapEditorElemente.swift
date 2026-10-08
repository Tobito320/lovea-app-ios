import SwiftUI
import UIKit

/// Text und Sticker auf der Vorschau (CapCut-Bedienung): ziehen, mit zwei Fingern skalieren und
/// drehen, Auswahlrahmen mit Löschen-x (oben links) und Skalier-/Drehgriff (unten rechts). Alle
/// Positionen sind Bruchteile (0...1) der Inhaltsfläche, genau wie im Export.

// MARK: - Reine Rechnung

enum SnapElementRechnung {
    static let skalaGrenzen: ClosedRange<CGFloat> = 0.3...4

    /// Griff in der Ecke: Abstand zur Mitte ändert die Größe, Winkel zur Mitte dreht. `start` ist der
    /// Punkt, an dem der Finger den Griff berührt hat, `aktuell` der jetzige Fingerort.
    static func griff(mitte: CGPoint, start: CGPoint, aktuell: CGPoint, startSkala: CGFloat, startWinkel: Double,
                      grenzen: ClosedRange<CGFloat> = skalaGrenzen) -> (skala: CGFloat, winkel: Double) {
        let anfangsAbstand = hypot(start.x - mitte.x, start.y - mitte.y)
        guard anfangsAbstand > 1 else { return (startSkala, startWinkel) }
        let abstand = hypot(aktuell.x - mitte.x, aktuell.y - mitte.y)
        let skala = min(max(startSkala * abstand / anfangsAbstand, grenzen.lowerBound), grenzen.upperBound)
        let vorher = atan2(start.y - mitte.y, start.x - mitte.x)
        let jetzt = atan2(aktuell.y - mitte.y, aktuell.x - mitte.x)
        return (skala, startWinkel + Double((jetzt - vorher) * 180 / .pi))
    }

    /// Ziehen: Startposition plus Fingerweg, als Bruchteil der Fläche, begrenzt.
    static func verschoben(start: CGPoint, verschiebung: CGSize, groesse: CGSize,
                           begrenzung: (CGFloat, CGFloat) -> CGPoint) -> CGPoint {
        guard groesse.width > 0, groesse.height > 0 else { return start }
        return begrenzung(start.x + verschiebung.width / groesse.width, start.y + verschiebung.height / groesse.height)
    }

    /// Alles innerhalb 0...1 (Sticker dürfen bis an den Rand).
    static func imBild(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: min(max(0, x), 1), y: min(max(0, y), 1))
    }

    /// Dunkle Textfarbe auf heller Fläche und umgekehrt (Stil "Balken").
    static func istHell(_ farbe: Color) -> Bool {
        var rot: CGFloat = 0, gruen: CGFloat = 0, blau: CGFloat = 0, alpha: CGFloat = 0
        guard UIColor(farbe).getRed(&rot, green: &gruen, blue: &blau, alpha: &alpha) else { return true }
        return 0.299 * rot + 0.587 * gruen + 0.114 * blau > 0.6
    }
}

// MARK: - Text-Darstellung (live UND im Export)

enum SnapSchrift: String, CaseIterable, Sendable {
    case fett, rund, serif, mono

    var anzeigename: String {
        switch self {
        case .fett: return "Fett"
        case .rund: return "Rund"
        case .serif: return "Serif"
        case .mono: return "Mono"
        }
    }

    func font(groesse: CGFloat) -> Font {
        switch self {
        case .fett: return .system(size: groesse, weight: .bold)
        case .rund: return .system(size: groesse, weight: .heavy, design: .rounded)
        case .serif: return .system(size: groesse, weight: .bold, design: .serif)
        case .mono: return .system(size: groesse, weight: .semibold, design: .monospaced)
        }
    }
}

enum SnapTextStil: String, CaseIterable, Sendable {
    case schlicht, balken, leuchten

    var anzeigename: String {
        switch self {
        case .schlicht: return "Schlicht"
        case .balken: return "Balken"
        case .leuchten: return "Leuchten"
        }
    }
}

/// Dieselbe View für die Live-Vorschau und für `SnapUeberlagerung` im Export — eine Rechnung,
/// zwei Ausgaben. `breite` ist die Breite der Inhaltsfläche (Schrift 7 % davon, mal `skala`).
struct SnapTextAnzeige: View {
    let text: SnapEditor.SnapText
    let breite: CGFloat

    var body: some View {
        let groesse = breite * 0.07 * text.skala
        stilisiert(groesse: groesse)
    }

    @ViewBuilder private func stilisiert(groesse: CGFloat) -> some View {
        switch text.stil {
        case .schlicht:
            Text(text.text)
                .font(text.schrift.font(groesse: groesse))
                .foregroundStyle(text.farbe)
                .shadow(radius: 3)
        case .balken:
            Text(text.text)
                .font(text.schrift.font(groesse: groesse))
                .foregroundStyle(SnapElementRechnung.istHell(text.farbe) ? Color.black : Color.white)
                .padding(.horizontal, groesse * 0.45)
                .padding(.vertical, groesse * 0.18)
                .background(text.farbe, in: RoundedRectangle(cornerRadius: groesse * 0.35))
        case .leuchten:
            Text(text.text)
                .font(text.schrift.font(groesse: groesse))
                .foregroundStyle(text.farbe)
                .shadow(color: text.farbe.opacity(0.9), radius: groesse * 0.3)
                .shadow(color: text.farbe.opacity(0.6), radius: groesse * 0.12)
        }
    }
}

// MARK: - Bewegen, Skalieren, Drehen

/// Gesten eines Elements: ein Finger zieht, zwei Finger skalieren/drehen, Tippen wählt aus.
/// Nur am Inhalt, nicht am Auswahlrahmen — sonst würde dessen Ziehen den Griff überstimmen.
private struct SnapBewegbar: ViewModifier {
    @Binding var x: CGFloat
    @Binding var y: CGFloat
    @Binding var skala: CGFloat
    @Binding var winkel: Double
    let groesse: CGSize
    let begrenzung: (CGFloat, CGFloat) -> CGPoint
    let onAntippen: () -> Void
    let onBeruehrt: () -> Void

    @State private var ziehStart: CGPoint?
    @State private var skalaStart: CGFloat?
    @State private var winkelStart: Double?

    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .onTapGesture(perform: onAntippen)
            .highPriorityGesture(ziehen)
            .simultaneousGesture(zoomen)
            .simultaneousGesture(drehen)
    }

    private var ziehen: some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .named(SnapEditor.inhaltRaum))
            .onChanged { wert in
                if ziehStart == nil { ziehStart = CGPoint(x: x, y: y); onBeruehrt() }
                let neu = SnapElementRechnung.verschoben(start: ziehStart ?? CGPoint(x: x, y: y), verschiebung: wert.translation,
                                                         groesse: groesse, begrenzung: begrenzung)
                x = neu.x
                y = neu.y
            }
            .onEnded { _ in ziehStart = nil }
    }

    private var zoomen: some Gesture {
        MagnifyGesture()
            .onChanged { wert in
                if skalaStart == nil { skalaStart = skala }
                let start = skalaStart ?? skala
                skala = min(max(start * wert.magnification, SnapElementRechnung.skalaGrenzen.lowerBound), SnapElementRechnung.skalaGrenzen.upperBound)
            }
            .onEnded { _ in skalaStart = nil }
    }

    private var drehen: some Gesture {
        RotateGesture()
            .onChanged { wert in
                if winkelStart == nil { winkelStart = winkel }
                winkel = (winkelStart ?? winkel) + wert.rotation.degrees
            }
            .onEnded { _ in winkelStart = nil }
    }
}

/// Weißer Rahmen, Löschen-x oben links, Skalier-/Drehgriff unten rechts (wie CapCut).
private struct SnapAuswahlRahmen: View {
    let mitte: CGPoint
    @Binding var skala: CGFloat
    @Binding var winkel: Double
    let onLoeschen: () -> Void

    private struct GriffStart { var punkt: CGPoint; var skala: CGFloat; var winkel: Double }
    @State private var griffStart: GriffStart?

    var body: some View {
        Rectangle()
            .strokeBorder(Color.white, lineWidth: 1.5)
            .allowsHitTesting(false)
            .overlay(alignment: .topLeading) { loeschen.offset(x: -13, y: -13) }
            .overlay(alignment: .bottomTrailing) { griff.offset(x: 13, y: 13) }
    }

    private var loeschen: some View {
        Button(action: onLoeschen) {
            Image(systemName: "xmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.black)
                .frame(width: 26, height: 26)
                .background(Color.white, in: Circle())
        }
        .accessibilityLabel("Löschen")
    }

    private var griff: some View {
        Image(systemName: "arrow.up.left.and.arrow.down.right")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(.black)
            .frame(width: 26, height: 26)
            .background(Color.white, in: Circle())
            .contentShape(Circle())
            .highPriorityGesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named(SnapEditor.inhaltRaum))
                    .onChanged { wert in
                        if griffStart == nil { griffStart = GriffStart(punkt: wert.startLocation, skala: skala, winkel: winkel) }
                        guard let start = griffStart else { return }
                        let neu = SnapElementRechnung.griff(mitte: mitte, start: start.punkt, aktuell: wert.location,
                                                            startSkala: start.skala, startWinkel: start.winkel)
                        skala = neu.skala
                        winkel = neu.winkel
                    }
                    .onEnded { _ in griffStart = nil }
            )
            .accessibilityLabel("Größe und Drehung")
    }
}

/// Ein Element auf der Vorschau: Inhalt + Gesten + (ausgewählt) Rahmen, gedreht und positioniert.
/// Reihenfolge wie im Export: erst Größe (im Inhalt), dann drehen, dann `position`.
struct SnapElementHuelle<Inhalt: View>: View {
    @Binding var x: CGFloat
    @Binding var y: CGFloat
    @Binding var skala: CGFloat
    @Binding var winkel: Double
    let groesse: CGSize
    let ausgewaehlt: Bool
    let begrenzung: (CGFloat, CGFloat) -> CGPoint
    let onAntippen: () -> Void
    let onBeruehrt: () -> Void
    let onLoeschen: () -> Void
    @ViewBuilder let inhalt: () -> Inhalt

    var body: some View {
        inhalt()
            .modifier(SnapBewegbar(x: $x, y: $y, skala: $skala, winkel: $winkel, groesse: groesse,
                                   begrenzung: begrenzung, onAntippen: onAntippen, onBeruehrt: onBeruehrt))
            .overlay {
                if ausgewaehlt {
                    SnapAuswahlRahmen(mitte: CGPoint(x: x * groesse.width, y: y * groesse.height),
                                      skala: $skala, winkel: $winkel, onLoeschen: onLoeschen)
                }
            }
            .rotationEffect(.degrees(winkel))
            .position(x: x * groesse.width, y: y * groesse.height)
    }
}
