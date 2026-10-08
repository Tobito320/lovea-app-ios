import SwiftUI

/// Hilfe nur für Ahmed (Ahmed 08.10.): erscheint nie auf Annikas Gerät, weil alles an
/// `Raum.shared.ich == .ahmed` hängt. Rein lokal: keine Op, kein Push, nichts landet im Raum.
/// Der Chat-Hinweis: wartet Annika seit einer Weile auf eine Antwort, schlägt die Leiste über der
/// Eingabe drei kurze Sätze vor ("melde mich um …"), ein Tipp sendet einen davon. Schalter in den
/// Einstellungen (nur im Profil von Ahmed), Tipps-Seite ebenda.
enum AhmedHilfe {
    nonisolated static let schluessel = "lovea.ahmedHilfe"
    /// Local to the device, no op. Same pattern as `ChatTempo.an`; the settings toggle binds the same key.
    nonisolated static var an: Bool { UserDefaults.standard.object(forKey: schluessel) as? Bool ?? true }

    nonisolated static let wartetAb: TimeInterval = 20 * 60
    nonisolated static let wartetBis: TimeInterval = 12 * 3600
    /// Nachts (23 bis 7 Uhr) kommt kein Hinweis: da wird nicht geantwortet.
    nonisolated static let wachStunden = 7..<23

    nonisolated static let vorschlaege = [
        "Gesehen, melde mich gleich",
        "Bin gerade beschäftigt, melde mich heute Abend",
        "Hab dich lieb, antworte dir später in Ruhe",
    ]

    /// The partner's last real message waiting for an answer, or nil when no hint is due: the last
    /// visible line must be from the partner (not a system line, not deleted), 20 minutes to 12
    /// hours old, and `jetzt` must be between 7 and 23 o'clock.
    nonisolated static func wartet(auf nachrichten: [ChatModell.Nachricht], ich: Person, jetzt: Date,
                                   kalender: Calendar = .current) -> ChatModell.Nachricht? {
        guard ich == .ahmed, wachStunden.contains(kalender.component(.hour, from: jetzt)),
              let letzte = nachrichten.last(where: { !$0.geloescht && $0.system == nil }),
              letzte.von == ich.partner else { return nil }
        let alter = jetzt.timeIntervalSince(letzte.zeit)
        return alter >= wartetAb && alter <= wartetBis ? letzte : nil
    }

    /// "35 Min." or "2 Std.".
    nonisolated static func dauerText(_ sekunden: TimeInterval) -> String {
        let minuten = Int(sekunden / 60)
        return minuten < 60 ? "\(minuten) Min." : "\(minuten / 60) Std."
    }
}

/// The bar above the input: only for Ahmed, only while Annika waits, one dismiss per message.
struct AhmedHilfeLeiste: View {
    let ich: Person
    let modell: ChatModell
    @AppStorage(AhmedHilfe.schluessel) private var eingeschaltet = true // same key `AhmedHilfe.an` reads
    @State private var weggetippt: String?

    var body: some View {
        if ich == .ahmed, eingeschaltet {
            // Once a minute, so "35 Min." counts up and the bar appears without a new op.
            TimelineView(.periodic(from: .now, by: 60)) { zeit in
                if let nachricht = AhmedHilfe.wartet(auf: modell.nachrichten, ich: ich, jetzt: zeit.date), nachricht.id != weggetippt {
                    leiste(nachricht, jetzt: zeit.date)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
    }

    private func leiste(_ nachricht: ChatModell.Nachricht, jetzt: Date) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("\(ich.partner.name) wartet seit \(AhmedHilfe.dauerText(jetzt.timeIntervalSince(nachricht.zeit))). Sag kurz, wann du antwortest.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 8)
                Button {
                    Haptik.leicht()
                    withAnimation(Feder.schnell) { weggetippt = nachricht.id }
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .accessibilityLabel("Hinweis schließen")
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(AhmedHilfe.vorschlaege, id: \.self) { satz in
                        Button {
                            Haptik.leicht()
                            modell.nachrichtSenden(text: satz)
                        } label: {
                            Text(satz)
                                .font(.footnote)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(.thinMaterial, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}

/// Settings, only in Ahmed's own profile: the switch for the bar and the page with the tips.
struct AhmedHilfeEinstellungen: View {
    @AppStorage(AhmedHilfe.schluessel) private var eingeschaltet = true

    var body: some View {
        Section {
            Toggle("Hinweis im Chat", isOn: $eingeschaltet)
            NavigationLink("Tipps für dich") { AhmedTippsSeite() }
        } header: {
            Text("Für dich")
        } footer: {
            Text("Nur auf deinem Gerät. Der Hinweis erscheint über der Eingabe, wenn jemand länger auf eine Antwort wartet. Aus: wie vorher.")
        }
    }
}

/// Short, kind rules of thumb. Static text, nothing is read from the chat.
struct AhmedTippsSeite: View {
    private struct Tipp { let titel: String, text: String }
    private struct Satz { let statt: String, besser: String }

    private static let tipps = [
        Tipp(titel: "Warten sichtbar machen", text: "Kannst du nicht gleich antworten, schreib kurz wann. Ein Satz reicht: Gesehen, melde mich um 20 Uhr."),
        Tipp(titel: "Vor dem Schlafen abschließen", text: "Bist du zu müde zum Reden, nenn eine feste Zeit: Morgen um 10 reden wir weiter. Nicht still werden."),
        Tipp(titel: "Nur zusagen, was sicher ist", text: "Lieber klein und gehalten als groß und zurückgenommen."),
        Tipp(titel: "Von dir aus melden", text: "Ich vermisse dich, wann sehen wir uns: kommt am besten, bevor gefragt wird."),
        Tipp(titel: "Gym und Freunde", text: "Vorher kurz Bescheid: Bin bis 22 Uhr im Gym, melde mich danach."),
        Tipp(titel: "Wenn dich etwas stört", text: "Sag es ruhig und frag, was sie braucht: Rat oder nur zuhören?"),
    ]
    private static let glueck = [
        Tipp(titel: "Eine Nachricht, die sie nicht erwartet", text: "Persönlich und aus dir selbst, ohne Anlass. Das trifft mehr als jede Show."),
        Tipp(titel: "Selbst gemacht", text: "Etwas Eigenes aus Liebe zählt mehr als etwas Gekauftes. Blumen gern, aber nicht aus Pflicht."),
        Tipp(titel: "Ruhige Zeit", text: "Park, zusammen kochen, ausschlafen. Zeit zählt mehr als Geld."),
        Tipp(titel: "Kleinigkeiten bemerken", text: "Sag, was dir an ihr auffällt, zum Beispiel ihr Lächeln."),
        Tipp(titel: "Deine Stimme bei Stress", text: "Ruf an, wenn es ihr nicht gut geht. Nähe und Stimme beruhigen sie."),
        Tipp(titel: "Ein Bild von dir", text: "Ein Foto aus deinem Tag freut sie."),
    ]
    private static let dates = [
        "Park, spazieren, reden.",
        "Zusammen kochen, ohne Kalorien zu zählen.",
        "Wochenende zum Ausschlafen.",
        "Zusammen zeichnen oder ein Brief in Lovea.",
        "Wochenende früh klären, mit Zeit und Ort: Samstag 14 Uhr, Park.",
    ]
    private static let saetze = [
        Satz(statt: "Ich antworte, wenn ich kann.", besser: "Ich schaffe das heute nicht vor 20 Uhr, melde mich dann."),
        Satz(statt: "Das ist wieder eine Beschwerde.", besser: "Danke, dass du es sagst. Erzähl mir mehr."),
        Satz(statt: "Bin eingeschlafen.", besser: "Ich bin müde. Morgen um 10 reden wir in Ruhe weiter."),
        Satz(statt: "Mein Lieblingsmensch aktuell, dazu eine Aufzählung.", besser: "Du bist mein Lieblingsmensch."),
        Satz(statt: "Plane noch 10 Minuten Gym.", besser: "Eher 40 Minuten, ich rufe um 21 Uhr an."),
    ]
    private static let besserNicht = [
        "Eine Nachricht als Beschwerde oder Drama abtun.",
        "Späte Abend-Scherze mit Spitze.",
        "Mitten im Streit offline gehen, ohne zu sagen, wann du antwortest.",
        "Auf ihr Lob oder ihre Frage nichts antworten: ein Herz oder Danke reicht.",
        "Zahlen oder Ziele nennen, wenn es um Körper oder Essen geht: zuhören, bestätigen, fragen.",
    ]

    var body: some View {
        List {
            Section("Jeden Tag") { tippZeilen(Self.tipps) }
            Section {
                tippZeilen(Self.glueck)
            } header: {
                Text("Was sie glücklich macht")
            } footer: {
                Text("Hilfe, kein Skript. Echt und eigener Einfall schlägt jede Liste.")
            }
            Section("Date-Ideen") {
                ForEach(Self.dates, id: \.self) { Text($0).font(.footnote) }
            }
            Section("Statt, besser") {
                ForEach(Self.saetze, id: \.statt) { satz in
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Statt: \(satz.statt)").font(.footnote).foregroundStyle(.secondary)
                        Text(satz.besser).font(.subheadline)
                    }
                    .padding(.vertical, 2)
                }
            }
            Section("Besser nicht") {
                ForEach(Self.besserNicht, id: \.self) { Text($0).font(.footnote) }
            }
        }
        .navigationTitle("Tipps für dich")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func tippZeilen(_ liste: [Tipp]) -> some View {
        ForEach(liste, id: \.titel) { tipp in
            VStack(alignment: .leading, spacing: 3) {
                Text(tipp.titel).font(.subheadline.weight(.semibold))
                Text(tipp.text).font(.footnote).foregroundStyle(.secondary)
            }
            .padding(.vertical, 2)
        }
    }
}
