import CoreLocation
import SwiftUI
import UserNotifications

/// Erster Start auf einem Gerät, vier Schritte (Spec 2). Speichert die Person erst am Ende
/// im Schlüsselbund und setzt `lovea.ersterStartFertig`, danach wird nie wieder gefragt.
struct ErsterStart: View {
    let onFertig: (Person) -> Void

    @State private var step: Int
    @State private var gewaehltePerson: Person?
    @StateObject private var standortAnfrage = StandortAnfrage()

    init(vorausgewaehltePerson: Person? = nil, onFertig: @escaping (Person) -> Void) {
        self.onFertig = onFertig
        _step = State(initialValue: vorausgewaehltePerson == nil ? 1 : 2)
        _gewaehltePerson = State(initialValue: vorausgewaehltePerson)
    }

    var body: some View {
        Group {
            switch step {
            case 1: personSchritt
            case 2: figurSchritt
            case 3: mitteilungenSchritt
            default: standortSchritt
            }
        }
        .padding(28)
        .animation(.default, value: step)
        .onChange(of: standortAnfrage.fertig) { _, fertig in
            guard fertig, let gewaehltePerson else { return }
            UserDefaults.standard.set(true, forKey: "lovea.ersterStartFertig")
            onFertig(gewaehltePerson)
        }
    }

    // MARK: Schritt 1 – Wer bist du?

    private var personSchritt: some View {
        VStack(alignment: .leading, spacing: 32) {
            Spacer()
            VStack(alignment: .leading, spacing: 8) {
                Text("Lovea")
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                Text("Wer bist du?")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            VStack(spacing: 0) {
                ForEach(Person.allCases, id: \.self) { person in
                    Button {
                        gewaehltePerson = person
                        step = 2
                    } label: {
                        HStack {
                            Text(person.name)
                                .font(.title2.weight(.semibold))
                            Spacer()
                            Image(systemName: "arrow.right")
                                .foregroundStyle(.secondary)
                        }
                        .frame(minHeight: 64)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if person != Person.allCases.last { Divider() }
                }
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Schritt 2 – Figur (Platzhalter bis Block 3)

    private var figurSchritt: some View {
        schrittAnsicht(
            symbol: "person.crop.circle.badge.plus",
            titel: "Deine Figur",
            text: "Deine Figur baust du gleich im Profil.",
            knopf: "Weiter"
        ) { step = 3 }
    }

    // MARK: Schritt 3 – Mitteilungen

    private var mitteilungenSchritt: some View {
        schrittAnsicht(
            symbol: "bell.fill",
            titel: "Mitteilungen",
            text: "Lovea meldet euch neue Nachrichten und wichtige Momente.",
            knopf: "Erlauben"
        ) {
            Task {
                _ = try? await UNUserNotificationCenter.current()
                    .requestAuthorization(options: [.alert, .sound, .badge])
                step = 4
            }
        }
    }

    // MARK: Schritt 4 – Standort

    private var standortSchritt: some View {
        schrittAnsicht(
            symbol: "location.fill",
            titel: "Standort",
            text: "Mit \u{201E}Immer\u{201C} zeigt Lovea deinem Partner, wo du bist, auch wenn die App zu ist.",
            knopf: "Erlauben"
        ) { standortAnfrage.anfordern() }
    }

    @ViewBuilder
    private func schrittAnsicht(symbol: String, titel: String, text: String, knopf: String, aktion: @escaping () -> Void) -> some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: symbol)
                .font(.system(size: 56))
                .foregroundStyle(Color.loveaRose)
            Text(titel).font(.largeTitle.bold())
            Text(text)
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
            Button(knopf, action: aktion)
                .buttonStyle(.borderedProminent)
                .frame(minHeight: 44)
        }
        .padding(.horizontal, 8)
    }
}

/// Fragt zuerst "beim Benutzen", danach "immer" an, wie von iOS verlangt.
@MainActor
private final class StandortAnfrage: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var fertig = false

    private var manager: CLLocationManager?
    private var alwaysAngefragt = false

    func anfordern() {
        let manager = CLLocationManager()
        manager.delegate = self
        self.manager = manager
        reagiere(auf: manager.authorizationStatus)
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in self.reagiere(auf: status) }
    }

    private func reagiere(auf status: CLAuthorizationStatus) {
        switch status {
        case .notDetermined:
            manager?.requestWhenInUseAuthorization()
        case .authorizedWhenInUse where !alwaysAngefragt:
            alwaysAngefragt = true
            manager?.requestAlwaysAuthorization()
            // Nicht auf die Always-Antwort warten: bei "Nur bei Verwendung erlauben"
            // bleibt der Status unverändert, es kommt kein weiterer Callback.
            fertig = true
        default:
            fertig = true
        }
    }
}
