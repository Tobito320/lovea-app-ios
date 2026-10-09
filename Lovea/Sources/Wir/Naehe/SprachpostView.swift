import SwiftUI

/// Sprachpost: gedrückt halten nimmt auf, Loslassen schickt. Nichts spielt von allein, die Partnerin
/// tippt selbst auf Abspielen. Nicht live: es ist eine Nachricht zum späteren Hören.
struct SprachpostView: View {
    let speicher = SprachpostSpeicher.shared

    var body: some View {
        List {
            if speicher.liste.isEmpty {
                ContentUnavailableView(
                    "Noch keine Sprachpost",
                    systemImage: "waveform.circle",
                    description: Text("Halte den Knopf unten gedrückt und sprich. Sie hört es, wann sie Zeit hat.")
                )
                .listRowBackground(Color.clear)
            }
            ForEach(speicher.liste) { post in
                SprachpostZeile(post: post)
            }
        }
        .navigationTitle("Sprachpost")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            SprachpostAufnehmen()
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(.bar)
        }
    }
}

private struct SprachpostZeile: View {
    let post: Sprachpost
    let speicher = SprachpostSpeicher.shared

    var body: some View {
        let ungehoert = speicher.ungehoert(post)
        let meine = post.von == speicher.ich
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                if ungehoert {
                    Circle().fill(Color.accentColor).frame(width: 10, height: 10).accessibilityLabel("Ungehört")
                }
                Text(meine ? "Von dir" : "Von \(post.von.name)").font(.headline)
                Spacer()
                Text(NaeheDatum.kurz(post.zeit)).font(.caption).foregroundStyle(.secondary)
            }
            NaeheAbspielen(medienId: post.medienId, dauer: post.dauer, pegel: post.pegel) { speicher.alsGehoert(post) }
            if meine {
                Text(speicher.stand.gehoert[post.id].map { "Gehört am \(NaeheDatum.kurz($0))" } ?? "Noch nicht gehört")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .animation(Feder.weich, value: ungehoert)
    }
}

/// Halte-Knopf. Loslassen schickt, Wischen nach links bricht ab, zu kurz wird verworfen.
private struct SprachpostAufnehmen: View {
    @State private var steuerung = AufnahmeSteuerung()
    @State private var gehalten = false
    @State private var abbruch = false
    @State private var sendet = false
    @State private var meldung: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let abbruchWeg: CGFloat = -80

    var body: some View {
        VStack(spacing: 8) {
            Group {
                if sendet {
                    Label("Wird geschickt ...", systemImage: "paperplane")
                } else if steuerung.laeuft {
                    Label(
                        abbruch ? "Loslassen zum Verwerfen" : "\(zeit(steuerung.dauer))  ·  Nach links wischen zum Abbrechen",
                        systemImage: abbruch ? "trash" : "waveform"
                    )
                    .foregroundStyle(abbruch ? Color.red : Color.primary)
                } else {
                    Text(meldung ?? "Gedrückt halten zum Aufnehmen")
                }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)

            Image(systemName: "mic.fill")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 72, height: 72)
                .background(steuerung.laeuft ? Color.red : Color.accentColor, in: .circle)
                .scaleEffect(steuerung.laeuft && !reduceMotion ? 1.12 : 1)
                .animation(Feder.federnd, value: steuerung.laeuft)
                .contentShape(.circle)
                .tabWischSperre()
                .gesture(halten)
                .opacity(sendet ? 0.4 : 1)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Sprachpost aufnehmen")
                .accessibilityHint("Gedrückt halten, loslassen schickt")
                .accessibilityAddTraits(.isButton)
                .accessibilityAction(named: "Aufnahme starten oder beenden") { Task { await umschalten() } }
        }
        .animation(Feder.weich, value: steuerung.laeuft)
    }

    private var halten: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { wert in
                abbruch = wert.translation.width < Self.abbruchWeg
                guard !gehalten, !sendet else { return }
                gehalten = true
                meldung = nil
                Haptik.mittel()
                Task {
                    let laeuft = await steuerung.start()
                    if !laeuft {
                        meldung = "Mikrofon nicht erlaubt"
                    } else if !gehalten {
                        // Schon losgelassen, bevor die Berechtigung durch war: nichts behalten.
                        steuerung.verwerfen()
                    }
                }
            }
            .onEnded { wert in
                let weg = wert.translation.width < Self.abbruchWeg
                let war = gehalten
                gehalten = false
                abbruch = false
                guard war else { return }
                Task { await beenden(verwerfen: weg) }
            }
    }

    /// VoiceOver: einmal ausführen startet, noch mal beendet und schickt.
    private func umschalten() async {
        if steuerung.laeuft { await beenden(verwerfen: false) } else { _ = await steuerung.start() }
    }

    private func beenden(verwerfen: Bool) async {
        guard steuerung.hatAufnahme else { return }
        if verwerfen {
            steuerung.verwerfen()
            Haptik.warnung()
            return
        }
        guard let entwurf = await steuerung.zusammenfuegen() else { steuerung.zuruecksetzen(); return }
        guard entwurf.dauer >= SprachpostLogik.mindestDauer else {
            steuerung.verwerfen()
            meldung = "Zu kurz. Halte länger gedrückt."
            Haptik.warnung()
            return
        }
        sendet = true
        defer { sendet = false }
        // Hochladen zuerst. Bricht es ab, bleibt es wie im Chat in der Fortsetz-Warteschlange und die Op geht trotzdem raus.
        if let id = await ChatMedien.entwurfSprachHochladen(entwurf.url) {
            SprachpostSpeicher.shared.abschicken(medienId: id, dauer: entwurf.dauer, pegel: entwurf.pegel)
            Haptik.erfolg()
        } else {
            meldung = "Senden hat nicht geklappt"
            Haptik.warnung()
        }
        steuerung.zuruecksetzen()
    }

    private func zeit(_ s: TimeInterval) -> String { String(format: "%d:%02d", Int(s) / 60, Int(s) % 60) }
}
