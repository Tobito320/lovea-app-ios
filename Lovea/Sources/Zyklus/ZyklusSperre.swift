import LocalAuthentication
import Observation
import SwiftUI

enum ZyklusSperreLogik {
    /// Annika: an. Ahmed (Testdaten): aus.
    static func standardAn(_ person: Person) -> Bool { person == .annika }

    static func schluessel(_ person: Person) -> String { "lovea.zyklus.sperre.\(person.rawValue)" }

    static func gesperrt(aktiv: Bool, entsperrt: Bool) -> Bool { aktiv && !entsperrt }
}

/// Face ID oder Gerätecode vor dem Zyklus. Die Prüfung kommt als Closure, damit Tests ohne Gerät laufen.
@MainActor
@Observable
final class ZyklusSperre {
    private let person: Person
    private let defaults: UserDefaults
    private let pruefer: () async -> Bool

    var aktiv: Bool {
        didSet {
            defaults.set(aktiv, forKey: ZyklusSperreLogik.schluessel(person))
            if !aktiv { entsperrt = false }
        }
    }
    private(set) var entsperrt = false
    private(set) var pruefungLaeuft = false

    var gesperrt: Bool { ZyklusSperreLogik.gesperrt(aktiv: aktiv, entsperrt: entsperrt) }

    init(person: Person, defaults: UserDefaults = .standard, pruefer: @escaping () async -> Bool = ZyklusSperre.systemPruefung) {
        self.person = person
        self.defaults = defaults
        self.pruefer = pruefer
        let key = ZyklusSperreLogik.schluessel(person)
        aktiv = defaults.object(forKey: key) == nil ? ZyklusSperreLogik.standardAn(person) : defaults.bool(forKey: key)
    }

    func entsperren() async {
        guard gesperrt, !pruefungLaeuft else { return }
        pruefungLaeuft = true
        let ok = await pruefer()
        pruefungLaeuft = false
        if ok { entsperrt = true }
    }

    func sperren() { entsperrt = false }

    static func systemPruefung() async -> Bool {
        let kontext = LAContext()
        var fehler: NSError?
        guard kontext.canEvaluatePolicy(.deviceOwnerAuthentication, error: &fehler) else { return false }
        return (try? await kontext.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Dein Zyklus bleibt privat.")) ?? false
    }
}

struct ZyklusSperreAnsicht: View {
    let sperre: ZyklusSperre
    @Environment(\.colorScheme) private var schema

    var body: some View {
        ZStack {
            ZyklusHintergrund()
            VStack(spacing: 18) {
                ZyklusHerzForm().fill(ZyklusFarbe.himbeere.farbe(schema)).frame(width: 44, height: 44)
                Text("Nur für dich")
                    .font(.system(.title2, design: .rounded).weight(.heavy))
                    .foregroundStyle(ZyklusFarbe.tinte(schema))
                Text("Entsperre mit Face ID oder Code.")
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(ZyklusFarbe.tinteLeise(schema))
                    .multilineTextAlignment(.center)
                ZyklusKnopf(titel: "Entsperren", symbol: "lock.open.fill") {
                    Task { await sperre.entsperren() }
                }
                .padding(.horizontal, 40)
            }
            .padding(24)
        }
        .task { await sperre.entsperren() }
    }
}
