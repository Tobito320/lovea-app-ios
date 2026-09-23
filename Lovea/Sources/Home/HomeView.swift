import SwiftUI

/// Home in der Reihenfolge aus Spec 8.1: Nächstes Treffen, Wie geht's dir heute, Frage des
/// Tages, Pünktlich-Karte (nur wenn fällig), Kalendermonat, Unsere Liste und Würfel.
struct HomeView: View {
    let person: Person
    @State private var pfad = NavigationPath()

    var body: some View {
        NavigationStack(path: $pfad) {
            ScrollView {
                VStack(spacing: 16) {
                    NaechstesTreffenCard()
                    WieGehtsDirCard()
                    FrageDesTagesCard()
                    PuenktlichCard()
                    kalenderKarte
                    UnsereListeCard()
                }
                .padding(16)
            }
            .navigationTitle("Home")
            .navigationDestination(for: String.self) { tag in TagesAnsicht(tag: tag) }
            .navigationDestination(for: FrageZiel.self) { _ in FrageDesTagesView() }
        }
    }

    private var kalenderKarte: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Kalender")
                .font(.headline)
            MonatsAnsicht { tag in
                pfad.append(tag)
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}
