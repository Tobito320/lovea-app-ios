import SwiftUI

// Shared look of the Zyklus area: sugar pink, raspberry, peach, lilac white and pearl; in dark mode
// a deep berry instead of black. Colours are picked from the colour scheme so they also work in ImageRenderer.

enum ZyklusFarbe: CaseIterable {
    case zuckerrosa, himbeere, pfirsich, fliederweiss, perlmutt

    func farbe(_ schema: ColorScheme) -> Color {
        let hex: (hell: UInt32, dunkel: UInt32) = switch self {
        case .zuckerrosa: (0xF9A8C9, 0xF48FB8)
        case .himbeere: (0xC2185B, 0xFF6FA5)
        case .pfirsich: (0xFFC9A8, 0xFFA98A)
        case .fliederweiss: (0xF3E8FC, 0xB9A0DC)
        case .perlmutt: (0xFFF8FB, 0x4A1B3E)
        }
        return Color(zyklusHex: schema == .dark ? hex.dunkel : hex.hell)
    }

    var name: String {
        switch self {
        case .zuckerrosa: "Zuckerrosa"
        case .himbeere: "Himbeere"
        case .pfirsich: "Pfirsich"
        case .fliederweiss: "Fliederweiß"
        case .perlmutt: "Perlmutt"
        }
    }

    /// Body text on pearl cards and on the background (≥ 7 : 1).
    static func tinte(_ schema: ColorScheme) -> Color { Color(zyklusHex: schema == .dark ? 0xFFEAF3 : 0x5B1C3F) }
    /// Secondary text (≥ 4.5 : 1 on cards).
    static func tinteLeise(_ schema: ColorScheme) -> Color { Color(zyklusHex: schema == .dark ? 0xE8BCD3 : 0x8A4A68) }
    /// Glyphs and text on a raspberry fill.
    static func aufHimbeere(_ schema: ColorScheme) -> Color { Color(zyklusHex: schema == .dark ? 0x2D0A1E : 0xFFFFFF) }
}

/// Phase tints. Own names so this file does not depend on the logic types.
enum ZyklusPhasenTon: CaseIterable {
    case periode, follikel, fruchtbar, eisprung, luteal

    func farbe(_ schema: ColorScheme) -> Color {
        let hex: (hell: UInt32, dunkel: UInt32) = switch self {
        case .periode: (0xD81B60, 0xFF5C93)
        case .follikel: (0xE0703A, 0xFFB08A)
        case .fruchtbar: (0x8E44CE, 0xC49BFF)
        case .eisprung: (0x0E9C98, 0x5EE0D8)
        case .luteal: (0xB05A8A, 0xE59BC4)
        }
        return Color(zyklusHex: schema == .dark ? hex.dunkel : hex.hell)
    }

    var name: String {
        switch self {
        case .periode: "Periode"
        case .follikel: "Follikel"
        case .fruchtbar: "Fruchtbar"
        case .eisprung: "Eisprung"
        case .luteal: "Luteal"
        }
    }
}

extension Color {
    fileprivate init(zyklusHex hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
}

/// Soft gradient: lilac white to sugar pink (light), deep berry (dark), with optional decoration.
struct ZyklusHintergrund: View {
    var deko = true
    @Environment(\.colorScheme) private var schema

    var body: some View {
        ZStack {
            LinearGradient(
                colors: schema == .dark
                    ? [Color(zyklusHex: 0x2A0F24), Color(zyklusHex: 0x4A1738), Color(zyklusHex: 0x3A1230)]
                    : [Color(zyklusHex: 0xFFF1F7), Color(zyklusHex: 0xFFD9E8), Color(zyklusHex: 0xF3E8FC)],
                startPoint: .topLeading, endPoint: .bottomTrailing)
            if deko { ZyklusDeko() }
        }
        .ignoresSafeArea()
    }
}

/// Round pearl card, 1 pt border, soft pink shadow.
struct ZyklusKarte<Inhalt: View>: View {
    var akzent: Color?
    @ViewBuilder var inhalt: () -> Inhalt
    @Environment(\.colorScheme) private var schema
    @Environment(\.colorSchemeContrast) private var kontrast
    @ScaledMetric(relativeTo: .body) private var innen: CGFloat = 16

    var body: some View {
        let form = RoundedRectangle(cornerRadius: 26, style: .continuous)
        let ton = akzent ?? ZyklusFarbe.zuckerrosa.farbe(schema)
        inhalt()
            .padding(innen)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                form.fill(ZyklusFarbe.perlmutt.farbe(schema))
                    .overlay(form.fill(LinearGradient(colors: [ton.opacity(0.28), ton.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing)))
                    .overlay(form.strokeBorder(ton.opacity(kontrast == .increased ? 0.9 : 0.5), lineWidth: 1.5))
                    .shadow(color: ZyklusFarbe.himbeere.farbe(schema).opacity(schema == .dark ? 0.25 : 0.14), radius: 12, y: 5)
            }
    }
}

/// Filled raspberry button (or soft pink outline when `leise`), at least 48 pt high.
struct ZyklusKnopf: View {
    var titel: String
    var symbol: String?
    var leise = false
    var aktion: () -> Void = {}
    @Environment(\.colorScheme) private var schema
    @ScaledMetric(relativeTo: .body) private var hoehe: CGFloat = 48

    var body: some View {
        Button(action: aktion) {
            HStack(spacing: 8) {
                if let symbol { Image(systemName: symbol).font(.body.weight(.bold)) }
                Text(titel).font(.system(.body, design: .rounded).weight(.bold)).multilineTextAlignment(.center)
            }
            .foregroundStyle(leise ? ZyklusFarbe.tinte(schema) : ZyklusFarbe.aufHimbeere(schema))
            .padding(.horizontal, 22)
            .frame(minHeight: hoehe)
            .frame(maxWidth: .infinity)
            .background {
                let form = Capsule()
                if leise {
                    form.fill(ZyklusFarbe.zuckerrosa.farbe(schema).opacity(0.3))
                        .overlay(form.strokeBorder(ZyklusFarbe.zuckerrosa.farbe(schema), lineWidth: 1.5))
                } else {
                    form.fill(LinearGradient(colors: [ZyklusFarbe.himbeere.farbe(schema), ZyklusFarbe.himbeere.farbe(schema).opacity(0.82)], startPoint: .top, endPoint: .bottom))
                        .shadow(color: ZyklusFarbe.himbeere.farbe(schema).opacity(0.35), radius: 8, y: 4)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

/// Small pill for symptoms, moods and filters.
struct ZyklusChip: View {
    var titel: String
    var symbol: String?
    var gewaehlt = false
    var farbe: Color?
    @Environment(\.colorScheme) private var schema
    @ScaledMetric(relativeTo: .subheadline) private var hoehe: CGFloat = 36

    var body: some View {
        let ton = farbe ?? ZyklusFarbe.himbeere.farbe(schema)
        HStack(spacing: 6) {
            if let symbol { Image(systemName: symbol).font(.subheadline.weight(.semibold)) }
            Text(titel).font(.system(.subheadline, design: .rounded).weight(.semibold))
        }
        .foregroundStyle(gewaehlt ? ZyklusFarbe.aufHimbeere(schema) : ZyklusFarbe.tinte(schema))
        .padding(.horizontal, 14)
        .frame(minHeight: hoehe)
        .background {
            let form = Capsule()
            if gewaehlt {
                form.fill(ton)
            } else {
                form.fill(ZyklusFarbe.perlmutt.farbe(schema)).overlay(form.strokeBorder(ton.opacity(0.55), lineWidth: 1.5))
            }
        }
        .accessibilityAddTraits(gewaehlt ? .isSelected : [])
    }
}

/// Phase ring: progress 0...1 in the phase colour, title (e.g. "Tag 14") and subtitle inside.
struct ZyklusRing: View {
    var fortschritt: Double
    var phase: ZyklusPhasenTon
    var titel: String
    var untertitel: String
    @Environment(\.colorScheme) private var schema
    @Environment(\.accessibilityReduceMotion) private var weniger
    @ScaledMetric(relativeTo: .largeTitle) private var durchmesser: CGFloat = 220
    @ScaledMetric(relativeTo: .largeTitle) private var strich: CGFloat = 22

    var body: some View {
        let ton = phase.farbe(schema)
        let anteil = min(max(fortschritt, 0), 1)
        ZStack {
            Circle().stroke(ton.opacity(schema == .dark ? 0.28 : 0.2), lineWidth: strich)
            Circle()
                .trim(from: 0, to: anteil)
                .stroke(AngularGradient(colors: [ton.opacity(0.55), ton], center: .center, startAngle: .degrees(0), endAngle: .degrees(360 * max(anteil, 0.01))),
                        style: StrokeStyle(lineWidth: strich, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(weniger ? nil : .easeOut(duration: 0.6), value: anteil)
            VStack(spacing: 4) {
                ZyklusHerzForm().fill(ton).frame(width: 18, height: 18)
                Text(titel)
                    .font(.system(.largeTitle, design: .rounded).weight(.heavy))
                    .foregroundStyle(ZyklusFarbe.tinte(schema))
                    .minimumScaleFactor(0.5).lineLimit(2).multilineTextAlignment(.center)
                Text(untertitel)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(ZyklusFarbe.tinteLeise(schema))
                    .minimumScaleFactor(0.7).lineLimit(2).multilineTextAlignment(.center)
            }
            .padding(strich + 12)
        }
        .frame(width: durchmesser, height: durchmesser)
        .padding(strich / 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(titel), \(untertitel)")
        .accessibilityValue("\(Int((anteil * 100).rounded())) Prozent des Zyklus")
    }
}
