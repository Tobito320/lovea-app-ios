import SwiftUI

extension EnvironmentValues {
    /// Global bottom edge of the conversation: own bubbles cut their gradient out of 0…this.
    @Entry var chatVerlaufHoehe: CGFloat = 900
    /// Width of the conversation, for the 70 % photo cap (Z-33.4).
    @Entry var chatBreite: CGFloat = 390
    /// Fixed backdrop for render boards; nil = the chosen one (`Backdrops.aktuell`).
    @Entry var chatBackdrop: Backdrop? = nil
}

/// Z-32.4: iMessage bubble. Continuous rounding; on the last bubble of a group a tail at the
/// bottom corner of the sender's side. Every bubble keeps `schwanzBreite` free on that side, so
/// a group lines up whether or not a bubble has the tail.
struct BlasenForm: Shape {
    static let schwanzBreite: CGFloat = 6
    var schwanz: Bool
    var rechts: Bool

    func path(in rect: CGRect) -> Path {
        let t = Self.schwanzBreite
        let koerper = CGRect(x: rechts ? rect.minX : rect.minX + t, y: rect.minY, width: max(rect.width - t, 0), height: rect.height)
        let radius = min(18, koerper.height / 2)
        let rund = Path(roundedRect: koerper, cornerRadius: radius, style: .continuous)
        guard schwanz else { return rund }
        let kante = rechts ? koerper.maxX : koerper.minX
        let s: CGFloat = rechts ? 1 : -1
        let unten = rect.maxY
        var zipfel = Path()
        zipfel.move(to: CGPoint(x: kante - s * 12, y: unten - radius))
        zipfel.addLine(to: CGPoint(x: kante, y: unten - min(16, radius)))
        zipfel.addCurve(to: CGPoint(x: kante + s * t, y: unten), control1: CGPoint(x: kante, y: unten - 5), control2: CGPoint(x: kante + s * t * 0.4, y: unten - 1))
        zipfel.addCurve(to: CGPoint(x: kante - s * 10, y: unten - 2), control1: CGPoint(x: kante - s, y: unten + 0.5), control2: CGPoint(x: kante - s * 6, y: unten - 0.5))
        zipfel.closeSubpath()
        return rund.union(zipfel)
    }
}

/// Fill of a text bubble. Own: the backdrop gradient laid over the whole screen and cut out by the
/// bubble, so the colour wanders while scrolling (Instagram). Partner: calm `partnerBlase`.
struct BlasenHintergrund: View {
    let eigene: Bool
    let schwanz: Bool
    @Environment(\.chatVerlaufHoehe) private var hoehe
    @Environment(\.chatBackdrop) private var festerBackdrop

    var body: some View {
        let backdrop = festerBackdrop ?? Backdrops.aktuell
        let form = BlasenForm(schwanz: schwanz, rechts: eigene)
        if eigene {
            // ponytail: one `visualEffect` offset per own bubble. If this costs frames at 120 Hz,
            // drop the overlay/offset and fill `form` with the gradient directly (fixed per bubble).
            Color.clear
                .overlay(alignment: .top) {
                    LinearGradient(colors: backdrop.verlauf, startPoint: .top, endPoint: .bottom)
                        .frame(height: max(hoehe, 1))
                        .visualEffect { inhalt, geo in inhalt.offset(y: -geo.frame(in: .global).minY) }
                }
                .clipShape(form)
        } else {
            form.fill(backdrop.partnerBlase)
        }
    }
}

extension View {
    /// Padding, text colour and fill of a text bubble (the side keeps room for the tail).
    func blase(eigene: Bool, schwanz: Bool, backdrop: Backdrop) -> some View {
        self
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .padding(eigene ? .trailing : .leading, BlasenForm.schwanzBreite)
            .foregroundStyle(eigene ? backdrop.eigeneText : backdrop.partnerText)
            .background { BlasenHintergrund(eigene: eigene, schwanz: schwanz) }
    }
}

/// Grouping of consecutive bubbles (Z-32.4): same sender, at most 5 minutes apart, same day.
enum BlasenGruppe {
    static let fenster: TimeInterval = 300

    /// Rows that draw as a bubble or media (not captions like "zurückgezogen", system lines, games).
    static func istBlase(_ n: ChatModell.Nachricht) -> Bool {
        !n.geloescht && n.system == nil && n.spiel == nil && n.einladung == nil
    }

    static func zusammen(_ a: ChatModell.Nachricht, _ b: ChatModell.Nachricht) -> Bool {
        a.von == b.von && istBlase(a) && istBlase(b)
            && abs(b.zeit.timeIntervalSince(a.zeit)) <= fenster
            && Calendar.berlin.isDate(a.zeit, inSameDayAs: b.zeit)
    }
}

/// Z-32.4 read receipt: the newest own message the partner has read (head goes under it) and the
/// newest own message if it's still unread ("Zugestellt").
struct LeseStatus {
    var gelesenID: String?
    var offen: ChatModell.Nachricht?

    init(nachrichten: [ChatModell.Nachricht], ich: Person, gelesenBisPartner: Date?) {
        for n in nachrichten.reversed() where n.von == ich && BlasenGruppe.istBlase(n) {
            if let bis = gelesenBisPartner, n.zeit <= bis {
                gelesenID = n.id
                break
            }
            if offen == nil { offen = n }
        }
    }
}
