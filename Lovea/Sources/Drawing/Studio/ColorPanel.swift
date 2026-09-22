import SwiftUI

struct HSBColor: Equatable, Sendable {
    var hue: Double
    var saturation: Double
    var brightness: Double
    var alpha: Double
}

extension RGBAColor {
    init(hsb: HSBColor) {
        let s = min(max(hsb.saturation, 0), 1)
        let v = min(max(hsb.brightness, 0), 1)
        let h = hsb.hue.isFinite ? (hsb.hue - hsb.hue.rounded(.down)) * 6 : 0
        let sector = min(Int(h), 5)
        let f = h - Double(sector)
        let p = v * (1 - s)
        let q = v * (1 - s * f)
        let t = v * (1 - s * (1 - f))
        let rgb: (Double, Double, Double) = switch sector {
        case 0: (v, t, p)
        case 1: (q, v, p)
        case 2: (p, v, t)
        case 3: (p, q, v)
        case 4: (t, p, v)
        default: (v, p, q)
        }
        self.init(red: rgb.0, green: rgb.1, blue: rgb.2, alpha: hsb.alpha)
    }

    var hsb: HSBColor {
        let maxValue = max(red, green, blue)
        let delta = maxValue - min(red, green, blue)
        var hue = 0.0
        if delta > 0 {
            if maxValue == red {
                hue = (green - blue) / delta
            } else if maxValue == green {
                hue = (blue - red) / delta + 2
            } else {
                hue = (red - green) / delta + 4
            }
            hue /= 6
            if hue < 0 { hue += 1 }
        }
        return HSBColor(
            hue: hue,
            saturation: maxValue > 0 ? delta / maxValue : 0,
            brightness: maxValue,
            alpha: alpha
        )
    }

    init?(hex: String) {
        var digits = hex.trimmingCharacters(in: .whitespaces)
        if digits.hasPrefix("#") { digits.removeFirst() }
        guard digits.count == 6, digits.allSatisfy(\.isHexDigit), let value = UInt32(digits, radix: 16) else {
            return nil
        }
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }

    var hex: String {
        let byte = { (value: Double) in Int((min(max(value, 0), 1) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", byte(red), byte(green), byte(blue))
    }

    fileprivate var swiftUIColor: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}

@MainActor
final class ColorPaletteStore: ObservableObject {
    static let slotCount = 16
    static let recentLimit = 8
    static let defaultPalette: [RGBAColor?] = {
        let bytes: [(Double, Double, Double)] = [
            (0, 0, 0), (255, 255, 255), (64, 64, 64), (128, 128, 128),
            (200, 200, 200), (230, 57, 70), (247, 140, 30), (250, 210, 50),
            (60, 180, 90), (40, 170, 220), (30, 90, 220), (130, 70, 200),
            (240, 110, 170), (246, 214, 190), (198, 134, 99), (110, 70, 45),
        ]
        return bytes.map { RGBAColor(red: $0.0 / 255, green: $0.1 / 255, blue: $0.2 / 255) }
    }()

    @Published private(set) var palette: [RGBAColor?]
    @Published private(set) var recent: [RGBAColor]

    private let defaults: UserDefaults
    private let paletteKey: String
    private let recentKey: String

    init(person: String, defaults: UserDefaults = .standard) {
        self.defaults = defaults
        paletteKey = "colorPalette.\(person)"
        recentKey = "recentColors.\(person)"
        let storedPalette = defaults.data(forKey: paletteKey)
            .flatMap { try? JSONDecoder().decode([RGBAColor?].self, from: $0) }
        if let storedPalette, storedPalette.count == Self.slotCount {
            palette = storedPalette
        } else {
            palette = Self.defaultPalette
        }
        recent = defaults.data(forKey: recentKey)
            .flatMap { try? JSONDecoder().decode([RGBAColor].self, from: $0) }
            .map { Array($0.prefix(Self.recentLimit)) } ?? []
    }

    func store(_ color: RGBAColor, at slot: Int) {
        guard palette.indices.contains(slot) else { return }
        palette[slot] = color
        defaults.set(try? JSONEncoder().encode(palette), forKey: paletteKey)
    }

    func use(_ color: RGBAColor) {
        recent.removeAll { $0 == color }
        recent.insert(color, at: 0)
        recent = Array(recent.prefix(Self.recentLimit))
        defaults.set(try? JSONEncoder().encode(recent), forKey: recentKey)
    }
}

struct ColorPanel: View {
    @Binding var color: RGBAColor
    @ObservedObject var palette: ColorPaletteStore
    var onEyedropper: () -> Void

    // Held separately so hue (and saturation) survive grey and black, where RGB loses them.
    @State private var hsb = HSBColor(hue: 0, saturation: 0, brightness: 0, alpha: 1)
    @State private var hexText = ""
    @FocusState private var hexFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                wheel
                    .frame(maxWidth: 320)
                    .frame(maxWidth: .infinity)

                HStack(spacing: 12) {
                    TextField("#RRGGBB", text: $hexText)
                        .font(.body.monospaced())
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .textFieldStyle(.roundedBorder)
                        .focused($hexFocused)
                        .onSubmit(applyHex)
                        .accessibilityLabel("Hex-Farbcode")
                    Button(action: onEyedropper) {
                        Label("Pipette", systemImage: "eyedropper")
                            .frame(minHeight: 44)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Pipette")
                }

                VStack(spacing: 8) {
                    slider("H", name: "Farbton", value: component(\.hue), scale: 360, unit: "°")
                    slider("S", name: "Sättigung", value: component(\.saturation), scale: 100, unit: "")
                    slider("B", name: "Helligkeit", value: component(\.brightness), scale: 100, unit: "")
                    slider("Deckkraft", name: "Deckkraft", value: component(\.alpha), scale: 100, unit: " %")
                }

                Text("Palette").font(.headline)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 8)], spacing: 8) {
                    ForEach(palette.palette.indices, id: \.self) { slot in
                        paletteSlot(slot)
                    }
                }

                Text("Zuletzt").font(.headline)
                if palette.recent.isEmpty {
                    Text("Noch keine Farben").foregroundStyle(.secondary)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(palette.recent.enumerated()), id: \.offset) { _, recentColor in
                                Button { choose(recentColor) } label: { ColorDot(color: recentColor) }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("Zuletzt benutzt \(recentColor.hex)")
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .onAppear {
            hsb = color.hsb
            hexText = color.hex
        }
        .onChange(of: color) { sync(from: color) }
        .onChange(of: hexFocused) { if !hexFocused { applyHex() } }
    }

    private var wheel: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let ring = max(side * 0.12, 28)
            let radius = (side - ring) / 2
            let square = max((radius - ring / 2 - 10) * sqrt(2), 1)
            let angle = hsb.hue * 2 * .pi

            ZStack {
                Circle()
                    .strokeBorder(
                        AngularGradient(
                            colors: stride(from: 0.0, through: 1.0, by: 1.0 / 6).map {
                                Color(hue: $0, saturation: 1, brightness: 1)
                            },
                            center: .center
                        ),
                        lineWidth: ring
                    )
                    .contentShape(Circle())
                    .gesture(DragGesture(minimumDistance: 0).onChanged { drag in
                        var turn = atan2(drag.location.y - side / 2, drag.location.x - side / 2) / (2 * .pi)
                        if turn < 0 { turn += 1 }
                        var next = hsb
                        next.hue = turn
                        update(next)
                    })
                    .frame(width: side, height: side)

                Knob(fill: Color(hue: hsb.hue, saturation: 1, brightness: 1), size: ring + 6)
                    .offset(x: radius * cos(angle), y: radius * sin(angle))

                ZStack {
                    LinearGradient(
                        colors: [.white, Color(hue: hsb.hue, saturation: 1, brightness: 1)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                }
                .frame(width: square, height: square)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onChanged { drag in
                    var next = hsb
                    next.saturation = min(max(drag.location.x / square, 0), 1)
                    next.brightness = 1 - min(max(drag.location.y / square, 0), 1)
                    update(next)
                })
                .overlay {
                    Knob(fill: Color(hue: hsb.hue, saturation: hsb.saturation, brightness: hsb.brightness), size: 28)
                    .position(x: hsb.saturation * square, y: (1 - hsb.brightness) * square)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }

    private func paletteSlot(_ slot: Int) -> some View {
        let stored = palette.palette[slot]
        let label: String = stored.map { "Palette \(slot + 1), \($0.hex)" } ?? "Palette \(slot + 1), leer"
        return Button {
            if let stored {
                choose(stored)
            } else {
                palette.store(color, at: slot)
            }
        } label: {
            if let stored {
                ColorDot(color: stored)
            } else {
                Circle()
                    .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    .foregroundStyle(.secondary)
                    .frame(width: 36, height: 36)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityHint(stored == nil ? Text("Speichert die aktuelle Farbe") : Text(""))
        .contextMenu {
            Button("Aktuelle Farbe hier speichern", systemImage: "square.and.arrow.down") {
                palette.store(color, at: slot)
            }
        }
    }

    private func slider(_ title: String, name: String, value: Binding<Double>, scale: Double, unit: String) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .frame(minWidth: 24, alignment: .leading)
                .accessibilityHidden(true)
            Slider(value: value, in: 0...1)
                .frame(minHeight: 44)
                .accessibilityLabel(name)
                .accessibilityValue("\(Int((value.wrappedValue * scale).rounded()))\(unit)")
            Text("\(Int((value.wrappedValue * scale).rounded()))\(unit)")
                .monospacedDigit()
                .frame(minWidth: 52, alignment: .trailing)
                .accessibilityHidden(true)
        }
    }

    private func component(_ key: WritableKeyPath<HSBColor, Double>) -> Binding<Double> {
        Binding(
            get: { hsb[keyPath: key] },
            set: { newValue in
                var next = hsb
                next[keyPath: key] = newValue
                update(next)
            }
        )
    }

    private func update(_ next: HSBColor) {
        hsb = next
        color = RGBAColor(hsb: next)
        hexText = color.hex
    }

    private func sync(from newColor: RGBAColor) {
        guard RGBAColor(hsb: hsb) != newColor else { return }
        var next = newColor.hsb
        if next.saturation < 0.001 || next.brightness < 0.001 { next.hue = hsb.hue }
        if next.brightness < 0.001 { next.saturation = hsb.saturation }
        hsb = next
        hexText = newColor.hex
    }

    private func choose(_ chosen: RGBAColor) {
        color = chosen
        palette.use(chosen)
    }

    private func applyHex() {
        guard var parsed = RGBAColor(hex: hexText), parsed.hex != color.hex else {
            hexText = color.hex
            return
        }
        parsed.alpha = color.alpha
        color = parsed
    }
}

struct ColorSwatchButton: View {
    let color: RGBAColor
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ColorDot(color: color)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Farbe")
        .accessibilityValue(color.hex)
    }
}

private struct ColorDot: View {
    let color: RGBAColor
    @ScaledMetric private var size = 34.0

    var body: some View {
        ZStack {
            Canvas { context, canvasSize in
                let cell = 6.0
                for row in 0..<Int((canvasSize.height / cell).rounded(.up)) {
                    for column in 0..<Int((canvasSize.width / cell).rounded(.up)) where (row + column).isMultiple(of: 2) {
                        let rect = CGRect(x: Double(column) * cell, y: Double(row) * cell, width: cell, height: cell)
                        context.fill(Path(rect), with: .color(.gray.opacity(0.35)))
                    }
                }
            }
            .background(.white)
            color.swiftUIColor
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(Color.primary.opacity(0.2), lineWidth: 1))
        .frame(minWidth: 44, minHeight: 44)
        .contentShape(Rectangle())
    }
}

private struct Knob: View {
    let fill: Color
    let size: Double

    var body: some View {
        Circle()
            .fill(fill)
            .overlay(Circle().strokeBorder(.white, lineWidth: 3))
            .shadow(color: .black.opacity(0.35), radius: 2)
            .frame(width: size, height: size)
            .allowsHitTesting(false)
    }
}

#Preview {
    @Previewable @State var color = RGBAColor.blue
    ColorPanel(color: $color, palette: ColorPaletteStore(person: "preview"), onEyedropper: {})
}
