import SwiftUI
import UIKit

/// CapCut-Bedienung des Snap-Editors (dunkel, flach): Kopfzeile, untere Werkzeugleiste und die
/// Panels, die von unten hereinkommen (kein Sheet, Vorschau und Zeitleiste bleiben sichtbar).
/// Zustand hält allein der `SnapEditor`.

enum SnapFarben {
    static let flaeche = Color(white: 0.1)
    static let kachel = Color(white: 0.16)
    /// Texte und Kritzeln.
    static let palette: [Color] = [.white, .black, Color.loveaRose, .yellow, .orange, .green, .cyan, .blue, .purple]
}

enum SnapPanel: String, Identifiable, CaseIterable {
    case bearbeiten = "Bearbeiten", ton = "Ton", text = "Text", sticker = "Sticker", filter = "Filter", zeichnen = "Zeichnen"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .bearbeiten: return "scissors"
        case .ton: return "speaker.wave.2"
        case .text: return "textformat"
        case .sticker: return "face.smiling"
        case .filter: return "camera.filters"
        case .zeichnen: return "pencil.tip"
        }
    }

    /// Bearbeiten/Ton gibt es nur beim Video, Filter nur wenn eingeschaltet.
    static func leiste(video: Bool, filterAn: Bool) -> [SnapPanel] {
        allCases.filter { (video || ($0 != .bearbeiten && $0 != .ton)) && (filterAn || $0 != .filter) }
    }
}

/// X links, rechts (optional "bleibt im Chat") und die Akzent-Pille "Senden"/"Übernehmen".
struct SnapEditorKopfzeile: View {
    /// `nil` im Tray-Modus: dort wird nichts gesendet, also gibt es kein "bleibt".
    let bleibt: Binding<Bool>?
    let sendetGerade: Bool
    let tray: Bool
    let schliessenLabel: String
    let onSchliessen: () -> Void
    let onSenden: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onSchliessen) {
                Image(systemName: "xmark").font(.body.weight(.semibold)).foregroundStyle(.white).frame(width: 44, height: 44)
            }
            .accessibilityLabel(schliessenLabel)
            Spacer(minLength: 0)
            if let bleibt {
                Toggle(isOn: bleibt) { Label("bleibt", systemImage: bleibt.wrappedValue ? "pin.fill" : "pin") }
                    .toggleStyle(.button).tint(Color.loveaRose).fixedSize()
                    .accessibilityLabel("bleibt im Chat")
            }
            Button(action: onSenden) {
                if sendetGerade { ProgressView().tint(.white) } else { Text(tray ? "Übernehmen" : "Senden").fixedSize() }
            }
            .buttonStyle(.borderedProminent).buttonBorderShape(.capsule).tint(Color.loveaRose)
            .disabled(sendetGerade)
        }
        .padding(.horizontal, 12)
        .padding(.top, 4)
    }
}

/// Horizontal scrollbar, Symbol mit kleinem Label darunter.
struct SnapWerkzeugLeiste: View {
    let werkzeuge: [SnapPanel]
    let onWahl: (SnapPanel) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(werkzeuge) { werkzeug in
                    Button { onWahl(werkzeug) } label: {
                        VStack(spacing: 4) {
                            Image(systemName: werkzeug.symbol).font(.system(size: 21)).frame(height: 26)
                            Text(werkzeug.rawValue).font(.system(size: 10, weight: .medium)).lineLimit(1)
                        }
                        .foregroundStyle(.white)
                        .frame(width: 68, height: 58)
                    }
                }
            }
            .padding(.horizontal, 12)
        }
        .frame(height: 62)
        .background(Color.black)
    }
}

/// Unteres Panel: Inhalt, darunter Titel links und Häkchen rechts (bestätigt, schließt).
struct SnapPanelRahmen<Inhalt: View>: View {
    let titel: String
    let onFertig: () -> Void
    @ViewBuilder let inhalt: () -> Inhalt

    var body: some View {
        VStack(spacing: 0) {
            inhalt().padding(.top, 12)
            HStack {
                Text(titel).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                Spacer()
                Button(action: onFertig) {
                    Image(systemName: "checkmark").font(.body.weight(.bold)).foregroundStyle(.white).frame(width: 44, height: 40)
                }
                .accessibilityLabel("Fertig")
            }
            .padding(.horizontal, 16)
            .frame(height: 44)
        }
        .background(SnapFarben.flaeche)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 16, topTrailingRadius: 16))
        .environment(\.colorScheme, .dark)
    }
}

/// Symbol + Label als Kachel (Bearbeiten, Ton, Zeichnen).
struct SnapPanelKnopf: View {
    let titel: String
    let symbol: String
    var aktiv = false
    let aktion: () -> Void

    var body: some View {
        Button(action: aktion) {
            VStack(spacing: 6) {
                Image(systemName: symbol).font(.system(size: 20)).frame(height: 24)
                Text(titel).font(.system(size: 11, weight: .medium)).lineLimit(2).multilineTextAlignment(.center)
            }
            .foregroundStyle(aktiv ? Color.loveaRose : .white)
            .frame(width: 84, height: 72)
            .background(SnapFarben.kachel, in: RoundedRectangle(cornerRadius: 10))
        }
    }
}

/// Farbreihe für Text und Stift.
struct SnapFarbReihe: View {
    @Binding var farbe: Color

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(SnapFarben.palette, id: \.self) { eintrag in
                    Button { farbe = eintrag } label: {
                        RoundedRectangle(cornerRadius: 8).fill(eintrag).frame(width: 44, height: 44)
                            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.white, lineWidth: farbe == eintrag ? 3 : 1)
                                .opacity(farbe == eintrag ? 1 : 0.25))
                    }
                    .accessibilityLabel("Farbe")
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

struct SnapTextPanel: View {
    @Binding var text: SnapEditor.SnapText
    @FocusState private var fokus: Bool

    var body: some View {
        VStack(spacing: 12) {
            TextField("Text eingeben", text: $text.text)
                .focused($fokus)
                .submitLabel(.done)
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .frame(height: 44)
                .background(SnapFarben.kachel, in: RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 16)
            SnapFarbReihe(farbe: $text.farbe)
        }
        .onAppear { fokus = true }
    }
}

/// Rechteck-Kacheln mit Namen + Intensitäts-Regler (0-100) darüber.
struct SnapFilterPanel: View {
    let vorschauBilder: [SnapFilter: UIImage]
    let gewaehlt: SnapFilter
    @Binding var staerke: Double
    let onWahl: (SnapFilter) -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Text("Intensität").font(.footnote.weight(.medium)).foregroundStyle(.secondary)
                Slider(value: $staerke, in: 0...100, step: 1).tint(Color.loveaRose)
                Text("\(Int(staerke.rounded()))").font(.footnote.monospacedDigit().weight(.semibold)).frame(width: 30, alignment: .trailing)
            }
            .padding(.horizontal, 16)
            .disabled(gewaehlt == .original)
            .opacity(gewaehlt == .original ? 0.4 : 1)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 10) {
                    ForEach(SnapFilter.allCases) { kachel($0) }
                }
                .padding(.horizontal, 16)
            }
            .frame(height: 110)
        }
    }

    private func kachel(_ filter: SnapFilter) -> some View {
        let aktiv = filter == gewaehlt
        return Button { onWahl(filter) } label: {
            VStack(spacing: 6) {
                ZStack {
                    SnapFarben.kachel
                    if let bild = vorschauBilder[filter] {
                        Image(uiImage: bild).resizable().scaledToFill()
                    } else {
                        ProgressView().tint(.white)
                    }
                    if filter == .original {
                        Color.black.opacity(0.35)
                        Image(systemName: "nosign").font(.system(size: 24)).foregroundStyle(.white)
                    }
                }
                .frame(width: 64, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.loveaRose, lineWidth: aktiv ? 2.5 : 0))
                Text(filter == .original ? "Keiner" : filter.anzeigename)
                    .font(.system(size: 11, weight: aktiv ? .semibold : .regular))
                    .foregroundStyle(aktiv ? Color.loveaRose : .white)
                    .lineLimit(1).minimumScaleFactor(0.7)
                    .frame(width: 70)
            }
        }
        .accessibilityAddTraits(aktiv ? .isSelected : [])
    }
}
