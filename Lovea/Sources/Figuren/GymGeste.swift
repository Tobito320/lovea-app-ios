import Foundation

/// Teil 4: what the full-body figure does in the gym. Mapped from the running exercise
/// (`TrainingModell.aktiveUebung`, an ExerciseDB id) or picked at random per person.
enum GymGeste: String, CaseIterable, Sendable {
    case bank, curls, preacher, kabelzug, schulterdruecken, laufband
    case beinKabel, beinstrecker, kniebeuge, ausfallschritt, wadenheben
    case pause

    static let ahmed: [GymGeste] = [.bank, .curls, .preacher, .kabelzug, .schulterdruecken, .laufband]
    static let annika: [GymGeste] = [.beinKabel, .beinstrecker, .kniebeuge, .ausfallschritt, .wadenheben, .laufband]

    /// Seconds per random slot.
    static let slot: Double = 30

    /// Random pick while no exercise runs: a new one every 30 s, every 5th slot a break.
    /// `t` is the figure clock (seconds since reference date).
    static func zufall(_ person: Person, t: Double) -> GymGeste {
        let liste = person == .annika ? annika : ahmed
        let n = Int((t / slot).rounded(.down))
        if n % 5 == 4 { return .pause }
        // ponytail: fixed stride instead of a seeded RNG; looks random enough at 30 s per slot.
        return liste[((n % liste.count) * 7 + n / liste.count) % liste.count]
    }

    static func fuer(id: String?) -> GymGeste? {
        fuer(id.flatMap { UebungsKatalog.nachId[$0] })
    }

    /// Catalog exercise to gesture by English name, equipment and body part. nil = no good match (random).
    static func fuer(_ u: Uebung?) -> GymGeste? {
        guard let u else { return nil }
        let en = u.en.lowercased()
        let hat: (String) -> Bool = { en.contains($0) }
        let beine = ["Beine", "Waden"].contains(u.koerper)
        if u.istCardio || hat("treadmill") { return .laufband }
        if hat("preacher") { return .preacher }
        if hat("leg extension") || hat("leg curl") { return .beinstrecker }
        if u.geraet == "Kabelzug" && beine { return .beinKabel }
        if hat("squat") && !hat("split") { return .kniebeuge }
        if hat("lunge") || hat("split squat") || hat("step up") || hat("step-up") { return .ausfallschritt }
        if hat("calf") || u.koerper == "Waden" { return .wadenheben }
        if u.geraet == "Kabelzug" { return .kabelzug }
        if u.koerper == "Brust" { return .bank }
        if hat("curl") && ["Arme", "Unterarme"].contains(u.koerper) { return .curls }
        if u.koerper == "Schultern" { return .schulterdruecken }
        if u.koerper == "Beine" { return .kniebeuge }
        if ["Arme", "Unterarme"].contains(u.koerper) { return .curls }
        if u.koerper == "Rücken" { return .kabelzug }
        return nil
    }
}
