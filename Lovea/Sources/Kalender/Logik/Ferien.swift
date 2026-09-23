import Foundation

struct Ferienzeitraum: Hashable {
    let von: String // yyyy-MM-dd, einschließlich
    let bis: String // yyyy-MM-dd, einschließlich
    let name: String
}

/// Schulferien Nordrhein-Westfalen.
///
/// Quelle: BASS 12-65 Nr. 1 „Ordnung der Ferien für die Schuljahre 2024/2025 bis 2029/2030“,
/// https://bass.schule.nrw/19662.htm , bestätigt über
/// https://www.schulministerium.nrw/service/ferienordnung-fuer-nordrhein-westfalen-fuer-die-schuljahre-bis-202930
/// Stand: 23.09.2026. Pfingsten ist in NRW nur ein einzelner beweglicher Ferientag (Pfingstdienstag);
/// im Schuljahr 2027/28 gibt es keinen. Deckt jedes Kalenderdatum 2026 bis 2028 ab (inkl. der
/// Sommer-/Herbst-/Weihnachtsferien 2028, die zum Schuljahr 2028/29 gehören).
enum Ferien {
    static let nrw: [Ferienzeitraum] = [
        Ferienzeitraum(von: "2026-03-30", bis: "2026-04-11", name: "Osterferien"),
        Ferienzeitraum(von: "2026-05-26", bis: "2026-05-26", name: "Pfingsten"),
        Ferienzeitraum(von: "2026-07-20", bis: "2026-09-01", name: "Sommerferien"),
        Ferienzeitraum(von: "2026-10-17", bis: "2026-10-31", name: "Herbstferien"),
        Ferienzeitraum(von: "2026-12-23", bis: "2027-01-06", name: "Weihnachtsferien"),
        Ferienzeitraum(von: "2027-03-22", bis: "2027-04-03", name: "Osterferien"),
        Ferienzeitraum(von: "2027-05-18", bis: "2027-05-18", name: "Pfingsten"),
        Ferienzeitraum(von: "2027-07-19", bis: "2027-08-31", name: "Sommerferien"),
        Ferienzeitraum(von: "2027-10-23", bis: "2027-11-06", name: "Herbstferien"),
        Ferienzeitraum(von: "2027-12-24", bis: "2028-01-08", name: "Weihnachtsferien"),
        Ferienzeitraum(von: "2028-04-10", bis: "2028-04-22", name: "Osterferien"),
        Ferienzeitraum(von: "2028-07-10", bis: "2028-08-22", name: "Sommerferien"),
        Ferienzeitraum(von: "2028-10-23", bis: "2028-11-04", name: "Herbstferien"),
        Ferienzeitraum(von: "2028-12-21", bis: "2029-01-05", name: "Weihnachtsferien"),
    ]

    static func istFerien(_ tag: String) -> Bool {
        nrw.contains { $0.von <= tag && tag <= $0.bis }
    }
}
