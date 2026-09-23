enum Person: String, Codable, CaseIterable { case ahmed, annika
    var partner: Person { self == .ahmed ? .annika : .ahmed }
    var name: String { self == .ahmed ? "Ahmed" : "Annika" } }
