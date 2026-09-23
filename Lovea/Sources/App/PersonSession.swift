import Combine
import Foundation

/// Holds the active `Person`, backed by the Keychain so the choice survives a cold start.
@MainActor
final class PersonSession: ObservableObject {
    @Published private(set) var person: Person?

    private let schluesselbund: Schluesselbund

    init(schluesselbund: Schluesselbund = .shared) {
        self.schluesselbund = schluesselbund
        person = schluesselbund.get().flatMap(Person.init(rawValue:))
    }

    /// First start, or "Person wechseln" in Profil → Entwickler.
    func waehlen(_ person: Person) {
        schluesselbund.set(person.rawValue)
        self.person = person
    }
}
