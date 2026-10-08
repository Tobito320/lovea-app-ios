import AVKit
import SwiftUI

/// Video vor dem Senden schneiden: vorn und hinten kürzen, Teile aus der Mitte entfernen, Ton aus.
/// Der Plan (`SnapSchnitt`) rechnet, `SnapSchnittExport` setzt ihn um. Das Blatt hat keinen Takt und
/// spielt nicht von selbst: man schiebt durch das Video (Einzelbild), setzt Marken, fertig.
/// Einhängen: als `fullScreenCover`/`sheet` zeigen, `onFertig` liefert die neue Datei (oder die
/// unveränderte Quelle, wenn nichts geändert wurde).
struct SnapSchnittBlatt: View {
    let quelle: URL
    let onFertig: (URL) -> Void
    let onAbbruch: () -> Void

    @State private var plan: SnapSchnitt?
    @State private var spieler: AVPlayer?
    @State private var position = 0.0
    @State private var markeStart: Double?
    @State private var schneidet = false
    @State private var hinweis: String?

    var body: some View {
        VStack(spacing: 16) {
            kopfzeile
            vorschau
            if let plan {
                zeitleiste(plan)
                werkzeuge(plan)
                entfernteChips(plan)
            }
            if let hinweis { Text(hinweis).font(.footnote).foregroundStyle(.orange).multilineTextAlignment(.center) }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
        .background(Color.black.ignoresSafeArea())
        .task { await vorbereiten() }
        .onDisappear { spieler?.pause() }
    }

    // MARK: Teile

    private var kopfzeile: some View {
        HStack {
            Button("Abbrechen") { onAbbruch() }
            Spacer()
            if let plan {
                Text("Länge " + SnapSchnitt.zeit(plan.ergebnisDauer)).font(.subheadline.monospacedDigit())
            }
            Spacer()
            if schneidet {
                HStack(spacing: 6) { ProgressView().tint(.white); Text("Wird geschnitten") }.font(.footnote)
            } else {
                Button("Fertig") { fertigMelden() }
                    .fontWeight(.semibold)
                    .disabled(plan?.gueltig != true)
            }
        }
        .foregroundStyle(.white)
        .padding(.top, 8)
    }

    @ViewBuilder private var vorschau: some View {
        if let spieler {
            VideoPlayer(player: spieler)
                .disabled(true)
                .clipShape(.rect(cornerRadius: 16))
        } else {
            ProgressView().tint(.white).frame(maxHeight: .infinity)
        }
    }

    private func zeitleiste(_ plan: SnapSchnitt) -> some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                let breite = geo.size.width
                let dauer = max(plan.dauer, 0.001)
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.18))
                    ForEach(Array(plan.behalten.enumerated()), id: \.offset) { _, teil in
                        Capsule().fill(.white)
                            .frame(width: max(breite * teil.laenge / dauer, 2))
                            .offset(x: breite * teil.von / dauer)
                    }
                    Capsule().fill(.pink).frame(width: 3, height: 22)
                        .offset(x: min(max(breite * position / dauer - 1.5, 0), breite - 3))
                }
            }
            .frame(height: 14)
            Slider(value: $position, in: 0...max(plan.dauer, 0.001))
                .tint(.pink)
                .onChange(of: position) { _, neu in
                    spieler?.seek(to: CMTime(seconds: neu, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
                }
            Text(SnapSchnitt.zeit(position) + " von " + SnapSchnitt.zeit(plan.dauer))
                .font(.caption2.monospacedDigit()).foregroundStyle(.white.opacity(0.7))
        }
    }

    private func werkzeuge(_ plan: SnapSchnitt) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                knopf("Anfang hier", "arrow.right.to.line") { bearbeiten { schnitt in let ende = schnitt.ende; return schnitt.kuerzen(anfang: position, ende: ende) } }
                knopf("Ende hier", "arrow.left.to.line") { bearbeiten { schnitt in let anfang = schnitt.anfang; return schnitt.kuerzen(anfang: anfang, ende: position) } }
            }
            HStack(spacing: 10) {
                if let start = markeStart {
                    knopf("Bis hier entfernen", "scissors") {
                        bearbeiten { schnitt in schnitt.entfernen(von: start, bis: position) }
                        markeStart = nil
                    }
                } else {
                    knopf("Ab hier markieren", "scissors") { markeStart = position; hinweis = nil }
                }
                knopf(plan.stumm ? "Ton aus" : "Ton an", plan.stumm ? "speaker.slash.fill" : "speaker.wave.2.fill") {
                    var neu = plan
                    neu.stumm.toggle()
                    self.plan = neu
                    Haptik.auswahl()
                }
            }
            if let start = markeStart {
                Text("Marke bei " + SnapSchnitt.zeit(start) + ". Zum Ende des Teils schieben, dann entfernen.")
                    .font(.caption2).foregroundStyle(.white.opacity(0.7))
            }
        }
    }

    @ViewBuilder private func entfernteChips(_ plan: SnapSchnitt) -> some View {
        if !plan.entfernt.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(plan.entfernt.enumerated()), id: \.offset) { index, teil in
                        Button {
                            var neu = plan
                            neu.entfernenRueckgaengig(bei: index)
                            self.plan = neu
                            Haptik.leicht()
                        } label: {
                            Label(SnapSchnitt.zeit(teil.von) + "–" + SnapSchnitt.zeit(teil.bis), systemImage: "xmark.circle.fill")
                                .font(.caption.monospacedDigit())
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(.white.opacity(0.15), in: .capsule)
                        }
                        .foregroundStyle(.white)
                        .accessibilityLabel("Entfernten Teil \(index + 1) wiederherstellen")
                    }
                }
            }
        }
    }

    private func knopf(_ titel: String, _ symbol: String, _ aktion: @escaping () -> Void) -> some View {
        Button(action: aktion) {
            Label(titel, systemImage: symbol)
                .font(.footnote.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(.white.opacity(0.15), in: .rect(cornerRadius: 12))
        }
        .foregroundStyle(.white)
        .buttonStyle(.federnd)
    }

    // MARK: Ablauf

    private func vorbereiten() async {
        guard plan == nil, let dauer = await SnapSchnittExport.dauer(von: quelle) else {
            if plan == nil { hinweis = "Das Video lässt sich nicht lesen." }
            return
        }
        plan = SnapSchnitt(dauer: dauer)
        spieler = AVPlayer(url: quelle)
    }

    /// Wendet eine Änderung an; lehnt der Plan sie ab (zu kurz, zu wenig übrig), sagt das Blatt es.
    private func bearbeiten(_ aenderung: (inout SnapSchnitt) -> Bool) {
        guard var neu = plan else { return }
        if aenderung(&neu) {
            plan = neu
            hinweis = nil
            Haptik.auswahl()
        } else {
            hinweis = "Das geht nicht: zu kurz oder es bliebe weniger als eine halbe Sekunde."
            Haptik.warnung()
        }
    }

    private func fertigMelden() {
        guard let plan, plan.gueltig, !schneidet else { return }
        guard plan.veraendert else { onFertig(quelle); return }
        schneidet = true
        hinweis = nil
        spieler?.pause()
        Task {
            let ergebnis = await SnapSchnittExport.exportieren(quelle: quelle, plan: plan)
            schneidet = false
            if let ergebnis {
                Haptik.erfolg()
                onFertig(ergebnis)
            } else {
                hinweis = "Schneiden hat nicht geklappt. Das Video bleibt, wie es war."
                Haptik.warnung()
            }
        }
    }
}
