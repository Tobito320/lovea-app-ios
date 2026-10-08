import SwiftUI

/// Text und Sticker auf der Vorschau: ziehen, pinch, drehen, Löschen-x am Auswahlrahmen. Alle
/// Positionen sind Bruchteile (0...1) der Inhaltsfläche, genau wie im Export.

enum SnapElementRechnung {
    static let skalaGrenzen: ClosedRange<CGFloat> = 0.3...4

    /// Alles innerhalb 0...1 (Sticker dürfen bis an den Rand).
    static func imBild(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: min(max(0, x), 1), y: min(max(0, y), 1))
    }
}

/// Dieselbe View für die Live-Vorschau und `SnapUeberlagerung` im Export. `breite` ist die Breite
/// der Inhaltsfläche (Schrift 7 % davon, mal `skala`).
struct SnapTextAnzeige: View {
    let text: SnapEditor.SnapText
    let breite: CGFloat

    var body: some View {
        Text(text.text)
            .font(.system(size: breite * 0.07 * text.skala, weight: .bold))
            .foregroundStyle(text.farbe)
            .shadow(radius: 3)
    }
}

/// Ein Element auf der Vorschau: Inhalt + Gesten + (ausgewählt) Rahmen mit Löschen-x, gedreht und
/// positioniert. Reihenfolge wie im Export: erst Größe (im Inhalt), dann drehen, dann `position`.
struct SnapElementHuelle<Inhalt: View>: View {
    @Binding var x: CGFloat
    @Binding var y: CGFloat
    @Binding var skala: CGFloat
    @Binding var winkel: Double
    let groesse: CGSize
    let ausgewaehlt: Bool
    let begrenzung: (CGFloat, CGFloat) -> CGPoint
    let onAntippen: () -> Void
    let onLoeschen: () -> Void
    @ViewBuilder let inhalt: () -> Inhalt

    @State private var ziehStart: CGPoint?
    @State private var skalaStart: CGFloat?
    @State private var winkelStart: Double?

    var body: some View {
        inhalt()
            .contentShape(Rectangle())
            .onTapGesture(perform: onAntippen)
            .highPriorityGesture(ziehen)
            .simultaneousGesture(MagnifyGesture()
                .onChanged { wert in
                    let start = skalaStart ?? skala
                    skalaStart = start
                    skala = min(max(start * wert.magnification, SnapElementRechnung.skalaGrenzen.lowerBound), SnapElementRechnung.skalaGrenzen.upperBound)
                }
                .onEnded { _ in skalaStart = nil })
            .simultaneousGesture(RotateGesture()
                .onChanged { wert in
                    let start = winkelStart ?? winkel
                    winkelStart = start
                    winkel = start + wert.rotation.degrees
                }
                .onEnded { _ in winkelStart = nil })
            .overlay {
                if ausgewaehlt {
                    Rectangle().strokeBorder(Color.white, lineWidth: 1.5)
                        .allowsHitTesting(false)
                        .overlay(alignment: .topLeading) {
                            Button(action: onLoeschen) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.black)
                                    .frame(width: 26, height: 26)
                                    .background(Color.white, in: Circle())
                            }
                            .offset(x: -13, y: -13)
                            .accessibilityLabel("Löschen")
                        }
                }
            }
            .rotationEffect(.degrees(winkel))
            .position(x: x * groesse.width, y: y * groesse.height)
    }

    /// Im Inhalts-Raum gemessen, nicht lokal: das Element dreht sich mit.
    private var ziehen: some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .named(SnapEditor.inhaltRaum))
            .onChanged { wert in
                if ziehStart == nil {
                    ziehStart = CGPoint(x: x, y: y)
                    if !ausgewaehlt { onAntippen() }
                }
                guard let start = ziehStart, groesse.width > 0, groesse.height > 0 else { return }
                let neu = begrenzung(start.x + wert.translation.width / groesse.width, start.y + wert.translation.height / groesse.height)
                x = neu.x
                y = neu.y
            }
            .onEnded { _ in ziehStart = nil }
    }
}
