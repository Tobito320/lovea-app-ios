import SwiftUI

/// Home in der Reihenfolge aus Spec 8.1: Nächstes Treffen, Wie geht's dir heute, Frage des
/// Tages, Pünktlich-Karte (nur wenn fällig), Kalendermonat, Date-Ideen (mit Würfel und Wunschliste).
struct HomeView: View {
    let person: Person
    @State private var pfad = NavigationPath()

    var body: some View {
        NavigationStack(path: $pfad) {
            ScrollView {
                VStack(spacing: 16) {
                    NaechstesTreffenCard()
                    GrussKnopfCard()
                    HeuteVorCard()
                    WieGehtsDirCard()
                    SchritteDuellCard()
                    FrageDesTagesCard()
                    PuenktlichCard()
                    KalenderKarte(pfad: $pfad)
                    DatesKarte()
                }
                .padding(16)
            }
            // R6: nur hier (Wurzel des Tabs), nicht auf TagesAnsicht/FrageDesTagesView dahinter.
            .tabWischen(vorheriger: nil, naechster: "chat")
            .navigationTitle("Home")
            .navigationDestination(for: String.self) { tag in KalenderTagZiel(tag: tag) }
            .navigationDestination(for: FrageZiel.self) { _ in FrageDesTagesView() }
        }
    }
}
