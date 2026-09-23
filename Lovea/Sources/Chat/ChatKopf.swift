import SwiftUI
import UIKit

/// Z-32.2: the conversation header. One wide glass bar with the partner's live figure head, name
/// and status (tap → partner profile), FaceTime audio and video as glass buttons on the right.
struct ChatKopf: View {
    let partner: Person
    let modell: ChatModell
    let onProfil: () -> Void
    @State private var hinweis: String?

    /// Place states worth naming in the status line ("im Gym · online").
    private static let orte: Set<FigurZustand> = [.schule, .arbeit, .gym, .zuhause, .fahrschule, .supermarkt]

    var body: some View {
        VStack(spacing: 6) {
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    profilKnopf
                    anrufKnopf(audio: true)
                    anrufKnopf(audio: false)
                }
            }
            if let hinweis {
                Text(hinweis)
                    .font(.footnote.weight(.medium))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .glassEffect(.regular, in: .capsule)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 2)
        .task(id: hinweis) {
            guard hinweis != nil else { return }
            try? await Task.sleep(for: .seconds(2.5))
            withAnimation(Feder.weich) { hinweis = nil }
        }
    }

    private var profilKnopf: some View {
        Button {
            Haptik.leicht()
            onProfil()
        } label: {
            HStack(spacing: 10) {
                KopfFigur(person: partner, groesse: 40)
                VStack(alignment: .leading, spacing: 1) {
                    Text(partner.name).font(.headline).lineLimit(1)
                    TimelineView(.everyMinute) { _ in
                        Text(status)
                            .font(.caption)
                            .foregroundStyle(tippt ? Color.person(partner) : Color.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.leading, 6)
            .padding(.trailing, 14)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .capsule)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(partner.name), \(status)")
        .accessibilityHint("Profil öffnen")
        .accessibilityAddTraits(.isButton)
    }

    private func anrufKnopf(audio: Bool) -> some View {
        Button { anrufen(audio: audio) } label: {
            Image(systemName: audio ? "phone.fill" : "video.fill")
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 50, height: 50)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel(audio ? "FaceTime Audio" : "FaceTime Video")
    }

    private var tippt: Bool { FigurenModell.shared.anzeige(partner).haupt == .tippt }

    /// "tippt …" wins; otherwise the last known place (also while offline) plus online/last seen.
    private var status: String {
        if tippt { return "tippt …" }
        let ort = FigurenModell.shared.zustand[partner]?.haupt
        let ortText = ort.flatMap { Self.orte.contains($0) ? $0.titel : nil }
        return [ortText, anwesenheit].compactMap { $0 }.joined(separator: " · ")
    }

    private var anwesenheit: String {
        if Raum.shared.partnerDa { return "online" }
        let zuletzt = [FigurenModell.shared.partnerZuletztGesehen[partner], modell.letzteAktivitaet[partner]].compactMap { $0 }.max()
        guard let zuletzt else { return "offline" }
        return "zuletzt " + ZeitText.relativ(zuletzt)
    }

    private func anrufen(audio: Bool) {
        guard let url = FaceTime.url(audio: audio, kontakt: FaceTime.kontakt(von: partner)) else {
            Haptik.warnung()
            withAnimation(Feder.federnd) { hinweis = "\(partner.name) hat noch keine FaceTime-Nummer eingetragen" }
            return
        }
        Haptik.leicht()
        UIApplication.shared.open(url)
    }
}

/// Round head crop of a figure (header 40 pt live, read receipt 18 pt still): the head sits in the
/// top of FigurView's canvas, so the view is drawn 1.35× and clipped to a top-aligned circle.
struct KopfFigur: View {
    let person: Person
    let groesse: CGFloat
    var animiert = true

    var body: some View {
        let anzeige = FigurenModell.shared.anzeige(person)
        FigurView(FigurenModell.shared.aussehen(person), zustand: anzeige.haupt, abzeichen: anzeige.abzeichen, groesse: groesse * 1.35, animiert: animiert, bildrate: 20)
            .frame(width: groesse, height: groesse, alignment: .top)
            .clipShape(.circle)
            .background(Color.person(person).opacity(0.18), in: .circle)
    }
}

/// Z-33.4: pinned messages as one slim glass bar under the header, at most three, tap jumps there.
struct ChatAngeheftetLeiste: View {
    let modell: ChatModell
    let onSpringeZu: (String) -> Void

    var body: some View {
        let angeheftet = Array(modell.angeheftete.suffix(3))
        if !angeheftet.isEmpty {
            HStack(spacing: 8) {
                Image(systemName: "pin.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                ForEach(Array(angeheftet.enumerated()), id: \.element.id) { index, nachricht in
                    if index > 0 { Divider().frame(height: 18) }
                    Button {
                        Haptik.auswahl()
                        onSpringeZu(nachricht.id)
                    } label: {
                        Text(ChatVorschau.inhalt(nachricht))
                            .font(.footnote)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Angeheftet: \(ChatVorschau.inhalt(nachricht))")
                    .accessibilityHint("Zur Nachricht springen")
                }
            }
            .padding(.horizontal, 16)
            .glassEffect(.regular, in: .capsule)
            .padding(.horizontal, 12)
        }
    }
}
