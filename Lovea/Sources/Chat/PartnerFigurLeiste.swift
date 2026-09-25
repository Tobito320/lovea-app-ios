import AVFoundation
import SwiftUI

/// Partner figure above the input, shown while the partner is doing something chat-shaped
/// (Spec 4.2, Z-4.5). Slides in and out as that stops being true.
struct PartnerFigurLeiste: View {
    let partner: Person

    private static let sichtbareZustaende: Set<FigurZustand> = [.imChat, .tippt, .kamera, .sprache, .liest, .schautBild, .schautVideo]

    private var zustand: FigurenModell.Zustand? {
        let z = FigurenModell.shared.anzeige(partner)
        return Self.sichtbareZustaende.contains(z.haupt) ? z : nil
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Tap on the figure: a sweet "mhm", a pout and a wagging finger ("hands off").
    @State private var schimpft = false
    @State private var wackeln = 0

    var body: some View {
        VStack(spacing: 0) {
            if let zustand {
                HStack(spacing: 8) {
                    FigurView(FigurenModell.shared.aussehen(partner), zustand: schimpft ? .schmollt : zustand.haupt, abzeichen: zustand.abzeichen, groesse: 44, bildrate: 20)
                        .keyframeAnimator(initialValue: 0.0, trigger: wackeln) { figur, winkel in
                            figur.rotationEffect(.degrees(reduceMotion ? 0 : winkel * 0.25), anchor: .bottom)
                        } keyframes: { _ in wackelSpur() }
                        .overlay(alignment: .topTrailing) {
                            if schimpft {
                                Image(systemName: "hand.point.up.left.fill")
                                    .font(.system(size: 17))
                                    .foregroundStyle(Color(red: 0.96, green: 0.80, blue: 0.68))
                                    .shadow(color: .black.opacity(0.35), radius: 0.5)
                                    .keyframeAnimator(initialValue: 0.0, trigger: wackeln) { finger, winkel in
                                        finger.rotationEffect(.degrees(reduceMotion ? 0 : winkel), anchor: .bottom)
                                    } keyframes: { _ in wackelSpur() }
                                    .offset(x: 12, y: 2)
                                    .transition(.scale(scale: 0.3, anchor: .bottom).combined(with: .opacity))
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { anmeckern() }
                    Text(zustand.haupt.titel)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)
                // One element: figure + its state as text, not "Figur" followed by the same state twice.
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(partner.name): \(zustand.haupt.titel)")
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { anmeckern() }
                .transition(reduceMotion ? AnyTransition.opacity : AnyTransition.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.3), value: zustand?.haupt)
    }

    private func wackelSpur() -> some Keyframes<Double> {
        KeyframeTrack {
            CubicKeyframe(18, duration: 0.12)
            CubicKeyframe(-18, duration: 0.18)
            CubicKeyframe(18, duration: 0.18)
            CubicKeyframe(-18, duration: 0.18)
            CubicKeyframe(0, duration: 0.14)
        }
    }

    private func anmeckern() {
        Haptik.leicht()
        MhmTon.spielen()
        withAnimation(Feder.federnd) { schimpft = true }
        wackeln += 1
        Task {
            try? await Task.sleep(for: .seconds(1.4))
            withAnimation(Feder.weich) { schimpft = false }
        }
    }
}

/// The sweet annoyed "mhm" (`mhm.wav`, generated). A strong static reference keeps the player alive.
@MainActor
private enum MhmTon {
    private static var player: AVAudioPlayer?
    static func spielen() {
        guard let url = Bundle.main.url(forResource: "mhm", withExtension: "wav")
            ?? Bundle.main.url(forResource: "mhm", withExtension: "wav", subdirectory: "Chat")
        else { return }
        player = try? AVAudioPlayer(contentsOf: url)
        player?.play()
    }
}
