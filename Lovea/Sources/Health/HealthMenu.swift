import SwiftUI
import UIKit

/// Z-21.2 "…"-Menü: vergangene Gym-Tage nachtragen und die eigenen/gemeinsamen Ziele ändern.

struct VergangeneTageView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var monateZurueck = 0

    private var health: HealthModell { HealthModell.shared }
    private var ich: Person { Raum.shared.ich ?? .ahmed }
    private var heute: String { Datum.text(Date()) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    HStack {
                        Button { wechsleMonat(1) } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
                            .accessibilityLabel("Vorheriger Monat")
                        Spacer()
                        Text(monatsTitel).font(.subheadline.weight(.semibold))
                        Spacer()
                        Button { wechsleMonat(-1) } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }
                            .disabled(monateZurueck == 0)
                            .accessibilityLabel("Nächster Monat")
                    }
                    .buttonStyle(.plain)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 8) {
                        ForEach(Array(gitter.enumerated()), id: \.offset) { _, tag in
                            if let tag, tag <= heute {
                                tagKnopf(tag)
                            } else {
                                Color.clear.frame(height: 40)
                            }
                        }
                    }
                    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                    .contentShape(Rectangle())
                    .gesture(
                        // Wie `MonatsAnsicht`: links wischen = später, rechts wischen = früher.
                        DragGesture(minimumDistance: 24).onEnded { wert in
                            if wert.translation.width < -30 { wechsleMonat(-1) }
                            else if wert.translation.width > 30 { wechsleMonat(1) }
                        }
                    )

                    Text("Nur Gym-Tage der letzten 7 Tage geben noch Punkte. Ältere zählen nur hier grün, ohne Punkte.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(16)
            }
            .navigationTitle("Vergangene Tage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } }
            }
        }
    }

    private var gitter: [String?] { HealthLogik.monatsGitter(heute: heute, monateZurueck: monateZurueck) }

    private func wechsleMonat(_ delta: Int) {
        UISelectionFeedbackGenerator().selectionChanged()
        monateZurueck = max(0, monateZurueck + delta)
    }

    private var monatsTitel: String {
        let aktuellerErster = String(heute.prefix(7)) + "-01"
        guard let ziel = Datum.kalender.date(byAdding: .month, value: -monateZurueck, to: Datum.datum(aktuellerErster)) else { return "" }
        let f = DateFormatter()
        f.calendar = Datum.kalender
        f.locale = Locale(identifier: "de_DE")
        f.dateFormat = "MMMM yyyy"
        return f.string(from: ziel)
    }

    private func tagKnopf(_ tag: String) -> some View {
        let an = health.gymAbgehakt(ich, tag)
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            health.setzeGym(datum: tag, an: !an)
        } label: {
            VStack(spacing: 2) {
                Text(String(Int(tag.suffix(2)) ?? 0)).font(.caption)
                if an { Image(systemName: "checkmark.circle.fill").font(.caption2) }
            }
            .frame(width: 40, height: 40)
            // Spec 3.2: "sie werden grün" — bewusst Grün statt Personenfarbe, damit es wie die
            // Jahres-/Monatsübersicht (`HabitVerlaufInhalt`) liest, nicht wie ein Besitz-Merkmal.
            .background(an ? Color.green : Color(uiColor: .tertiarySystemFill), in: RoundedRectangle(cornerRadius: 8))
            .foregroundStyle(an ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(Datum.anzeige(tag)), Gym \(an ? "abgehakt" : "nicht abgehakt")")
        .accessibilityAddTraits(.isButton)
    }
}

struct ZieleAendernView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var schritte: Int
    @State private var gym: Int
    @State private var wasser: Int
    @State private var gemeinsamWoche: Int

    init() {
        let h = HealthModell.shared
        _schritte = State(initialValue: h.zielSchritte())
        _gym = State(initialValue: h.zielGym())
        _wasser = State(initialValue: h.zielWasser())
        _gemeinsamWoche = State(initialValue: h.zielGemeinsamWoche)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Eigene Ziele") {
                    Stepper(value: $schritte, in: 1_000...30_000, step: 500) {
                        Text("Schritte: \(schritte.formatted(.number.locale(Locale(identifier: "de_DE"))))")
                    }
                    Stepper("Gym pro Woche: \(gym)×", value: $gym, in: 1...7)
                    Stepper("Wasser pro Tag: \(wasser) Gläser", value: $wasser, in: 1...20)
                }
                Section("Gemeinsam") {
                    Stepper(value: $gemeinsamWoche, in: 10_000...500_000, step: 10_000) {
                        Text("Wöchentliches Ziel: \(gemeinsamWoche.formatted(.number.locale(Locale(identifier: "de_DE"))))")
                    }
                }
            }
            .navigationTitle("Ziele ändern")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Fertig") { speichern(); dismiss() } }
            }
        }
    }

    private func speichern() {
        let h = HealthModell.shared
        if schritte != h.zielSchritte() { h.setzeZiel("ziel.schritte", schritte) }
        if gym != h.zielGym() { h.setzeZiel("ziel.gym", gym) }
        if wasser != h.zielWasser() { h.setzeZiel("ziel.wasser", wasser) }
        if gemeinsamWoche != h.zielGemeinsamWoche { h.setzeZiel("ziel.gemeinsamWoche", gemeinsamWoche) }
    }
}
