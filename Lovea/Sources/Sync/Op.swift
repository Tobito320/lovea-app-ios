import Foundation

/// One synchronized change: chat message, calendar entry, figure gesture, and so on.
/// `d` holds the raw JSON body for `art` and is decoded lazily via `daten(_:)`.
struct Op: Codable, Identifiable, Sendable {
    let id: String
    var seq: Int?
    let art: String
    let von: Person
    let zeit: Date
    let d: Data

    init(id: String, seq: Int?, art: String, von: Person, zeit: Date, d: Data) {
        self.id = id
        self.seq = seq
        self.art = art
        self.von = von
        self.zeit = zeit
        self.d = d
    }

    /// Creates a new, unconfirmed op (`seq == nil`) ready for `Raum.senden`.
    static func neu<T: Encodable>(_ art: String, _ d: T, von: Person) -> Op {
        let daten = (try? JSONEncoder().encode(d)) ?? Data("{}".utf8)
        return Op(id: UUID().uuidString, seq: nil, art: art, von: von, zeit: Date(), d: daten)
    }

    func daten<T: Decodable>(_ type: T.Type) -> T? {
        try? JSONDecoder().decode(T.self, from: d)
    }

    private enum CodingKeys: String, CodingKey { case id, seq, art, von, zeit, d }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        seq = try c.decodeIfPresent(Int.self, forKey: .seq)
        art = try c.decode(String.self, forKey: .art)
        von = try c.decode(Person.self, forKey: .von)
        zeit = Op.datum(von: try c.decode(String.self, forKey: .zeit))
        let wert = try c.decode(JSONValue.self, forKey: .d)
        d = (try? JSONEncoder().encode(wert)) ?? Data("{}".utf8)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encodeIfPresent(seq, forKey: .seq)
        try c.encode(art, forKey: .art)
        try c.encode(von, forKey: .von)
        try c.encode(Op.datumString(zeit), forKey: .zeit)
        let wert = (try? JSONDecoder().decode(JSONValue.self, from: d)) ?? .object([:])
        try c.encode(wert, forKey: .d)
    }

    // Fresh formatter per call: ISO8601DateFormatter is a class and not Sendable,
    // so a shared `static let` would trip Swift 6 strict concurrency.
    private static func isoFormatierer(fraktional: Bool) -> ISO8601DateFormatter {
        let f = ISO8601DateFormatter()
        f.formatOptions = fraktional ? [.withInternetDateTime, .withFractionalSeconds] : [.withInternetDateTime]
        return f
    }

    private static func datumString(_ datum: Date) -> String {
        isoFormatierer(fraktional: true).string(from: datum)
    }

    private static func datum(von text: String) -> Date {
        isoFormatierer(fraktional: true).date(from: text)
            ?? isoFormatierer(fraktional: false).date(from: text)
            ?? Date()
    }
}
