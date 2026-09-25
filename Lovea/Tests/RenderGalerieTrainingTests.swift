import SwiftUI
import UIKit
import XCTest
@testable import Lovea

/// Render board "training": Health card states, the gym screen mid-workout, week strip, day rows
/// and catalog rows with real GIF thumbnails (fetched from ExerciseDB; blank if CI is offline). Light and dark.
@MainActor
final class RenderGalerieTrainingTests: XCTestCase {
    private let t0 = Datum.datum("2026-09-23").addingTimeInterval(18 * 3600 + 5 * 60)

    private func zelle(_ titel: String, _ ansicht: some View, _ schema: ColorScheme = .light, breite: CGFloat = 390) -> (titel: String, ansicht: AnyView) {
        (titel, AnyView(ansicht.frame(width: breite).padding(12).background(Color(uiColor: .systemGroupedBackground)).environment(\.colorScheme, schema)))
    }

    private func pu(_ id: String, _ name: String, _ saetze: [PlanSatz] = [], minuten: Int? = nil) -> PlanUebung {
        PlanUebung(id: id, uebung: PlanUebung.eigen, name: name, saetze: saetze, minuten: minuten)
    }

    private var push: TrainingsTag {
        let drei = { (kg: Double) in Array(repeating: PlanSatz(wdh: 10, kg: kg, failure: false), count: 3) }
        return TrainingsTag(id: "push", name: "Push", wochentage: [1, 3, 5], uebungen: [
            pu("a", "Bankdrücken mit Langhantel", drei(60)),
            pu("b", "Bizeps-Curls mit Kurzhanteln", [PlanSatz(wdh: 12, kg: 12, failure: false), PlanSatz(wdh: 10, kg: 14, failure: false), PlanSatz(wdh: 8, kg: 14, failure: true)]),
            pu("c", "Preacher Curls mit SZ-Stange", drei(25)),
            pu("d", "Kabelturm Fliegende", drei(15)),
            pu("e", "Laufband", minuten: 20),
        ])
    }

    private var laufend: GymSession {
        GymSession(id: "s", tag: "push", start: t0, ende: nil, laeufe: [
            UebungsLauf(plan: "a", uebung: "eigen", start: t0 + 120, ende: t0 + 900, fertig: true, saetze: nil),
            UebungsLauf(plan: "b", uebung: "eigen", start: t0 + 960, ende: nil, fertig: false, saetze: nil),
        ])
    }

    func testTrainingKarte() {
        let jetzt = t0 + 1500
        let staende: [(String, TrainingKartenStand)] = [
            ("Heute Push", TrainingKartenStand(heute: push, planLeer: false, partner: "Annika hat heute Beine", jetzt: jetzt)),
            ("Im Gym", TrainingKartenStand(heute: push, laufend: laufend, laufendTag: push, planLeer: false, partner: "Annika trainiert gerade: Beinstrecker", jetzt: jetzt)),
            ("Ruhetag + vergessen", TrainingKartenStand(heute: nil, vergessen: GymSession(id: "v", tag: "beine", start: t0 - 20 * 3600, ende: nil, laeufe: []), planLeer: false, jetzt: jetzt)),
            ("Kein Plan", TrainingKartenStand(heute: nil, planLeer: true, jetzt: jetzt)),
        ]
        var zellen: [(titel: String, ansicht: AnyView)] = []
        for schema in [ColorScheme.light, .dark] {
            for (titel, stand) in staende {
                zellen.append(zelle("\(titel), \(schema == .light ? "hell" : "dunkel")", TrainingKarteInhalt(stand: stand), schema))
            }
        }
        RenderTafel.speichern("training-karte", spalten: 4, zellen: zellen)
    }

    func testGymSession() {
        let fertig = GymSession(id: "s", tag: "push", start: t0, ende: t0 + 4800, laeufe: push.uebungen.map {
            UebungsLauf(plan: $0.id, uebung: "eigen", start: nil, ende: t0 + 4800, fertig: true, saetze: nil)
        })
        let neu = GymSession(id: "s", tag: "push", start: t0, ende: nil, laeufe: [
            UebungsLauf(plan: "a", uebung: "eigen", start: nil, ende: t0 + 900, fertig: true, saetze: nil),
        ])
        RenderTafel.speichern("training-session", spalten: 4, zellen: [
            zelle("Übung läuft, hell", GymSessionInhalt(session: laufend, tag: push, jetzt: t0 + 1500)),
            zelle("Nächste markiert, dunkel", GymSessionInhalt(session: neu, tag: push, jetzt: t0 + 1000), .dark),
            zelle("Alles fertig, hell", GymSessionInhalt(session: fertig, tag: push, jetzt: t0 + 5000)),
            zelle("Ohne Tag, dunkel", GymSessionInhalt(session: GymSession(id: "x", tag: nil, start: t0, ende: nil, laeufe: []), tag: nil, jetzt: t0 + 600), .dark),
        ])
    }

    func testPlanUndKatalog() {
        let plan = TrainingsPlan(tage: [push, TrainingsTag(id: "beine", name: "Beine", wochentage: [2, 6], uebungen: [pu("x", "Beinstrecker an der Maschine"), pu("y", "Kickbacks am Kabelzug")])])
        let bundle = Bundle(for: FigurenModell.self)
        let katalog = UebungsKatalog.laden(bundle)
        let beispiele = ["barbell bench press", "lever leg extension", "cable kickback", "dumbbell standing biceps curl", "walking on incline treadmill"]
            .compactMap { en in katalog.first { $0.en == en } }
        let bilder = beispiele.map { u in (try? Data(contentsOf: UebungsMedien.quelle.appending(path: "\(u.id).gif"))).flatMap { UIImage(data: $0) } }
        let zeilen = VStack(alignment: .leading, spacing: 10) {
            ForEach(beispiele.indices, id: \.self) { i in UebungZeile(uebung: beispiele[i], bild: bilder[i]) }
        }
        RenderTafel.speichern("training-plan", spalten: 3, zellen: [
            zelle("Woche, hell", WochenLeiste(plan: plan, heute: 3)),
            zelle("Woche, dunkel", WochenLeiste(plan: plan, heute: 3), .dark),
            zelle("Tage", VStack(spacing: 12) { ForEach(plan.tage) { TagZeile(tag: $0) } }),
            zelle("Katalog, hell", zeilen),
            zelle("Katalog, dunkel", zeilen, .dark),
            zelle("Verlauf", VStack(spacing: 8) {
                GymVerlaufZeile(session: laufend, tag: push)
                GymVerlaufZeile(session: GymSession(id: "f", tag: "push", start: t0, ende: t0 + 4800, laeufe: []), tag: push)
            }),
        ])
    }
}
