import SwiftUI

/// Doodle-Linien des Snap-Editors als reiner Wert (p66), damit Rückgängig und abgebrochene Striche
/// testbar sind. Punkte sind Bruchteile (0...1) der Inhaltsfläche, wie überall im Editor.
struct SnapDoodle {
    private(set) var linien: [SnapEditor.SnapLinie] = []
    /// Der Strich unter dem Finger, noch nicht fertig.
    private(set) var laufend: [CGPoint] = []

    var kannZurueck: Bool { !linien.isEmpty }

    mutating func punkt(_ ort: CGPoint) { laufend.append(ort) }

    /// Ein einzelner Punkt (Antippen) ist keine Linie.
    mutating func abschliessen(farbe: Color) {
        defer { laufend = [] }
        guard laufend.count > 1 else { return }
        linien.append(SnapEditor.SnapLinie(punkte: laufend, farbe: farbe))
    }

    /// Die Geste wurde abgebrochen (Panel gewechselt, System-Geste): `.onEnded` kommt dann nicht, der
    /// halbe Strich würde sonst am nächsten hängen.
    mutating func abbrechen() { laufend = [] }

    mutating func zurueck() { _ = linien.popLast() }
}
