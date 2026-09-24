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
        let daten = (try? encoder.encode(d)) ?? Data("{}".utf8)
        return Op(id: UUID().uuidString, seq: nil, art: art, von: von, zeit: Date(), d: daten)
    }

    func daten<T: Decodable>(_ type: T.Type) -> T? {
        try? Op.decoder.decode(T.self, from: d)
    }

    // ponytail: one shared coder pair instead of one per op (audit #5), same reasoning as the ISO
    // formatters below. Never mutated after creation; encode/decode on an unmutated coder is
    // thread-safe, `nonisolated(unsafe)` only covers a missing Sendable mark.
    private nonisolated(unsafe) static let encoder = JSONEncoder()
    private nonisolated(unsafe) static let decoder = JSONDecoder()

    private enum CodingKeys: String, CodingKey { case id, seq, art, von, zeit, d }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        seq = try c.decodeIfPresent(Int.self, forKey: .seq)
        art = try c.decode(String.self, forKey: .art)
        von = try c.decode(Person.self, forKey: .von)
        zeit = Op.datum(von: try c.decode(String.self, forKey: .zeit))
        if decoder.codingPath.isEmpty, let zeile = decoder.userInfo[Op.zeileSchluessel] as? Data, let roh = Op.rohesD(zeile) {
            d = roh
        } else {
            let wert = try c.decode(JSONValue.self, forKey: .d)
            d = (try? Op.encoder.encode(wert)) ?? Data("{}".utf8)
        }
    }

    /// Audit #1: set to the exact bytes being decoded (one op per document, as in `ops.jsonl`) and
    /// `init(from:)` slices `d` straight out of them instead of rebuilding it via a `JSONValue` tree.
    /// Without it, or when the slice isn't found, the old tree path runs unchanged.
    static let zeileSchluessel = CodingUserInfoKey(rawValue: "lovea.op.zeile")!

    /// The raw bytes of the top-level `"d"` value of one JSON object, nil if there is none. Only
    /// used on bytes the decoder already accepted as valid JSON, so this just tracks strings and depth.
    static func rohesD(_ json: Data) -> Data? {
        let b = [UInt8](json)
        let anfuehrung = UInt8(ascii: "\""), rueckstrich = UInt8(ascii: "\\")
        func leer(_ c: UInt8) -> Bool { c == 0x20 || c == 0x0A || c == 0x0D || c == 0x09 }
        var tiefe = 0
        var start: Int?
        var i = 0
        while i < b.count {
            let c = b[i]
            if c == anfuehrung {
                let anfang = i
                i += 1
                while i < b.count, b[i] != anfuehrung { i += b[i] == rueckstrich ? 2 : 1 }
                // A key at depth 1 spelled exactly "d", followed by a colon: the value starts after it.
                if start == nil, tiefe == 1, i == anfang + 2, b[anfang + 1] == UInt8(ascii: "d") {
                    var j = i + 1
                    while j < b.count, leer(b[j]) { j += 1 }
                    if j < b.count, b[j] == UInt8(ascii: ":") {
                        j += 1
                        while j < b.count, leer(b[j]) { j += 1 }
                        start = j
                        i = j
                        continue
                    }
                }
            } else if c == UInt8(ascii: "{") || c == UInt8(ascii: "[") {
                tiefe += 1
            } else if c == UInt8(ascii: "}") || c == UInt8(ascii: "]") || c == UInt8(ascii: ",") {
                if tiefe == 1, let s = start {
                    var ende = i
                    while ende > s, leer(b[ende - 1]) { ende -= 1 }
                    return ende > s ? Data(b[s..<ende]) : nil
                }
                if c != UInt8(ascii: ",") { tiefe -= 1 }
            }
            i += 1
        }
        return nil
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encodeIfPresent(seq, forKey: .seq)
        try c.encode(art, forKey: .art)
        try c.encode(von, forKey: .von)
        try c.encode(Op.datumString(zeit), forKey: .zeit)
        let wert = (try? Op.decoder.decode(JSONValue.self, from: d)) ?? .object([:])
        try c.encode(wert, forKey: .d)
    }

    // ponytail: two shared formatters instead of one per call. ISO8601DateFormatter is thread-safe
    // (Apple docs, iOS 7+), so `nonisolated(unsafe)` only silences the missing Sendable mark; building
    // one per op made every launch and fold pay for it thousands of times.
    private nonisolated(unsafe) static let isoFraktional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private nonisolated(unsafe) static let isoGanz = ISO8601DateFormatter()

    private static func isoFormatierer(fraktional: Bool) -> ISO8601DateFormatter {
        fraktional ? isoFraktional : isoGanz
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
