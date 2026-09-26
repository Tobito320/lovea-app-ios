import CoreHaptics
import SwiftUI
import UIKit

extension View {
    /// Tap opens a small menu (Anstupsen, Kuss, the Runde-3 expressions); long press sends "herz".
    /// `onGeste` gets "anstupsen", "kuss", "herz" or a `FigurZustand.mimik` raw value; the caller sends the `geste` op.
    func figurGesten(person: Person, onGeste: @escaping (String) -> Void) -> some View {
        modifier(FigurGesten(person: person, onGeste: onGeste))
    }
}

private struct FigurGesten: ViewModifier {
    let person: Person
    let onGeste: (String) -> Void
    @State private var menu = false
    @State private var gesendet = 0

    func body(content: Content) -> some View {
        content
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
            .onTapGesture { menu = true }
            .onLongPressGesture(minimumDuration: 0.5) { senden("herz") }
            .sensoryFeedback(.impact(weight: .medium), trigger: gesendet)
            .popover(isPresented: $menu) {
                VStack(spacing: 0) {
                    knopf("\(person.name) anstupsen", symbol: "hand.tap", art: "anstupsen")
                    Divider()
                    knopf("Kuss schicken", symbol: "mouth", art: "kuss")
                    Divider()
                    mimikGitter
                }
                .padding(.vertical, 4)
                .presentationCompactAdaptation(.popover)
            }
            .accessibilityLabel("Figur von \(person.name)")
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("Tippen für Anstupsen oder Kuss, lange drücken für Denk an dich")
            .accessibilityAction(named: "Anstupsen") { senden("anstupsen") }
            .accessibilityAction(named: "Kuss schicken") { senden("kuss") }
            .accessibilityAction(named: "Denk an dich") { senden("herz") }
    }

    /// The own figure making each expression; a tap sends it like the other gestures.
    private var mimikGitter: some View {
        let aussehen = FigurenModell.shared.aussehen(Raum.shared.ich ?? person.partner)
        // Two rows visible, the rest scrolls — all 14 at once was too much.
        return ScrollView {
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(66), spacing: 6), count: 4), spacing: 6) {
            ForEach(FigurZustand.mimik, id: \.self) { z in
                Button {
                    menu = false
                    senden(z.rawValue)
                } label: {
                    MimikKachel(aussehen: aussehen, zustand: z)
                }
                .buttonStyle(.federnd)
                .accessibilityLabel(z.titel)
            }
        }
        .padding(10)
        }
        .frame(maxHeight: 190)
        .scrollIndicators(.visible)
    }

    private func knopf(_ titel: String, symbol: String, art: String) -> some View {
        Button {
            menu = false
            senden(art)
        } label: {
            Label(titel, systemImage: symbol)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .padding(.horizontal, 16)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func senden(_ art: String) {
        gesendet += 1
        onGeste(art)
    }
}

/// One expression tile in the gesture menu: the face, zoomed, with its name.
private struct MimikKachel: View {
    let aussehen: FigurAussehen
    let zustand: FigurZustand

    var body: some View {
        VStack(spacing: 2) {
            FigurView(aussehen, zustand: zustand, groesse: 52, animiert: false)
                .scaleEffect(1.5)
                .offset(y: 7)
                .frame(width: 58, height: 48)
                .clipped()
            Text(zustand.titel)
                .font(.caption2)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(width: 66, height: 72)
        .contentShape(Rectangle())
    }
}

/// Receiver-side haptics for gestures.
@MainActor
enum Herzschlag {
    private static var engine: CHHapticEngine?

    /// Plays the matching haptic when a `geste` op arrives.
    static func geste(_ art: String) {
        switch art {
        case "herz": spielen()
        case "anstupsen": UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case "kuss": UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        default:
            if let z = FigurZustand(rawValue: art), FigurZustand.mimik.contains(z) { Haptik.mittel() }
        }
    }

    /// Heartbeat: two pulses per beat, three beats.
    static func spielen() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            if engine == nil {
                let neu = try CHHapticEngine()
                neu.isAutoShutdownEnabled = true
                engine = neu
            }
            guard let engine else { return }
            try engine.start()
            var events: [CHHapticEvent] = []
            for schlag in 0..<3 {
                let beginn = Double(schlag) * 0.8
                for (versatz, staerke) in [(0.0, Float(1.0)), (0.18, Float(0.6))] {
                    let parameter = [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: staerke),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.25),
                    ]
                    events.append(CHHapticEvent(eventType: .hapticTransient, parameters: parameter, relativeTime: beginn + versatz))
                }
            }
            let player = try engine.makePlayer(with: CHHapticPattern(events: events, parameters: []))
            try player.start(atTime: 0)
        } catch {
            engine = nil
        }
    }
}
