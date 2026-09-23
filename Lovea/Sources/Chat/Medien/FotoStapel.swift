import AVKit
import SwiftUI
import UIKit

/// Instagram-style photo stack (Block 18): up to three cards fanned behind each other with a count
/// badge. Tap opens the full-screen gallery; the long-press menu is the bubble's (`ChatNachrichtRow`).
struct FotoStapel: View {
    let medien: [ChatModell.MedienEintrag]
    let eigene: Bool
    @State private var galerieOffen = false
    @Namespace private var zoomRaum

    var body: some View {
        ZStack {
            ForEach(Array(medien.prefix(3).enumerated()), id: \.element.id) { eintrag in
                MedienKachel(medium: eintrag.element, eigene: eigene)
                    .frame(width: 176, height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color(uiColor: .systemBackground), lineWidth: 2))
                    .shadow(color: .black.opacity(0.2), radius: 5, y: 2)
                    .rotationEffect(.degrees(winkel(eintrag.offset)))
                    .offset(x: versatz(eintrag.offset))
                    .zIndex(Double(-eintrag.offset))
            }
        }
        .frame(width: 226, height: 240)
        .overlay(alignment: eigene ? .topLeading : .topTrailing) {
            Text("\(medien.count)")
                .font(.caption.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(.black.opacity(0.6), in: Capsule())
                .padding(6)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard !LangDruck.geradeEben else { return }
            Haptik.leicht()
            galerieOffen = true
        }
        // Z-33.4: the gallery zooms out of the stack and back into it.
        .matchedTransitionSource(id: "stapel", in: zoomRaum)
        .fullScreenCover(isPresented: $galerieOffen) {
            MedienGalerie(medien: medien, eigene: eigene)
                .navigationTransition(.zoom(sourceID: "stapel", in: zoomRaum))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(medien.count) Fotos")
        .accessibilityHint("Galerie öffnen")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { galerieOffen = true }
    }

    /// Top card straight, the ones behind tilted away from the bubble's side.
    private func winkel(_ index: Int) -> Double {
        let richtung: Double = eigene ? -1 : 1
        return [0, 6, -5][index] * richtung
    }

    private func versatz(_ index: Int) -> CGFloat {
        let richtung: CGFloat = eigene ? -1 : 1
        return [0, 14, -10][index] * richtung
    }
}

/// Full-screen swipeable gallery for a stack: page swipe between photos, swipe down to close,
/// double tap zooms a photo, counter on top, selection haptic per page.
struct MedienGalerie: View {
    let medien: [ChatModell.MedienEintrag]
    let eigene: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var auswahl = 0
    @State private var zieh: CGFloat = 0

    var body: some View {
        ZStack {
            Color.black.opacity(1 - min(zieh / 500, 0.5)).ignoresSafeArea()
            TabView(selection: $auswahl) {
                ForEach(Array(medien.enumerated()), id: \.element.id) { eintrag in
                    GalerieSeite(medium: eintrag.element, eigene: eigene).tag(eintrag.offset)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: medien.count > 1 ? .always : .never))
            .ignoresSafeArea()
            .offset(y: zieh)
            .simultaneousGesture(
                DragGesture(minimumDistance: 20)
                    .onChanged { wert in
                        guard wert.translation.height > 0, wert.translation.height > abs(wert.translation.width) else { return }
                        zieh = wert.translation.height
                    }
                    .onEnded { _ in
                        if zieh > 120 { ChatHaptik.leicht(); dismiss() } else { withAnimation(.spring(duration: 0.3)) { zieh = 0 } }
                    }
            )
        }
        .overlay(alignment: .top) {
            HStack {
                Text("\(auswahl + 1) von \(medien.count)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.white)
                Spacer()
                Button { dismiss() } label: { Image(systemName: "xmark.circle.fill").font(.title2).frame(width: 44, height: 44) }
                    .foregroundStyle(.white)
                    .accessibilityLabel("Schließen")
            }
            .padding(.horizontal)
            .opacity(zieh > 0 ? 0 : 1)
        }
        .presentationBackground(.clear)
        .statusBarHidden()
        .sensoryFeedback(.selection, trigger: auswahl)
        .task { FigurenModell.shared.zustandSenden(.init(haupt: .schautBild)) }
        .onDisappear { FigurenModell.shared.zustandSenden(.init(haupt: .imChat)) }
    }
}

private struct GalerieSeite: View {
    let medium: ChatModell.MedienEintrag
    let eigene: Bool
    @State private var url: URL?
    @State private var bild: UIImage?
    @State private var spieler: AVPlayer?
    @State private var zoom: CGFloat = 1

    var body: some View {
        ZStack {
            if let spieler {
                VideoPlayer(player: spieler)
            } else if let bild {
                Image(uiImage: bild)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(zoom)
                    .onTapGesture(count: 2) {
                        ChatHaptik.leicht()
                        withAnimation(.spring(duration: 0.3)) { zoom = zoom > 1 ? 1 : 2.2 }
                    }
                    .contextMenu {
                        if let url {
                            Button("In Galerie speichern", systemImage: "photo.badge.plus") { ChatGalerie.inGaleriesSpeichern(bildURL: url) }
                        }
                    }
            } else {
                ProgressView().tint(.white)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: medium.id) {
            guard let geladen = await MedienDatei.url(medium, eigene: eigene) else { return }
            url = geladen
            if medium.typ == "video" {
                spieler = AVPlayer(url: geladen)
            } else {
                bild = await Bilddatei.laden(geladen)
            }
        }
        .onDisappear { spieler?.pause() }
    }
}
