import Foundation

/// Z-31.2: relative time for the whole app (Spec 2.11). Clocks of two phones differ a little, so
/// the future and the last minute read "gerade eben", never "in 0 Sek.". Calendar days in Europe/Berlin.
enum ZeitText {
    static func relativ(_ datum: Date, jetzt: Date = Date()) -> String {
        if jetzt.timeIntervalSince(datum) < 60 { return "gerade eben" }
        let calendar = Calendar.berlin
        let day = calendar.startOfDay(for: datum)
        let today = calendar.startOfDay(for: jetzt)
        let days = calendar.dateComponents([.day], from: day, to: today).day ?? 0
        if days == 1 { return "gestern" }
        // ponytail: one formatter per call (not Sendable, so no shared static); cache it if it ever shows up in a profile.
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.calendar = calendar
        // Same day: "vor 5 Minuten", "vor 2 Stunden". Older: whole days, so 2 calendar days never read "vor 1 Tag".
        return days == 0
            ? formatter.localizedString(for: datum, relativeTo: jetzt)
            : formatter.localizedString(for: day, relativeTo: today)
    }
}
