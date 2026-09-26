# Training: explicit rest days and smart rest-day hints (Task 7)

> **For agentic workers:** follow `docs/superpowers/plans/2026-09-25-training.md` "Global Constraints" (Swift 6 strict concurrency, iOS 26, no compiler here, German UI copy, English code, ponytail). This file adds one task on top of the committed Tasks 2–5. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Every weekday is either a training day or a rest day that the person marked; the app only speaks up when there are too few or too many rest days or they are badly placed, and then offers a concrete one-tap fix.

Ahmed (25.09. evening): "Mir gefällt nicht, wenn etwas ungeplant ist. Ruhetage muss man selber markieren, und die App schlägt vor, aber nur wenn man zu wenige oder zu viele Ruhetage hat oder wenn sie nicht optimal geplant sind."

## Research used (time-boxed, 25.09.2026)

- 1 to 3 rest days a week is the common guideline; health authorities recommend 2 to 3 resistance days a week, about 48 to 72 h apart (PMC6015912). NSCA (Baechle & Earle): at least one, at most three rest days between sessions for the same muscle group.
- Hypertrophy: training each muscle group about 2 times a week beats once (Schoenfeld et al. 2016; Weightology, "Training Frequency for Hypertrophy").
- Back-to-back days are rarely a problem; what matters is not hitting the same muscle hard on consecutive days, and placing rest after the hardest sessions (Stronger by Science, "Is training on back-to-back days bad?", Dec 2025).

## Rules (`RuhetagLogik`)

1. Every weekday is a training day, a rest day, or `offen`. `offen` shows as an orange "?" and then the only hint is "Noch nicht geplant: …".
2. No rest day: hint "Kein Ruhetag …". Fewer than 3 training days: hint "… Ruhetage sind viel …".
3. Placement score = 10 per pair of neighbouring days (So→Mo too) sharing main muscles + 3 per training day beyond 3 in a row. Main muscles of a day = target muscles (`Uebung.muskel`, not "Herz-Kreislauf") of at least two of its exercises (all of them when the day has at most two). Only if a single swap of two weekdays lowers the score does the app name the problem plus "Vorschlag: X auf Tag, Y auf Tag" with an "Übernehmen" button. If no swap helps: no hint (no nagging).

**Files:**
- Create: `Lovea/Sources/Health/Ruhetage.swift`, `Lovea/Tests/RuhetageTests.swift`
- Modify: `Lovea/Sources/Health/Training.swift`, `Lovea/Sources/Health/TrainingsPlanView.swift`, `Lovea/Sources/Health/GymSession.swift`, `Lovea/Tests/RenderGalerieTrainingTests.swift`

**Interfaces:**
- Consumes: `TrainingsPlan`, `TrainingsTag`, `PlanUebung.katalog`, `Uebung.muskel`, `TrainingLogik.wochentageText/wochentagName/tagSetzen`, `TrainingModell.shared.plan/planSichern`, `HabitLogik.wochentagKuerzel`, `HabitFarbe.mint.farbe`, `Haptik`, `.buttonStyle(.federnd)`.
- Produces: `TrainingsPlan.ruhetage: [Int]?`, `enum TagArt { training(TrainingsTag), ruhe, offen }`, `struct PlanHinweis { id, text, tausch: [Int]? }`, `enum RuhetagLogik { art, setzen, tauschen, schwerpunkt, laengsteSerie, wertung, hinweise, besterTausch, problem, tauschText }`, `WochenLeiste(plan:heute:setzen:)`, `PlanHinweisZeile(hinweis:uebernehmen:)`, `TrainingKartenStand.heuteRuhe`, `.planHinweis`.

- [ ] **Step 1: `Lovea/Sources/Health/Training.swift`** — replace the whole `TrainingsPlan` struct (and its doc comment) with

```swift
/// One person's plan, sent whole as `gym.plan` (newest wins). A weekday is a training day, a rest
/// day (`ruhetage`) or still open (`RuhetagLogik`).
struct TrainingsPlan: Codable, Equatable, Sendable {
    var tage: [TrainingsTag]
    /// Weekdays marked as rest days, 1 = Mo … 7 = So. Optional: plans from the first build have none.
    var ruhetage: [Int]? = nil
    static let leer = TrainingsPlan(tage: [])
}
```

and in `TrainingLogik.tagSetzen`, directly after its `for` loop, add

```swift
        p.ruhetage = p.ruhetage.map { ruhe in ruhe.filter { !tag.wochentage.contains($0) } }
```

- [ ] **Step 2: Create `Lovea/Sources/Health/Ruhetage.swift`**

```swift
import Foundation

/// What a weekday is in a plan. Nothing stays silently unplanned: `offen` asks to be decided.
enum TagArt: Equatable, Sendable {
    case training(TrainingsTag), ruhe, offen
}

/// One hint under the week. `tausch` = the two weekdays that swap on "Übernehmen".
struct PlanHinweis: Identifiable, Equatable, Sendable {
    var id: String
    var text: String
    var tausch: [Int]? = nil
}

/// Rest-day rules from the research (docs/superpowers/plans/2026-09-25-training-ruhetage.md): 1 to 3
/// rest days a week, at least 3 training days so every muscle gets about 2 sessions a week, the same
/// main muscles not on two days in a row, not more than 3 training days in a row when the rest days
/// could be spread. The app only speaks when a rule fails, and about placement only when one swap of
/// two weekdays really helps.
enum RuhetagLogik {
    static func art(_ plan: TrainingsPlan, _ w: Int) -> TagArt {
        if let t = plan.tage.first(where: { $0.wochentage.contains(w) }) { return .training(t) }
        return (plan.ruhetage ?? []).contains(w) ? .ruhe : .offen
    }

    /// Weekday `w` becomes training day `tag` (an id), or a rest day when `tag` is nil.
    static func setzen(_ plan: TrainingsPlan, _ w: Int, tag: String?) -> TrainingsPlan {
        var p = plan
        for i in p.tage.indices {
            p.tage[i].wochentage.removeAll { $0 == w }
            if p.tage[i].id == tag { p.tage[i].wochentage = (p.tage[i].wochentage + [w]).sorted() }
        }
        var ruhe = (p.ruhetage ?? []).filter { $0 != w }
        if tag == nil { ruhe = (ruhe + [w]).sorted() }
        p.ruhetage = ruhe
        return p
    }

    /// Swaps what two weekdays are.
    static func tauschen(_ plan: TrainingsPlan, _ a: Int, _ b: Int) -> TrainingsPlan {
        let artA = art(plan, a), artB = art(plan, b)
        return zuweisen(zuweisen(plan, a, artB), b, artA)
    }

    private static func zuweisen(_ plan: TrainingsPlan, _ w: Int, _ art: TagArt) -> TrainingsPlan {
        switch art {
        case .training(let t):
            return setzen(plan, w, tag: t.id)
        case .ruhe:
            return setzen(plan, w, tag: nil)
        case .offen:
            var p = setzen(plan, w, tag: nil)
            p.ruhetage = (p.ruhetage ?? []).filter { $0 != w }
            return p
        }
    }

    /// Main muscles of a day: target muscles of at least two of its exercises (all of them on a day
    /// with one or two). Cardio ("Herz-Kreislauf") and own exercises don't count.
    static func schwerpunkt(_ tag: TrainingsTag) -> Set<String> {
        let muskeln = tag.uebungen.compactMap { $0.katalog?.muskel }.filter { $0 != "Herz-Kreislauf" }
        guard muskeln.count > 2 else { return Set(muskeln) }
        var zahl: [String: Int] = [:]
        for m in muskeln { zahl[m, default: 0] += 1 }
        return Set(zahl.filter { $0.value >= 2 }.keys)
    }

    private static func istTraining(_ plan: TrainingsPlan, _ w: Int) -> Bool {
        if case .training = art(plan, w) { return true }
        return false
    }

    /// Longest run of training days, across the week's end too (7 when every day is training).
    static func laengsteSerie(_ plan: TrainingsPlan) -> Int {
        let training = (1...7).map { istTraining(plan, $0) }
        if !training.contains(false) { return 7 }
        var beste = 0, lauf = 0
        for i in 0..<14 {
            lauf = training[i % 7] ? lauf + 1 : 0
            beste = max(beste, lauf)
        }
        return beste
    }

    /// Lower is better: 10 per pair of neighbouring days (So→Mo too) sharing main muscles, 3 per
    /// training day beyond 3 in a row.
    static func wertung(_ plan: TrainingsPlan, schwerpunkt: (TrainingsTag) -> Set<String> = schwerpunkt) -> Int {
        var punkte = 0
        for w in 1...7 {
            if case .training(let a) = art(plan, w), case .training(let b) = art(plan, w % 7 + 1),
               !schwerpunkt(a).isDisjoint(with: schwerpunkt(b)) {
                punkte += 10
            }
        }
        return punkte + max(0, laengsteSerie(plan) - 3) * 3
    }

    /// The hints for a plan, empty when everything is fine.
    static func hinweise(_ plan: TrainingsPlan, schwerpunkt: (TrainingsTag) -> Set<String> = schwerpunkt) -> [PlanHinweis] {
        guard !plan.tage.isEmpty else { return [] }
        let offen = (1...7).filter { art(plan, $0) == .offen }
        if !offen.isEmpty {
            return [PlanHinweis(id: "offen", text: "Noch nicht geplant: \(TrainingLogik.wochentageText(offen)). Tipp auf den Tag und leg Training oder Ruhetag fest.")]
        }
        let ruhe = (1...7).filter { art(plan, $0) == .ruhe }.count
        if ruhe == 0 {
            return [PlanHinweis(id: "zuWenig", text: "Kein Ruhetag in der Woche. 1 bis 3 Ruhetage geben deinen Muskeln Zeit, stärker zu werden.")]
        }
        if 7 - ruhe < 3 {
            return [PlanHinweis(id: "zuViel", text: "\(ruhe) Ruhetage sind viel. Mit 3 bis 4 Trainingstagen kommt jede Muskelgruppe 2-mal pro Woche dran, das bringt am meisten.")]
        }
        guard let tausch = besterTausch(plan, schwerpunkt: schwerpunkt) else { return [] }
        let text = "\(problem(plan, schwerpunkt: schwerpunkt)) Vorschlag: \(tauschText(plan, tausch.a, tausch.b))."
        return [PlanHinweis(id: "verteilung", text: text, tausch: [tausch.a, tausch.b])]
    }

    /// The one swap of two weekdays that lowers `wertung` the most; nil when no swap helps.
    static func besterTausch(_ plan: TrainingsPlan, schwerpunkt: (TrainingsTag) -> Set<String>) -> (a: Int, b: Int)? {
        let jetzt = wertung(plan, schwerpunkt: schwerpunkt)
        guard jetzt > 0 else { return nil }
        var beste: (a: Int, b: Int, wert: Int)?
        for a in 1...6 {
            for b in (a + 1)...7 where art(plan, a) != art(plan, b) {
                let wert = wertung(tauschen(plan, a, b), schwerpunkt: schwerpunkt)
                if wert < (beste?.wert ?? jetzt) { beste = (a, b, wert) }
            }
        }
        return beste.map { ($0.a, $0.b) }
    }

    /// The first placement problem, in words.
    static func problem(_ plan: TrainingsPlan, schwerpunkt: (TrainingsTag) -> Set<String>) -> String {
        for w in 1...7 {
            let n = w % 7 + 1
            guard case .training(let a) = art(plan, w), case .training(let b) = art(plan, n) else { continue }
            let gleich = schwerpunkt(a).intersection(schwerpunkt(b)).sorted()
            if !gleich.isEmpty {
                return "\(gleich.joined(separator: " und ")) kommt am \(TrainingLogik.wochentagName[w - 1]) und gleich wieder am \(TrainingLogik.wochentagName[n - 1]) dran, dazwischen braucht der Muskel Erholung."
            }
        }
        return "\(laengsteSerie(plan)) Trainingstage am Stück ohne Pause."
    }

    /// "Ruhetag auf Dienstag, Beine auf Mittwoch".
    static func tauschText(_ plan: TrainingsPlan, _ a: Int, _ b: Int) -> String {
        "\(name(art(plan, b))) auf \(TrainingLogik.wochentagName[a - 1]), \(name(art(plan, a))) auf \(TrainingLogik.wochentagName[b - 1])"
    }

    private static func name(_ art: TagArt) -> String {
        switch art {
        case .training(let t): return t.name.isEmpty ? "Training" : t.name
        case .ruhe: return "Ruhetag"
        case .offen: return "offen"
        }
    }
}
```

- [ ] **Step 3: Create `Lovea/Tests/RuhetageTests.swift`**

```swift
import XCTest
@testable import Lovea

final class RuhetageTests: XCTestCase {
    /// Main muscles by day name, so the tests don't need the bundled catalog.
    private let muskeln: [String: Set<String>] = [
        "Push": ["Brust", "Trizeps"], "Push2": ["Brust", "Schultern"], "Pull": ["Latissimus", "Bizeps"],
        "Beine": ["Quadrizeps", "Po"], "Beine2": ["Beinbeuger", "Waden"], "Core": ["Bauch"],
    ]

    private func schwerpunkt(_ t: TrainingsTag) -> Set<String> { muskeln[t.name] ?? [] }

    private func tag(_ name: String, _ tage: [Int]) -> TrainingsTag {
        TrainingsTag(id: name, name: name, wochentage: tage, uebungen: [])
    }

    private func hinweise(_ plan: TrainingsPlan) -> [PlanHinweis] { RuhetagLogik.hinweise(plan, schwerpunkt: schwerpunkt) }
    private func wertung(_ plan: TrainingsPlan) -> Int { RuhetagLogik.wertung(plan, schwerpunkt: schwerpunkt) }

    func testUnplannedDaysAreNamedFirst() {
        let plan = TrainingsPlan(tage: [tag("Push", [1, 3, 5])], ruhetage: [2])
        let h = hinweise(plan)
        XCTAssertEqual(h.map(\.id), ["offen"])
        XCTAssertTrue(h[0].text.contains("Do, Sa, So"))
        XCTAssertEqual(RuhetagLogik.art(plan, 2), .ruhe)
        XCTAssertEqual(RuhetagLogik.art(plan, 4), .offen)
        XCTAssertTrue(hinweise(.leer).isEmpty)
    }

    func testTooFewAndTooManyRestDays() {
        let keinRuhetag = TrainingsPlan(tage: [tag("Push", [1, 4]), tag("Pull", [2, 5]), tag("Beine", [3, 6]), tag("Core", [7])])
        XCTAssertEqual(hinweise(keinRuhetag).map(\.id), ["zuWenig"])
        let zweiTage = TrainingsPlan(tage: [tag("Push", [1]), tag("Beine", [4])], ruhetage: [2, 3, 5, 6, 7])
        XCTAssertEqual(hinweise(zweiTage).map(\.id), ["zuViel"])
    }

    func testGoodWeekHasNoHint() {
        let plan = TrainingsPlan(tage: [tag("Push", [1, 5]), tag("Pull", [2, 6]), tag("Beine", [4])], ruhetage: [3, 7])
        XCTAssertEqual(wertung(plan), 0)
        XCTAssertTrue(hinweise(plan).isEmpty)
    }

    func testSameMusclesOnNeighbouringDaysGetASwapThatFixesIt() throws {
        let plan = TrainingsPlan(tage: [tag("Push", [1]), tag("Push2", [2]), tag("Beine", [4])], ruhetage: [3, 5, 6, 7])
        XCTAssertEqual(wertung(plan), 10)
        let h = hinweise(plan)
        XCTAssertEqual(h.map(\.id), ["verteilung"])
        XCTAssertTrue(h[0].text.contains("Brust"))
        XCTAssertTrue(h[0].text.contains("Vorschlag:"))
        let t = try XCTUnwrap(h[0].tausch)
        XCTAssertEqual(wertung(RuhetagLogik.tauschen(plan, t[0], t[1])), 0)
    }

    func testLongStreakGetsSpreadWhenPossible() throws {
        let plan = TrainingsPlan(tage: [tag("Push", [1]), tag("Pull", [2]), tag("Beine", [3]), tag("Core", [4])], ruhetage: [5, 6, 7])
        XCTAssertEqual(RuhetagLogik.laengsteSerie(plan), 4)
        let h = hinweise(plan)
        XCTAssertEqual(h.map(\.id), ["verteilung"])
        let t = try XCTUnwrap(h[0].tausch)
        XCTAssertLessThanOrEqual(RuhetagLogik.laengsteSerie(RuhetagLogik.tauschen(plan, t[0], t[1])), 3)
    }

    func testNoNaggingWhenNoSwapHelps() {
        // Six training days with pairwise different main muscles and one rest day: every
        // arrangement leaves a run of 6, so no swap lowers the score.
        let plan = TrainingsPlan(
            tage: [tag("Push", [1]), tag("Pull", [2]), tag("Beine", [3]), tag("Core", [4]), tag("Beine2", [5]), tag("Push2", [6])],
            ruhetage: [7]
        )
        XCTAssertEqual(RuhetagLogik.laengsteSerie(plan), 6)
        XCTAssertTrue(hinweise(plan).isEmpty)
    }

    func testSetAndSwapKeepEveryWeekdayInOnePlace() {
        var plan = TrainingsPlan(tage: [tag("Push", [1, 3]), tag("Beine", [5])], ruhetage: [2])
        plan = RuhetagLogik.setzen(plan, 3, tag: nil)
        XCTAssertEqual(plan.tage[0].wochentage, [1])
        XCTAssertEqual(plan.ruhetage, [2, 3])
        plan = RuhetagLogik.setzen(plan, 2, tag: "Beine")
        XCTAssertEqual(plan.tage[1].wochentage, [2, 5])
        XCTAssertEqual(plan.ruhetage, [3])
        plan = RuhetagLogik.tauschen(plan, 1, 3)
        XCTAssertEqual(RuhetagLogik.art(plan, 1), .ruhe)
        XCTAssertEqual(RuhetagLogik.art(plan, 3), .training(plan.tage[0]))
        let mitTag = TrainingLogik.tagSetzen(plan, TrainingsTag(id: "Pull", name: "Pull", wochentage: [1], uebungen: []))
        XCTAssertEqual(RuhetagLogik.art(mitTag, 1), .training(mitTag.tage[2]))
        XCTAssertEqual(mitTag.ruhetage, [])
    }

    func testOldPlanWithoutRestDaysDecodes() throws {
        let plan = try JSONDecoder().decode(TrainingsPlan.self, from: Data(#"{"tage":[]}"#.utf8))
        XCTAssertNil(plan.ruhetage)
    }
}
```

Why the expectations hold:
- `testGoodWeekHasNoHint`: Push/Pull/Ruhe/Beine/Push/Pull/Ruhe has no neighbouring main muscles and runs of at most 3.
- `testLongStreakGetsSpreadWhenPossible`: Mo–Do training, Fr–So rest; swapping Do with Fr gives Mo–Mi, rest, Fr: longest run 3, score 0.
- `testSameMuscles…`: Push (Brust) Mo and Push2 (Brust) Di score 10; e.g. swapping Di with Mi puts a rest day between them, score 0.

- [ ] **Step 4: `Lovea/Sources/Health/TrainingsPlanView.swift`**

In `TrainingsPlanView.body` replace

```swift
            Section {
                WochenLeiste(plan: plan)
            } header: {
                Text("Woche")
            } footer: {
                Text("Tage ohne Training sind Ruhetage.")
            }
```

with

```swift
            Section {
                WochenLeiste(plan: plan, setzen: eigener ? setzenAktion(plan) : nil)
            } header: {
                Text("Woche")
            } footer: {
                Text(eigener ? "Tipp auf einen Tag: Training oder Ruhetag." : "")
            }
            if eigener { hinweise(plan) }
```

Add these members to `TrainingsPlanView` (next to `loeschenAktion`):

```swift
    @ViewBuilder
    private func hinweise(_ plan: TrainingsPlan) -> some View {
        let liste = RuhetagLogik.hinweise(plan)
        if !liste.isEmpty {
            Section("Vorschlag") {
                ForEach(liste) { h in
                    PlanHinweisZeile(hinweis: h) { uebernehmen(h, plan) }
                }
            }
        }
    }

    private func setzenAktion(_ plan: TrainingsPlan) -> (Int, String?) -> Void {
        { w, tag in
            modell.planSichern(RuhetagLogik.setzen(plan, w, tag: tag))
            Haptik.auswahl()
        }
    }

    private func uebernehmen(_ h: PlanHinweis, _ plan: TrainingsPlan) {
        guard let t = h.tausch, t.count == 2 else { return }
        modell.planSichern(RuhetagLogik.tauschen(plan, t[0], t[1]))
        Haptik.erfolg()
    }
```

Replace the whole `WochenLeiste` struct (and its doc comment) with:

```swift
/// Mo to So: the training day's name, "Ruhe", or an orange "?" while still open. Own plan: tapping
/// a day opens a menu to make it a training day or a rest day.
struct WochenLeiste: View {
    let plan: TrainingsPlan
    var heute: Int = Datum.wochentag(Datum.text(Date()))
    var setzen: ((Int, String?) -> Void)? = nil

    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...7, id: \.self) { w in spalte(w) }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func spalte(_ w: Int) -> some View {
        if let setzen {
            Menu {
                menue(w, setzen)
            } label: {
                inhalt(w)
            }
            .accessibilityHint("Training oder Ruhetag festlegen")
        } else {
            inhalt(w)
        }
    }

    @ViewBuilder
    private func menue(_ w: Int, _ aktion: @escaping (Int, String?) -> Void) -> some View {
        ForEach(plan.tage) { t in
            Button(t.name.isEmpty ? "Ohne Namen" : t.name, systemImage: "dumbbell") { aktion(w, t.id) }
        }
        Button("Ruhetag", systemImage: "bed.double") { aktion(w, nil) }
    }

    private func inhalt(_ w: Int) -> some View {
        let art = RuhetagLogik.art(plan, w)
        let form = RoundedRectangle(cornerRadius: 8, style: .continuous)
        return VStack(spacing: 4) {
            Text(HabitLogik.wochentagKuerzel[w - 1])
                .font(.caption.weight(w == heute ? .bold : .semibold))
                .foregroundStyle(w == heute ? Color.primary : Color.secondary)
            Text(titel(art))
                .font(.caption2.weight(.medium))
                .foregroundStyle(Color.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, 2)
                .frame(maxWidth: .infinity, minHeight: 34)
                .background(form.fill(farbe(art)))
                .overlay {
                    if art == .offen { form.strokeBorder(Color.orange, style: StrokeStyle(lineWidth: 1, dash: [3, 2])) }
                }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(TrainingLogik.wochentagName[w - 1]): \(beschreibung(art))")
    }

    private func titel(_ art: TagArt) -> String {
        switch art {
        case .training(let t): return t.name.isEmpty ? "Training" : t.name
        case .ruhe: return "Ruhe"
        case .offen: return "?"
        }
    }

    private func beschreibung(_ art: TagArt) -> String {
        switch art {
        case .training(let t): return t.name.isEmpty ? "Training" : t.name
        case .ruhe: return "Ruhetag"
        case .offen: return "noch nicht geplant"
        }
    }

    private func farbe(_ art: TagArt) -> Color {
        switch art {
        case .training: return HabitFarbe.mint.farbe.opacity(0.25)
        case .ruhe: return Color(uiColor: .tertiarySystemFill)
        case .offen: return Color.orange.opacity(0.15)
        }
    }
}

/// A rest-day hint with the lightbulb; "Übernehmen" when it carries a swap.
struct PlanHinweisZeile: View {
    let hinweis: PlanHinweis
    var uebernehmen: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label {
                Text(hinweis.text).font(.subheadline)
            } icon: {
                Image(systemName: "lightbulb.fill").foregroundStyle(Color.yellow)
            }
            if hinweis.tausch != nil {
                Button("Übernehmen", action: uebernehmen)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
        }
        .padding(.vertical, 4)
    }
}
```

- [ ] **Step 5: `Lovea/Sources/Health/GymSession.swift`**

In `TrainingKartenStand`, directly after `var planLeer: Bool`, add

```swift
    var heuteRuhe = false
    var planHinweis: String? = nil
```

Replace the body of `TrainingKarte.stand(_:)` with

```swift
        let laufend = modell.laufende(ich, jetzt: jetzt)
        let plan = modell.plan(ich)
        return TrainingKartenStand(
            heute: modell.heutigerTag(ich), laufend: laufend, laufendTag: modell.tag(ich, id: laufend?.tag),
            vergessen: modell.vergessene(ich, jetzt: jetzt), planLeer: plan.tage.isEmpty,
            heuteRuhe: RuhetagLogik.art(plan, Datum.wochentag(Datum.text(jetzt))) == .ruhe,
            planHinweis: RuhetagLogik.hinweise(plan).first?.text,
            partner: partnerText(jetzt), jetzt: jetzt
        )
```

In `TrainingKarteInhalt.bereit`, insert directly before `Button(action: aktionen.einchecken) {`:

```swift
            if let hinweis = stand.planHinweis {
                Button(action: aktionen.plan) {
                    Label {
                        Text(hinweis).font(.footnote).multilineTextAlignment(.leading)
                    } icon: {
                        Image(systemName: "lightbulb.fill").foregroundStyle(Color.yellow)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(.rect)
                }
                .buttonStyle(.federnd)
                .foregroundStyle(Color.primary)
                .accessibilityHint("Öffnet den Trainingsplan")
            }
```

In `heuteText` replace `guard let t = stand.heute else { return "Heute ist Ruhetag" }` with

```swift
        guard let t = stand.heute else { return stand.heuteRuhe ? "Heute ist Ruhetag" : "Heute ist noch nicht geplant" }
```

- [ ] **Step 6: Render board `Lovea/Tests/RenderGalerieTrainingTests.swift`**
  - `testTrainingKarte`: in the third state ("Ruhetag + vergessen") add `heuteRuhe: true` right after `planLeer: false` (argument order: heute, laufend, laufendTag, vergessen, planLeer, heuteRuhe, planHinweis, partner, jetzt). Add a fifth state: `("Plan-Tipp", TrainingKartenStand(heute: push, planLeer: false, planHinweis: "Brust kommt am Montag und gleich wieder am Dienstag dran, dazwischen braucht der Muskel Erholung. Vorschlag: Ruhetag auf Dienstag, Push auf Mittwoch.", jetzt: jetzt))`. Change that board's `spalten: 4` to `spalten: 5`.
  - `testPlanUndKatalog`: make the plan `TrainingsPlan(tage: [push, TrainingsTag(id: "beine", …same…)], ruhetage: [4, 7])` and add two cells to its board: `zelle("Woche mit offenen Tagen", WochenLeiste(plan: TrainingsPlan(tage: [push], ruhetage: [2]), heute: 3))` and `zelle("Vorschlag", PlanHinweisZeile(hinweis: PlanHinweis(id: "v", text: "Brust kommt am Montag und gleich wieder am Dienstag dran, dazwischen braucht der Muskel Erholung. Vorschlag: Ruhetag auf Dienstag, Push auf Mittwoch.", tausch: [2, 3])))`.

- [ ] **Step 7: Self-check and commit**

Grep that every `TrainingKartenStand(` call site still uses the declared argument order, that `WochenLeiste(` call sites compile (`plan:`, optional `heute:`, optional `setzen:`), and that `TagArt` equality uses only `.ruhe`/`.offen`/`.training(tag)`.

```bash
git add Lovea/Sources/Health/Ruhetage.swift Lovea/Sources/Health/Training.swift Lovea/Sources/Health/TrainingsPlanView.swift Lovea/Sources/Health/GymSession.swift Lovea/Tests/RuhetageTests.swift Lovea/Tests/RenderGalerieTrainingTests.swift docs/superpowers/plans/2026-09-25-training-ruhetage.md
git commit -m "Training: explicit rest days, smart rest-day hints with one-tap swap

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```
