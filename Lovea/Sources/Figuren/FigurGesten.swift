import CoreHaptics
import SwiftUI
import UIKit

extension View {
    /// Tap opens a small menu (Anstupsen, Kuss); long press sends "herz".
    /// `onGeste` gets exactly "anstupsen", "kuss" or "herz"; the caller sends the `geste` op.
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
        default: break
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
