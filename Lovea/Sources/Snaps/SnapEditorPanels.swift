import SwiftUI
import UIKit

/// CapCut-Bedienung des Snap-Editors (dunkel, flach): untere Werkzeugleiste und die Panels, die
/// von unten hereinkommen (kein Sheet, Vorschau und Zeitleiste bleiben sichtbar). Alles hier ist
/// zustandslos: Werte und Closures kommen vom `SnapEditor`, der als Einziger den Zustand hält.

enum SnapFarben {
    static let flaeche = Color(red: 0x1A / 255, green: 0x1A / 255, blue: 0x1A / 255)
    static let kachel = Color(red: 0x2A / 255, green: 0x2A / 255, blue: 0x2A / 255)
    static let akzent = Color.loveaRose
    static let gedaempft = Color.white.opacity(0.6)
    /// Texte und Kritzeln.
    static let palette: [Color] = [.white, .black, Color.loveaRose, .yellow, .orange, .green, .cyan, .blue, .purple]
}

enum SnapPanel: String, Identifiable, CaseIterable {
    case bearbeiten, ton, text, sticker, filter, zeichnen

    var id: String { rawValue }

    var titel: String {
        switch self {
        case .bearbeiten: return "Bearbeiten"
        case .ton: return "Ton"
        case .text: return "Text"
        case .sticker: return "Sticker"
        case .filter: return "Filter"
        case .zeichnen: return "Zeichnen"
        }
    }

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

    /// Reihenfolge der Leiste; Bearbeiten/Ton gibt es nur beim Video, Filter nur wenn eingeschaltet.
    static func leiste(video: Bool, filterAn: Bool) -> [SnapPanel] {
        var liste: [SnapPanel] = []
        if video { liste.append(contentsOf: [.bearbeiten, .ton]) }
        liste.append(contentsOf: [.text, .sticker])
        if filterAn { liste.append(.filter) }
        liste.append(.zeichnen)
        return liste
    }
}

// MARK: - Obere Leiste und Werkzeugleiste

/// X links, rechts (optional "bleibt im Chat") und die Akzent-Pill "Senden"/"Übernehmen".
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
                Image(systemName: "xmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(schliessenLabel)
            Spacer(minLength: 0)
            if let bleibt { bleibtChip(bleibt) }
            sendenPille
        }
        .padding(.horizontal, 12)
        .padding(.top, 4)
    }

    private func bleibtChip(_ bleibt: Binding<Bool>) -> some View {
        Button {
            Haptik.auswahl()
            bleibt.wrappedValue.toggle()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: bleibt.wrappedValue ? "pin.fill" : "pin")
                Text("bleibt").lineLimit(1).fixedSize()
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(bleibt.wrappedValue ? SnapFarben.akzent : .white)
            .padding(.horizontal, 12)
            .frame(minHeight: 36)
            .background(SnapFarben.flaeche, in: Capsule())
        }
        .accessibilityLabel("bleibt im Chat")
        .accessibilityValue(bleibt.wrappedValue ? "an" : "aus")
    }

    private var sendenPille: some View {
        Button(action: onSenden) {
            HStack(spacing: 6) {
                if sendetGerade {
                    ProgressView().tint(.white)
                } else {
                    Text(tray ? "Übernehmen" : "Senden").lineLimit(1).fixedSize()
                }
            }
            .font(.subheadline.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .frame(minHeight: 36)
            .background(SnapFarben.akzent, in: Capsule())
        }
        .disabled(sendetGerade)
        .accessibilityLabel(tray ? "Übernehmen" : "Senden")
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
                    knopf(werkzeug)
                }
            }
            .padding(.horizontal, 12)
        }
        .frame(height: 62)
        .background(Color.black)
    }

    private func knopf(_ werkzeug: SnapPanel) -> some View {
        Button { onWahl(werkzeug) } label: {
            VStack(spacing: 4) {
                Image(systemName: werkzeug.symbol)
                    .font(.system(size: 21))
                    .frame(height: 26)
                Text(werkzeug.titel)
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(1)
            }
            .foregroundStyle(.white)
            .frame(width: 68, height: 58)
        }
        .accessibilityLabel(werkzeug.titel)
    }
}

// MARK: - Panel-Rahmen

/// Unteres Panel: Inhalt, darunter Titel links und Häkchen rechts (bestätigt, schließt).
struct SnapPanelRahmen<Inhalt: View>: View {
    let titel: String
    let onFertig: () -> Void
    @ViewBuilder let inhalt: () -> Inhalt

    var body: some View {
        VStack(spacing: 0) {
            inhalt()
            HStack {
                Text(titel)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
                Button(action: onFertig) {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 40)
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

/// Symbol + Label als Kachel in den Bearbeiten-/Ton-Panels.
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
            .foregroundStyle(aktiv ? SnapFarben.akzent : .white)
            .frame(width: 84, height: 72)
            .background(SnapFarben.kachel, in: RoundedRectangle(cornerRadius: 10))
        }
        .accessibilityLabel(titel)
    }
}

// MARK: - Filter

/// Eine abgerundete rechteckige Vorschau-Kachel mit Namen darunter (statt der alten Kreise).
struct SnapFilterKachel: View {
    let name: String
    let bild: UIImage?
    let keiner: Bool
    let gewaehlt: Bool
    let aktion: () -> Void

    static let breite: CGFloat = 64
    static let hoehe: CGFloat = 80

    var body: some View {
        Button(action: aktion) {
            VStack(spacing: 6) {
                vorschau
                    .frame(width: Self.breite, height: Self.hoehe)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(SnapFarben.akzent, lineWidth: gewaehlt ? 2.5 : 0))
                Text(name)
                    .font(.system(size: 11, weight: gewaehlt ? .semibold : .regular))
                    .foregroundStyle(gewaehlt ? SnapFarben.akzent : .white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(width: Self.breite + 6)
            }
        }
        .accessibilityLabel(name)
        .accessibilityAddTraits(gewaehlt ? .isSelected : [])
    }

    private var vorschau: some View {
        ZStack {
            SnapFarben.kachel
            if let bild {
                Image(uiImage: bild).resizable().scaledToFill()
            } else {
                ProgressView().tint(.white)
            }
            if keiner {
                Color.black.opacity(0.35)
                Image(systemName: "nosign").font(.system(size: 24)).foregroundStyle(.white)
            }
        }
    }
}

/// Kachelreihe + Intensitäts-Regler (0-100) darüber.
struct SnapFilterPanel: View {
    let vorschauBilder: [SnapFilter: UIImage]
    let gewaehlt: SnapFilter
    @Binding var staerke: Double
    let onWahl: (SnapFilter) -> Void

    var body: some View {
        VStack(spacing: 12) {
            regler
            kacheln
        }
        .padding(.top, 14)
        .padding(.bottom, 6)
    }

    private var regler: some View {
        HStack(spacing: 12) {
            Text("Intensität")
                .font(.footnote.weight(.medium))
                .foregroundStyle(SnapFarben.gedaempft)
            Slider(value: $staerke, in: 0...100, step: 1)
                .tint(SnapFarben.akzent)
                .disabled(gewaehlt == .original)
            Text("\(Int(staerke.rounded()))")
                .font(.footnote.monospacedDigit().weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 30, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .opacity(gewaehlt == .original ? 0.4 : 1)
    }

    private var kacheln: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: 10) {
                ForEach(SnapFilter.allCases) { filter in
                    SnapFilterKachel(
                        name: filter == .original ? "Keiner" : filter.anzeigename,
                        bild: vorschauBilder[filter],
                        keiner: filter == .original,
                        gewaehlt: filter == gewaehlt,
                        aktion: { onWahl(filter) }
                    )
                }
            }
            .padding(.horizontal, 16)
        }
        .frame(height: SnapFilterKachel.hoehe + 30)
    }
}

// MARK: - Bearbeiten und Ton (Video)

struct SnapBearbeitenPanel: View {
    let plan: SnapSchnitt
    let markeStart: Double?
    let hinweis: String?
    let onAnfang: () -> Void
    let onEnde: () -> Void
    let onMarke: () -> Void
    let onWiederherstellen: (Int) -> Void
    let onZuruecksetzen: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    SnapPanelKnopf(titel: "Anfang hier", symbol: "arrow.right.to.line", aktion: onAnfang)
                    SnapPanelKnopf(titel: "Ende hier", symbol: "arrow.left.to.line", aktion: onEnde)
                    SnapPanelKnopf(titel: markeStart == nil ? "Teil entfernen: Start" : "Bis hier entfernen",
                                   symbol: "scissors", aktiv: markeStart != nil, aktion: onMarke)
                    SnapPanelKnopf(titel: "Zurücksetzen", symbol: "arrow.counterclockwise", aktion: onZuruecksetzen)
                }
                .padding(.horizontal, 16)
            }
            entfernte
            Text(hinweis ?? "Länge " + SnapSchnitt.zeit(plan.ergebnisDauer) + ". Griffe am Clip kürzen ebenfalls.")
                .font(.caption)
                .foregroundStyle(hinweis == nil ? SnapFarben.gedaempft : Color.orange)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.top, 14)
        .padding(.bottom, 6)
    }

    @ViewBuilder private var entfernte: some View {
        if !plan.entfernt.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(plan.entfernt.enumerated()), id: \.offset) { index, teil in
                        Button { onWiederherstellen(index) } label: {
                            Label(SnapSchnitt.zeit(teil.von) + "–" + SnapSchnitt.zeit(teil.bis), systemImage: "arrow.uturn.backward")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(SnapFarben.kachel, in: Capsule())
                        }
                        .accessibilityLabel("Entfernten Teil \(index + 1) wiederherstellen")
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
}

struct SnapTonPanel: View {
    let stumm: Bool
    let onUmschalten: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                SnapPanelKnopf(titel: stumm ? "Ton an" : "Ton aus",
                               symbol: stumm ? "speaker.wave.2.fill" : "speaker.slash.fill",
                               aktiv: stumm, aktion: onUmschalten)
                Spacer()
            }
            .padding(.horizontal, 16)
            Text(stumm ? "Das Video wird ohne Ton gesendet." : "Das Video wird mit Originalton gesendet.")
                .font(.caption)
                .foregroundStyle(SnapFarben.gedaempft)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.top, 14)
        .padding(.bottom, 6)
    }
}

// MARK: - Text

struct SnapTextPanel: View {
    @Binding var text: SnapEditor.SnapText

    private enum Reiter: String, CaseIterable {
        case eingabe = "Text", schrift = "Schrift", farbe = "Farbe", stil = "Stil"
    }
    @State private var reiter = Reiter.eingabe
    @FocusState private var fokus: Bool

    var body: some View {
        VStack(spacing: 12) {
            reiterLeiste
            inhalt
                .frame(height: 64)
        }
        .padding(.top, 10)
        .padding(.bottom, 6)
        .onAppear { fokus = true }
    }

    private var reiterLeiste: some View {
        HStack(spacing: 22) {
            ForEach(Reiter.allCases, id: \.self) { eintrag in
                Button {
                    reiter = eintrag
                    fokus = eintrag == .eingabe
                } label: {
                    VStack(spacing: 4) {
                        Text(eintrag.rawValue)
                            .font(.subheadline.weight(reiter == eintrag ? .bold : .regular))
                            .foregroundStyle(reiter == eintrag ? Color.white : SnapFarben.gedaempft)
                        Capsule()
                            .fill(reiter == eintrag ? SnapFarben.akzent : Color.clear)
                            .frame(width: 22, height: 3)
                    }
                }
            }
            Spacer()
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder private var inhalt: some View {
        switch reiter {
        case .eingabe:
            TextField("Text eingeben", text: $text.text)
                .focused($fokus)
                .submitLabel(.done)
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .frame(height: 44)
                .background(SnapFarben.kachel, in: RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 16)
        case .schrift:
            optionsReihe {
                ForEach(SnapSchrift.allCases, id: \.self) { schrift in
                    auswahlKachel(titel: schrift.anzeigename, gewaehlt: text.schrift == schrift, schrift: schrift) { text.schrift = schrift }
                }
            }
        case .farbe:
            optionsReihe {
                ForEach(Array(SnapFarben.palette.enumerated()), id: \.offset) { _, farbe in
                    Button { text.farbe = farbe } label: {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(farbe)
                            .frame(width: 44, height: 44)
                            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.white, lineWidth: text.farbe == farbe ? 3 : 1).opacity(text.farbe == farbe ? 1 : 0.25))
                    }
                    .accessibilityLabel("Textfarbe")
                }
            }
        case .stil:
            optionsReihe {
                ForEach(SnapTextStil.allCases, id: \.self) { stil in
                    auswahlKachel(titel: stil.anzeigename, gewaehlt: text.stil == stil, schrift: .fett) { text.stil = stil }
                }
            }
        }
    }

    private func optionsReihe<Inhalt: View>(@ViewBuilder _ inhalt: () -> Inhalt) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) { inhalt() }.padding(.horizontal, 16)
        }
    }

    private func auswahlKachel(titel: String, gewaehlt: Bool, schrift: SnapSchrift, aktion: @escaping () -> Void) -> some View {
        Button(action: aktion) {
            Text(titel)
                .font(schrift.font(groesse: 16))
                .foregroundStyle(gewaehlt ? SnapFarben.akzent : .white)
                .frame(width: 84, height: 44)
                .background(SnapFarben.kachel, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(SnapFarben.akzent, lineWidth: gewaehlt ? 2 : 0))
        }
        .accessibilityLabel(titel)
        .accessibilityAddTraits(gewaehlt ? .isSelected : [])
    }
}

// MARK: - Zeichnen

struct SnapZeichnenPanel: View {
    @Binding var farbe: Color
    let kannZurueck: Bool
    let onZurueck: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(SnapFarben.palette.enumerated()), id: \.offset) { _, eintrag in
                        Button { farbe = eintrag } label: {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(eintrag)
                                .frame(width: 44, height: 44)
                                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.white, lineWidth: farbe == eintrag ? 3 : 1).opacity(farbe == eintrag ? 1 : 0.25))
                        }
                        .accessibilityLabel("Stiftfarbe")
                    }
                }
                .padding(.horizontal, 16)
            }
            HStack {
                SnapPanelKnopf(titel: "Rückgängig", symbol: "arrow.uturn.backward", aktion: onZurueck)
                    .opacity(kannZurueck ? 1 : 0.4)
                    .disabled(!kannZurueck)
                Spacer()
            }
            .padding(.horizontal, 16)
        }
        .padding(.top, 14)
        .padding(.bottom, 6)
    }
}
