import SwiftUI

// R7: "Training starten" gehört nicht mehr auf die Heute-Seite (Ahmed, 01.10.). Stattdessen eine
// schmale Leiste über der ganzen App: im Gym angekommen ein Vorschlag, läuft eine Einheit eine
// Live-Uhr. Für Ahmed und Annika gleich, jeweils für die eigene Person.

/// Reine Entscheidung, ohne SwiftUI oder Modelle — testbar ohne Gerät (`GymLeisteTests`).
enum GymLeisteZustand: Equatable {
    case aus
    case vorschlag
    /// Gerade beendet und noch im Gym: dasselbe Training fortsetzen statt nur neu starten.
    case fortsetzen
    case laeuft(seit: Date)
}

enum GymLeisteLogik {
    /// Eine laufende Einheit gewinnt immer. Sonst: im Gym und nicht für diesen Besuch weggewischt
    /// zeigt den Vorschlag (nach einem gerade beendeten Training: Fortsetzen), alles andere ist still.
    static func zustand(atGym: Bool, laufendeSeit: Date?, weggewischt: Bool, fortsetzbar: Bool = false) -> GymLeisteZustand {
        if let seit = laufendeSeit { return .laeuft(seit: seit) }
        if atGym && !weggewischt { return fortsetzbar ? .fortsetzen : .vorschlag }
        return .aus
    }
}

/// mm:ss, auch über 59:59 hinaus (keine Stunden-Spalte nötig, eine Einheit dauert selten so lange).
private func mmss(_ sekunden: TimeInterval) -> String {
    let s = max(0, Int(sekunden.rounded()))
    return String(format: "%d:%02d", s / 60, s % 60)
}

/// Docken an der App-Wurzel, über dem Inhalt (Akku: liest nur den schon berechneten Anwesenheits-
/// und Trainingsstand, startet kein eigenes Standort-/Timer-Update; die Sekundenuhr tickt nur,
/// solange diese Leiste selbst sichtbar ist — über `TimelineView`, nicht global).
struct GymLeisteView: View {
    @State private var weggewischt = false
    private var ich: Person { Raum.shared.ich ?? .ahmed }

    private var atGym: Bool { FigurenModell.shared.zustand[ich]?.haupt == .gym }
    private var laufendeSeit: Date? { TrainingModell.shared.laufende(ich)?.start }

    var body: some View {
        let beendet = TrainingModell.shared.fortsetzbare(ich)
        let zustand = GymLeisteLogik.zustand(atGym: atGym, laufendeSeit: laufendeSeit, weggewischt: weggewischt, fortsetzbar: beendet != nil)
        Group {
            switch zustand {
            case .aus: EmptyView()
            case .vorschlag: vorschlagLeiste
            case .fortsetzen: if let beendet { fortsetzenLeiste(beendet) }
            case .laeuft(let seit): laeuftLeiste(seit: seit)
            }
        }
        .onChange(of: atGym) { _, neu in if !neu { weggewischt = false } }
        // Review: `safeAreaInset` verdrängt statt überdeckt, soll den Inhalt aber weich schieben,
        // nicht hart springen lassen.
        .animation(.easeInOut(duration: 0.25), value: zustand)
    }

    private var vorschlagLeiste: some View {
        HStack(spacing: 10) {
            Image(systemName: "figure.strengthtraining.traditional").foregroundStyle(Color.person(ich))
            Text("Du bist im Gym").font(.subheadline.weight(.semibold))
            Spacer(minLength: 8)
            Button("Session starten") { starten() }
                .font(.subheadline.weight(.semibold))
                .buttonStyle(.borderedProminent)
                .tint(Color.person(ich))
            Button { weggewischt = true } label: {
                Image(systemName: "xmark").font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Schließen")
        }
        .leistenRahmen()
        .accessibilityElement(children: .combine)
    }

    private func fortsetzenLeiste(_ s: GymSession) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "figure.strengthtraining.traditional").foregroundStyle(Color.person(ich))
            Text("Training beendet").font(.subheadline.weight(.semibold)).lineLimit(1)
            Spacer(minLength: 8)
            Button("Fortsetzen") {
                TrainingModell.shared.auscheckenRueckgaengig(s.id)
                Haptik.erfolg()
                oeffnen()
            }
            .font(.subheadline.weight(.semibold))
            .buttonStyle(.borderedProminent)
            .tint(Color.person(ich))
            Button("Neu") { starten() }
                .font(.subheadline.weight(.semibold))
                .buttonStyle(.bordered)
            Button { weggewischt = true } label: {
                Image(systemName: "xmark").font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Schließen")
        }
        .leistenRahmen()
    }

    private func laeuftLeiste(seit: Date) -> some View {
        Button { oeffnen() } label: {
            HStack(spacing: 10) {
                Image(systemName: "figure.strengthtraining.traditional").foregroundStyle(Color.person(ich))
                TimelineView(.periodic(from: seit, by: 1)) { kontext in
                    Text("Training läuft · \(mmss(kontext.date.timeIntervalSince(seit)))")
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
            }
            .leistenRahmen()
        }
        .buttonStyle(.plain)
        .accessibilityHint("Öffnet die laufende Einheit")
    }

    private func starten() {
        TrainingModell.shared.einchecken(tag: TrainingModell.shared.heutigerTag(ich)?.id)
        Haptik.erfolg()
        oeffnen()
    }

    /// Wie die Live Activity ("zurück ins laufende Training"): Health-Tab, Trainingsseite, und falls
    /// schon eine Einheit läuft direkt hinein (`AppRootView`, `HeuteView.seiteAusWunsch`).
    private func oeffnen() { AppNavigation.shared.tabWunsch = "gym" }
}

private extension View {
    func leistenRahmen() -> some View {
        padding(.horizontal, 16)
            .frame(minHeight: 44)
            .background(.regularMaterial)
    }
}
