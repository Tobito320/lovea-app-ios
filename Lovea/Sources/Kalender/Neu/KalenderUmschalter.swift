import SwiftUI

/// Schalter „Neuer Kalender" (Variante C, „Raster und Blatt"), Einstellungen, Standard an.
/// Aus: der Kalender bleibt wie vorher.
enum KalenderNeu {
    static let schluessel = "lovea.kalenderNeu"

    static func an(_ defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: schluessel) as? Bool ?? true
    }
}

/// Die Kalender-Karte auf Home. Der Zweig „aus" ist der alte Karten-Code aus `HomeView`,
/// unverändert. Der Zweig „an" zeigt vorläufig dasselbe: Teil 2 setzt hier `RasterMonat` ein.
struct KalenderKarte: View {
    @Binding var pfad: NavigationPath
    @AppStorage(KalenderNeu.schluessel) private var neu = true

    var body: some View {
        if neu { neueKarte } else { alteKarte }
    }

    // ponytail: Teil 2 ersetzt den Inhalt durch die neue Ansicht.
    private var neueKarte: some View { alteKarte }

    private var alteKarte: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Kalender")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            MonatsAnsicht { tag in
                pfad.append(tag)
            }
            MonatsLegende()
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}

/// Das Ziel eines angetippten Tages (`String`-Navigationsziel auf Home). „Aus" ist die alte
/// `TagesAnsicht`; „an" zeigt vorläufig dieselbe, Teil 2 setzt hier `TagNeu` ein.
struct KalenderTagZiel: View {
    let tag: String
    @AppStorage(KalenderNeu.schluessel) private var neu = true

    var body: some View {
        if neu { neuerTag } else { TagesAnsicht(tag: tag) }
    }

    // ponytail: Teil 2 ersetzt den Inhalt durch `TagNeu`.
    private var neuerTag: some View { TagesAnsicht(tag: tag) }
}
