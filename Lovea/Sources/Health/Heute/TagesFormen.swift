import SwiftUI

// Tagesformen (Plan Task 5): neun Kacheln von "Heute", jede mit eigener Form, die sich von unten füllt.
// Pfade 1:1 aus `FORM` in design/erholung/erholung.html (Koordinatenraum 64 × 64).

enum TagesForm: String, CaseIterable, Sendable {
    case schritte, wasser, schlaf, habits, stimmung, koffein, protein, gewicht, training
}

private func tf(_ hex: UInt32, _ alpha: Double = 1) -> Color {
    Color(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
        .opacity(alpha)
}

extension TagesForm {
    var farbe: Color {
        switch self {
        case .schritte: tf(0xE5E5EA)
        case .wasser: tf(0x5AC8FA)
        case .schlaf: tf(0x8E91FF)
        case .habits: tf(0x3DDBB0)
        case .stimmung: tf(0xFFB340)
        case .koffein: tf(0xD9A066)
        case .protein: tf(0xE5534B)
        case .gewicht: tf(0xAEAEB2)
        case .training: tf(0x30D158)
        }
    }

    /// Senkrechtes Maß der Form: unten = leer, oben = voll (`FORM[..].y`).
    fileprivate var bereich: ClosedRange<Double> {
        switch self {
        case .schritte: 16.5...45
        case .wasser: 10...60
        case .schlaf: 12...52
        case .habits: 7...60
        case .stimmung: 7...59
        case .koffein: 22...58
        case .protein: 9...55
        case .gewicht: 10...58
        case .training: 18...46
        }
    }

    fileprivate var pfad: String {
        switch self {
        case .schritte:
            "M8 20C8 18 9.5 16.5 11.5 16.5H20C22 16.5 23.4 17.8 23.8 19.6L25 25C26 29 29.5 31 34 31.6L50 33.5C55.5 34.2 59.5 38.5 59.5 44V45H6V23C6 21.5 6.8 20.4 8 20ZM4 45H61C61.6 45 62 45.4 62 46V48.5C62 51 60 53 57.5 53H8C5.8 53 4 51.2 4 49Z"
        case .wasser: "M15 10H49L44.5 55C44.2 57.9 41.9 60 39 60H25C22.1 60 19.8 57.9 19.5 55Z"
        case .schlaf:
            "M6 14C6 12.9 6.9 12 8 12H10C11.1 12 12 12.9 12 14V32H55C57.8 32 60 34.2 60 37V50C60 51.1 59.1 52 58 52H56C54.9 52 54 51.1 54 50V46.5H12V50C12 51.1 11.1 52 10 52H8C6.9 52 6 51.1 6 50ZM14.5 30.5C14.5 26.5 16.5 24.5 20 24.5H25.5C28 24.5 30 26.5 30 29V32H14.5Z"
        case .habits:
            "M16 12H23C23 9.2 25.2 7 28 7H36C38.8 7 41 9.2 41 12H48C50.2 12 52 13.8 52 16V56C52 58.2 50.2 60 48 60H16C13.8 60 12 58.2 12 56V16C12 13.8 13.8 12 16 12Z"
        // ponytail: der Kreis "A26 26 0 1 1" als vier Bézier-Bögen, der Parser kennt keine Arc-Befehle.
        case .stimmung:
            "M32 7C46.36 7 58 18.64 58 33C58 47.36 46.36 59 32 59C17.64 59 6 47.36 6 33C6 18.64 17.64 7 32 7Z"
        case .koffein: "M10 22H46V46C46 52.6 40.6 58 34 58H22C15.4 58 10 52.6 10 46Z"
        case .protein:
            "M13 21C18 11 33 7 46 11C56 14 60.5 23.5 57.5 34C54.5 44.5 46 52.5 34 54.5C22 56.5 9.5 50.5 7.5 40C6.3 33 8.8 26.5 13 21Z"
        case .gewicht: "M15 10H49C53.4 10 57 13.6 57 18V50C57 54.4 53.4 58 49 58H15C10.6 58 7 54.4 7 50V18C7 13.6 10.6 10 15 10Z"
        case .training:
            "M3 26H8V20C8 18.9 8.9 18 10 18H14C15.1 18 16 18.9 16 20V44C16 45.1 15.1 46 14 46H10C8.9 46 8 45.1 8 44V38H3ZM16 29H48V35H16ZM48 20C48 18.9 48.9 18 50 18H54C55.1 18 56 18.9 56 20V26H61V38H56V44C56 45.1 55.1 46 54 46H50C48.9 46 48 45.1 48 44Z"
        }
    }
}

/// SVG-Pfadtext im 64 × 64 Raum als `Shape`. Kann M L H V C Q Z, klein geschrieben = relativ.
/// ponytail: keine Befehle S T A, der Entwurf braucht sie nicht (Handgriff und Kreis sind ausgeschrieben).
struct SVGPfad: Shape {
    let d: String

    func path(in rect: CGRect) -> Path {
        var p = Path()
        for (befehl, n) in Self.teile(d) {
            let art = befehl.lowercased()
            guard let anzahl = ["m": 2, "l": 2, "h": 1, "v": 1, "c": 6, "q": 4][art] else {
                if art == "z" { p.closeSubpath() }
                continue
            }
            for i in stride(from: 0, to: n.count - anzahl + 1, by: anzahl) {
                let a = Array(n[i..<i + anzahl])
                let hier = p.currentPoint ?? .zero
                let o = befehl.isLowercase ? hier : .zero
                func pt(_ j: Int) -> CGPoint { CGPoint(x: o.x + a[j], y: o.y + a[j + 1]) }
                switch art {
                case "m" where i == 0: p.move(to: pt(0))
                case "m", "l": p.addLine(to: pt(0))
                case "h": p.addLine(to: CGPoint(x: o.x + a[0], y: hier.y))
                case "v": p.addLine(to: CGPoint(x: hier.x, y: o.y + a[0]))
                case "c": p.addCurve(to: pt(4), control1: pt(0), control2: pt(2))
                default: p.addQuadCurve(to: pt(2), control: pt(0))
                }
            }
        }
        return p.applying(CGAffineTransform(scaleX: rect.width / 64, y: rect.height / 64))
            .offsetBy(dx: rect.minX, dy: rect.minY)
    }

    private static func teile(_ d: String) -> [(Character, [Double])] {
        var out: [(Character, [Double])] = []
        var zahl = ""
        func fertig() {
            if let z = Double(zahl), !out.isEmpty { out[out.count - 1].1.append(z) }
            zahl = ""
        }
        for c in d {
            if c.isLetter {
                fertig()
                out.append((c, []))
            } else if c == "-" || c == " " || c == "," {
                fertig()
                if c == "-" { zahl = "-" }
            } else {
                zahl.append(c)
            }
        }
        fertig()
        return out
    }
}

/// Füllung bis `ziel` (y im 64er Raum). Ohne `welle` ein Rechteck, mit `welle` die Wellenlinie aus dem Entwurf
/// (Amplitude 3,2, Periode 32). `linie` ist nur die helle Oberkante.
private struct Fuellung: Shape {
    var ziel: Double
    var phase: Double = 0
    var welle = false
    var linie = false

    var animatableData: Double {
        get { ziel }
        set { ziel = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var p = Path()
        guard welle else {
            p.addRect(CGRect(x: 0, y: ziel, width: 64, height: linie ? 1.8 : 70))
            return p
        }
        p.move(to: CGPoint(x: -64 + phase, y: ziel))
        for i in 0..<9 {
            let x = -64 + Double(i) * 16 + phase
            p.addQuadCurve(to: CGPoint(x: x + 16, y: ziel), control: CGPoint(x: x + 8, y: ziel + (i.isMultiple(of: 2) ? -3.2 : 3.2)))
        }
        if !linie {
            p.addLine(to: CGPoint(x: 80 + phase, y: 70))
            p.addLine(to: CGPoint(x: -64 + phase, y: 70))
            p.closeSubpath()
        }
        return p
    }
}

/// Eine Form mit Füllung und Details, 70 pt.
struct TagesFormView: View {
    let form: TagesForm
    let fuellung: Double
    var stimmung: Int?
    @Environment(\.accessibilityReduceMotion) private var ruhig

    var body: some View {
        ZStack {
            SVGPfad(d: form.pfad).fill(tf(0x2C2C30))
            schicht.mask { SVGPfad(d: form.pfad) }
            SVGPfad(d: form.pfad).stroke(form.farbe, style: StrokeStyle(lineWidth: 2.2, lineJoin: .round))
            TagesFormDetails(form: form, q: q, stimmung: stimmung, ruhig: ruhig)
        }
        .frame(width: 64, height: 64)
        .scaleEffect(70.0 / 64)
        .frame(width: 70, height: 70)
        .accessibilityHidden(true)
    }

    private var q: Double { min(max(fuellung, 0), 1) }

    @ViewBuilder private var schicht: some View {
        // ponytail: Gewicht ist eine Waage und füllt sich nicht (wie im Entwurf).
        if form != .gewicht {
            let b = form.bereich
            let ziel = b.upperBound - q * (b.upperBound - b.lowerBound)
            Group {
                if form == .wasser || form == .koffein {
                    // Bei 0 % sitzt der Wellenkamm unter dem Rand, sonst blitzt ein Streifen auf.
                    let z = ziel + 4 * (1 - q)
                    if ruhig { welle(z, 0) } else { TimelineView(.animation) { welle(z, Self.phase($0.date)) } }
                } else {
                    Fuellung(ziel: ziel).fill(form.farbe)
                    Fuellung(ziel: ziel, linie: true).fill(.white.opacity(0.7))
                }
            }
            .animation(ruhig ? nil : .spring(duration: 0.9, bounce: 0), value: fuellung)
        }
    }

    private func welle(_ ziel: Double, _ phase: Double) -> some View {
        ZStack {
            Fuellung(ziel: ziel, phase: phase, welle: true).fill(form.farbe)
            Fuellung(ziel: ziel, phase: phase, welle: true, linie: true).stroke(.white.opacity(0.7), lineWidth: 1.6)
        }
    }

    private static func phase(_ datum: Date) -> Double {
        (datum.timeIntervalSinceReferenceDate / 2.6).truncatingRemainder(dividingBy: 1) * 32
    }
}

/// Die eigenen Overlays je Form (Klassen `.z` aus dem Entwurf).
private struct TagesFormDetails: View {
    let form: TagesForm
    let q: Double
    let stimmung: Int?
    let ruhig: Bool

    var body: some View {
        ZStack {
            switch form {
            case .schritte: schritte
            case .wasser: strich("M21.5 15.5L24.5 50", .white, 2.2, 0.35)
            case .schlaf: schlaf
            case .habits: habits
            case .stimmung: gesicht
            case .koffein: tasse
            case .protein: steak
            case .gewicht: waage
            case .training: EmptyView()
            }
        }
    }

    private func strich(_ d: String, _ farbe: Color, _ breite: Double, _ deckkraft: Double = 1) -> some View {
        SVGPfad(d: d).stroke(farbe, style: StrokeStyle(lineWidth: breite, lineCap: .round, lineJoin: .round)).opacity(deckkraft)
    }

    private func punkt(_ x: Double, _ y: Double, _ r: Double, _ farbe: Color) -> some View {
        Circle().fill(farbe).frame(width: r * 2, height: r * 2).position(x: x, y: y)
    }

    private var schritte: some View {
        ZStack {
            SVGPfad(d: "M4 45H61C61.6 45 62 45.4 62 46V48.5C62 51 60 53 57.5 53H8C5.8 53 4 51.2 4 49Z")
                .fill(.white).overlay(SVGPfad(d: "M4 45H61C61.6 45 62 45.4 62 46V48.5C62 51 60 53 57.5 53H8C5.8 53 4 51.2 4 49Z").stroke(tf(0xAEAEB2), lineWidth: 1.6))
            strich("M5 49.2H61.5", tf(0xD1D1D6), 1.2)
            strich("M47 34C52.5 35.2 56.5 38.6 58.2 44", tf(0xAEAEB2), 1.4)
            SVGPfad(d: "M17 42C25 41.5 33 39 41 34.5C35 40 27 43.6 18.5 44Z").fill(tf(0xAEAEB2))
            strich("M26 24.5l4-2.6M29.2 28l4-2.6M33 30.6l4-2.6", tf(0x8E8E93), 1.8)
            strich("M11.5 16.5C14.5 20 20 20.4 23.3 18.8", tf(0xAEAEB2), 1.4)
            SVGPfad(d: "M5.5 22.5H9.5V36H5.5").fill(tf(0xE5E5EA))
                .overlay(SVGPfad(d: "M5.5 22.5H9.5V36H5.5").stroke(tf(0xAEAEB2), lineWidth: 1.2))
            ForEach([(50.0, 37.0), (53, 38.2), (56, 39.8), (51.5, 40.5), (54.5, 41.8)], id: \.0) { punkt($0.0, $0.1, 0.9, tf(0xAEAEB2)) }
        }
    }

    private var schlaf: some View {
        ZStack {
            strich("M31 32C38 28.5 48 28.5 55 32", form.farbe, 1.8, 0.8)
            zeichen("z", 11, x: 45, y: 21)
            zeichen("z", 8, x: 51, y: 14)
        }
    }

    /// SVG setzt `y` auf die Grundlinie, `position` meint die Mitte des Textes.
    private func zeichen(_ text: String, _ groesse: Double, x: Double, y: Double) -> some View {
        Text(text).font(.system(size: groesse, weight: .bold)).foregroundStyle(tf(0xAEAEB2))
            .position(x: x + groesse * 0.25, y: y - groesse * 0.35)
    }

    private var habits: some View {
        let an = Int((q * 5).rounded())
        return ZStack {
            ForEach(0..<5, id: \.self) { i in
                let y = 22 + Double(i) * 7.6
                strich("M19 \(y)l2.2 2.2 4-4.4", i < an ? .white : form.farbe, 2, i < an ? 1 : 0.35)
                strich("M30 \(y + 0.8)H45", form.farbe, 1.8, 0.8)
            }
        }
    }

    private var gesicht: some View {
        let k = [-7.0, 0, 10][min(max(stimmung ?? 2, 1), 3) - 1]
        return ZStack {
            punkt(23, 28, 3.2, tf(0x2A1F14))
            punkt(41, 28, 3.2, tf(0x2A1F14))
            strich("M21 \(41 - k / 3)Q32 \(41 + k) 43 \(41 - k / 3)", tf(0x2A1F14), 2.6)
            punkt(18, 37, 3, tf(0xFF7AA8, 0.45))
            punkt(46, 37, 3, tf(0xFF7AA8, 0.45))
        }
    }

    private var tasse: some View {
        ZStack {
            strich("M46 28H50C53.9 28 57 31.1 57 35C57 38.9 53.9 42 50 42H46", form.farbe, 2.4)
            if q > 0 && !ruhig { dampf }
        }
    }

    private var dampf: some View {
        TimelineView(.animation) { zeit in
            ZStack {
                ForEach(0..<3, id: \.self) { i in
                    let x = 21.0 + Double(i) * 8
                    let u = ((zeit.date.timeIntervalSinceReferenceDate - Double(i) * 0.5) / 2.4).truncatingRemainder(dividingBy: 1)
                    let v = u < 0 ? u + 1 : u
                    strich("M\(x) 16C\(x - 2) 13 \(x + 2) 11 \(x) 7", tf(0xAEAEB2), 1.8)
                        .offset(y: 4 - 9 * v)
                        .opacity(v < 0.4 ? 0.8 * v / 0.4 : 0.8 * (1 - v) / 0.6)
                }
            }
        }
    }

    private var steak: some View {
        ZStack {
            strich("M14.5 22.5C19.5 14 33.5 10 45 13.8", tf(0xFFEBDD), 3.6)
            Circle().fill(tf(0xFFEBDD)).overlay(Circle().stroke(tf(0xC9A48E), lineWidth: 1.4))
                .frame(width: 10, height: 10).position(x: 40, y: 31)
            punkt(40, 31, 2, tf(0xE8C9B6))
            strich("M20 36C24 34 26 38 30 36M28 45C32 43 35 46 39 44", tf(0xFFD0C2), 1.3, 0.8)
        }
    }

    private var waage: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3).fill(.black.opacity(0.35))
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(form.farbe, lineWidth: 1.4))
                .frame(width: 22, height: 11).position(x: 32, y: 22.5)
            strich("M32 25V20.5", form.farbe, 1.8, 0.8)
        }
    }
}

/// Kachel wie im Entwurf: Form 70 pt, Titel, Wert mit Einheit. Mit `aktion` ein Knopf.
struct FormKachel: View {
    let form: TagesForm
    let titel: String
    let wert: String
    let einheit: String
    let fuellung: Double
    var zusatz: String?
    var stimmung: Int?
    var aktion: (() -> Void)?

    @State private var hopp = false
    @State private var tipp = 0
    @Environment(\.accessibilityReduceMotion) private var ruhig

    var body: some View {
        if let aktion {
            Button {
                tipp += 1
                hopp = true
                aktion()
            } label: { inhalt }
                .buttonStyle(.federnd)
                .accessibilityHint("Antippen zum Eintragen")
                .sensoryFeedback(.increase, trigger: tipp)
        } else {
            inhalt
        }
    }

    private var inhalt: some View {
        VStack(spacing: 2) {
            TagesFormView(form: form, fuellung: fuellung, stimmung: stimmung)
                .scaleEffect(hopp && !ruhig ? 1.12 : 1)
                .rotationEffect(.degrees(hopp && !ruhig ? -3 : 0))
                .animation(ruhig ? nil : .spring(bounce: 0.35), value: hopp)
            Text(titel).font(.caption.weight(.semibold)).foregroundStyle(.secondary).padding(.top, 4)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(wert).font(.body.bold()).monospacedDigit().foregroundStyle(.primary)
                Text(einheit).font(.caption2).foregroundStyle(.tertiary)
            }
            if let zusatz { Text(zusatz).font(.caption2).foregroundStyle(.tertiary) }
        }
        .multilineTextAlignment(.center)
        .padding(.vertical, 10)
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color(uiColor: .secondarySystemBackground)))
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(titel): \(wert) \(einheit)")
        .task(id: hopp) {
            guard hopp else { return }
            try? await Task.sleep(for: .milliseconds(200))
            hopp = false
        }
    }
}
