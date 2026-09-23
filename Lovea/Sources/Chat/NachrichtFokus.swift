import SwiftUI
import UIKit

/// A long-pressed bubble: its message, the ids of its photo stack and its global frame.
struct ChatFokus: Equatable {
    let id: String
    let stapel: [String]
    let rahmen: CGRect
}

/// Menu items that need the conversation's own state.
enum FokusWunsch { case antworten, bearbeiten, reaktionen, snapAnsehen, aufnahmenSpeichern }

/// Fix round 3: when a long press opened the focus layer, the tap that ends the same touch must not
/// also open the photo, snap or letter underneath.
/// Swallows at most one tap, within 2 s of the long press, so a later real tap always works.
@MainActor
enum LangDruck {
    private static var zeit: Date?
    static func merken() { zeit = Date() }
    static var geradeEben: Bool {
        guard let zeit else { return false }
        Self.zeit = nil
        return Date().timeIntervalSince(zeit) < 2
    }
}

/// Vertical placement around the focused bubble `rahmen`, inside `oben…unten`: the reaction bar
/// above the bubble (below it when there is no room), the menu below (above everything when there
/// is no room, pinned to the bottom as the last resort).
enum FokusLayout {
    static func positionen(rahmen r: CGRect, leiste: CGFloat, menue: CGFloat, oben: CGFloat, unten: CGFloat, abstand: CGFloat = 8) -> (leisteY: CGFloat, menueY: CGFloat) {
        let ueber = r.minY - abstand - leiste
        let leisteOben = ueber >= oben
        let leisteY = leisteOben ? ueber : max(oben, min(r.maxY + abstand, unten - leiste - abstand - menue))
        let startUnten = leisteOben ? r.maxY + abstand : leisteY + leiste + abstand
        let menueY: CGFloat
        if startUnten + menue <= unten {
            menueY = startUnten
        } else if leisteOben, ueber - abstand - menue >= oben {
            menueY = ueber - abstand - menue
        } else {
            menueY = max(oben, unten - menue)
        }
        return (leisteY, menueY)
    }

    /// Horizontal centre of an element `breite` wide, aligned to the bubble's side and kept on screen.
    static func mitteX(rahmen r: CGRect, breite: CGFloat, rechts: Bool, flaeche: CGFloat, rand: CGFloat = 8) -> CGFloat {
        let wunsch = rechts ? r.maxX - breite / 2 : r.minX + breite / 2
        return min(max(wunsch, rand + breite / 2), flaeche - rand - breite / 2)
    }
}

/// Spec 2.4/2.6, Z-33.1/Z-33.3: long press dims everything except the bubble, shows the glass
/// reaction bar above it and the glass menu below it. The bubble itself stays where it is.
struct NachrichtFokusEbene: View {
    let fokus: ChatFokus
    let nachricht: ChatModell.Nachricht
    let ich: Person
    let onWunsch: (FokusWunsch) -> Void
    let onSchliessen: () -> Void

    @State private var offen = false
    @State private var menueHoehe: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let leisteBreite: CGFloat = 344
    private static let leisteHoehe: CGFloat = 56
    private static let menueBreite: CGFloat = 250

    private var eigene: Bool { nachricht.von == ich }

    var body: some View {
        GeometryReader { geo in
            let ursprung = geo.frame(in: .global).origin
            let r = fokus.rahmen.offsetBy(dx: -ursprung.x, dy: -ursprung.y)
            let punkte = menuePunkte
            let hm = menueHoehe > 0 ? menueHoehe : CGFloat(punkte.count) * 45 + 8
            let lage = FokusLayout.positionen(
                rahmen: r, leiste: Self.leisteHoehe, menue: hm,
                oben: geo.safeAreaInsets.top + 8, unten: geo.size.height - geo.safeAreaInsets.bottom - 8
            )
            ZStack(alignment: .topLeading) {
                abdunkelung(r)
                leiste
                    .position(x: FokusLayout.mitteX(rahmen: r, breite: Self.leisteBreite, rechts: eigene, flaeche: geo.size.width), y: lage.leisteY + Self.leisteHoehe / 2)
                menue(punkte)
                    .position(x: FokusLayout.mitteX(rahmen: r, breite: Self.menueBreite, rechts: eigene, flaeche: geo.size.width), y: lage.menueY + hm / 2)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(reduceMotion ? .easeOut(duration: 0.2) : Feder.federnd) { offen = true }
        }
        .accessibilityAction(.escape) { schliessen() }
    }

    private func abdunkelung(_ r: CGRect) -> some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .overlay(Color.black.opacity(0.15))
            .mask {
                ZStack {
                    Rectangle()
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .frame(width: r.width + 6, height: r.height + 6)
                        .position(x: r.midX, y: r.midY)
                        .blendMode(.destinationOut)
                }
                .compositingGroup()
            }
            .opacity(offen ? 1 : 0)
            .contentShape(.rect)
            .onTapGesture { schliessen() }
            .accessibilityLabel("Schließen")
            .accessibilityAddTraits(.isButton)
    }

    private var leiste: some View {
        ReaktionsLeiste(ich: ich, aktuell: nachricht.reaktionen[ich], onWahl: { reaktion in
            ChatModell.shared.reagierenUmschalten(nachricht, reaktion, ich: ich)
            Haptik.mittel()
            schliessen()
        }, onMehr: { tun(.reaktionen) })
        .scaleEffect(offen || reduceMotion ? 1 : 0.5, anchor: eigene ? .bottomTrailing : .bottomLeading)
        .opacity(offen ? 1 : 0)
    }

    private func menue(_ punkte: [MenuePunkt]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(punkte.enumerated()), id: \.element.id) { index, punkt in
                if index > 0 { Divider().padding(.leading, 16) }
                zeile(punkt)
            }
        }
        .padding(.vertical, 4)
        .frame(width: Self.menueBreite)
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
        .onGeometryChange(for: CGFloat.self) { geo in geo.size.height } action: { menueHoehe = $0 }
        .scaleEffect(offen || reduceMotion ? 1 : 0.7, anchor: eigene ? .topTrailing : .topLeading)
        .opacity(offen ? 1 : 0)
    }

    @ViewBuilder private func zeile(_ punkt: MenuePunkt) -> some View {
        let beschriftung = HStack {
            Text(punkt.titel)
            Spacer(minLength: 12)
            Image(systemName: punkt.symbol)
        }
        .foregroundStyle(punkt.destruktiv ? Color.red : Color.primary)
        .padding(.horizontal, 16)
        .frame(minHeight: 44)
        .contentShape(.rect)

        if punkt.untermenue.isEmpty {
            Button(action: punkt.tun) { beschriftung }.buttonStyle(.plain)
        } else {
            Menu {
                ForEach(Array(punkt.untermenue.enumerated()), id: \.offset) { _, eintrag in
                    Button(eintrag.titel, action: eintrag.tun)
                }
            } label: { beschriftung }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Items (only what applies right now: time windows hide edit and unsend, Z-33.3)

    private var menuePunkte: [MenuePunkt] {
        let modell = ChatModell.shared
        let jetzt = Date()
        let text = nachricht.text ?? ""
        var liste = [MenuePunkt(id: "antworten", titel: "Antworten", symbol: "arrowshape.turn.up.left") { tun(.antworten) }]
        // Fix round 3: straight from the bubble, no need to open the photo first.
        if nachricht.snap == nil, fokusMedien.contains(where: { $0.typ == "foto" || $0.typ == "video" }) {
            liste.append(MenuePunkt(id: "aufnahmen", titel: "In Aufnahmen speichern", symbol: "square.and.arrow.down") { tun(.aufnahmenSpeichern) })
        }
        if !text.isEmpty {
            liste.append(MenuePunkt(id: "kopieren", titel: "Kopieren", symbol: "doc.on.doc") {
                UIPasteboard.general.string = text
                schliessen()
            })
        }
        if eigene, !text.isEmpty, nachricht.brief == nil,
           ChatZeitfenster.darfBearbeiten(gesendet: nachricht.zeit, bearbeitungen: nachricht.fassungen.count, jetzt: jetzt) {
            liste.append(MenuePunkt(id: "bearbeiten", titel: "Bearbeiten", symbol: "pencil") { tun(.bearbeiten) })
        }
        if nachricht.snap != nil, nachricht.snapAngesehen {
            liste.append(MenuePunkt(id: "snap", titel: "Erneut ansehen", symbol: "arrow.clockwise") { tun(.snapAnsehen) })
            if !nachricht.snapGespeichert {
                liste.append(MenuePunkt(id: "snapSpeichern", titel: "Speichern", symbol: "square.and.arrow.down") {
                    modell.snapGespeichertSenden(nachricht.id)
                    schliessen()
                })
            }
        }
        let fotos = lokaleFotos
        if nachricht.snap == nil, !fotos.isEmpty {
            liste.append(MenuePunkt(id: "galerie", titel: fotos.count > 1 ? "Alle in Zeichnungen speichern" : "In Zeichnungen speichern", symbol: "paintbrush.pointed") {
                for url in fotos { ChatGalerie.inGaleriesSpeichern(bildURL: url) }
                Haptik.erfolg()
                schliessen()
            })
        }
        liste.append(anheftenPunkt)
        let gesternt = nachricht.gesternt.contains(ich)
        liste.append(MenuePunkt(id: "stern", titel: gesternt ? "Stern entfernen" : "Stern", symbol: gesternt ? "star.slash" : "star") {
            modell.sternSetzen(nachricht.id, an: !gesternt)
            Haptik.auswahl()
            schliessen()
        })
        if nachricht.reaktionen[ich] != nil {
            liste.append(MenuePunkt(id: "reaktionWeg", titel: "Reaktion entfernen", symbol: "heart.slash") {
                modell.reagieren(nachricht.id, emoji: nil)
                schliessen()
            })
        }
        if eigene, ChatZeitfenster.darfZurueckziehen(gesendet: nachricht.zeit, jetzt: jetzt) {
            liste.append(MenuePunkt(id: "zurueck", titel: "Zurückziehen", symbol: "arrow.uturn.backward", destruktiv: true) { zurueckziehen() })
        }
        return liste
    }

    private var anheftenPunkt: MenuePunkt {
        let modell = ChatModell.shared
        if nachricht.angeheftet {
            return MenuePunkt(id: "loesen", titel: "Lösen", symbol: "pin.slash") {
                modell.loesen(nachricht.id)
                schliessen()
            }
        }
        let mitternacht = Calendar.berlin.nextDate(after: Date(), matching: DateComponents(hour: 0, minute: 0), matchingPolicy: .nextTime)
            ?? Date().addingTimeInterval(86_400)
        let id = nachricht.id
        var punkt = MenuePunkt(id: "anheften", titel: "Anheften", symbol: "pin") {}
        punkt.untermenue = [
            UnterPunkt(titel: "Für immer") { modell.anheften(id, bis: nil); schliessen() },
            UnterPunkt(titel: "Bis morgen") { modell.anheften(id, bis: mitternacht); schliessen() },
            UnterPunkt(titel: "1 Woche") { modell.anheften(id, bis: Date().addingTimeInterval(7 * 86_400)); schliessen() },
        ]
        return punkt
    }

    private var fokusMedien: [ChatModell.MedienEintrag] {
        fokus.stapel.compactMap { ChatModell.shared.nachricht($0) }.flatMap(\.medien)
    }

    private var lokaleFotos: [URL] {
        fokusMedien.filter { $0.typ == "foto" }.compactMap { MedienDatei.lokal($0) }
    }

    /// Unsend with the puff (the row animates `geloescht`). Re-checked at tap time: a menu opened
    /// at 1:59 must not unsend at 2:01.
    private func zurueckziehen() {
        let modell = ChatModell.shared
        let eigeneIDs = fokus.stapel.compactMap { modell.nachricht($0) }
            .filter { $0.von == ich && ChatZeitfenster.darfZurueckziehen(gesendet: $0.zeit, jetzt: Date()) }
            .map(\.id)
        if eigeneIDs.isEmpty {
            Haptik.warnung()
        } else {
            Haptik.mittel()
            withAnimation(Feder.weich) {
                for id in eigeneIDs { modell.loeschen(id) }
            }
        }
        schliessen()
    }

    private func tun(_ wunsch: FokusWunsch) {
        onWunsch(wunsch)
        schliessen()
    }

    private func schliessen() {
        withAnimation(reduceMotion ? .easeOut(duration: 0.15) : Feder.schnell, completionCriteria: .logicallyComplete) {
            offen = false
        } completion: {
            onSchliessen()
        }
    }
}

struct MenuePunkt: Identifiable {
    let id: String
    let titel: String
    let symbol: String
    var destruktiv = false
    var untermenue: [UnterPunkt] = []
    let tun: () -> Void

    init(id: String, titel: String, symbol: String, destruktiv: Bool = false, tun: @escaping () -> Void) {
        self.id = id
        self.titel = titel
        self.symbol = symbol
        self.destruktiv = destruktiv
        self.tun = tun
    }
}

struct UnterPunkt {
    let titel: String
    let tun: () -> Void
}

/// Z-33.3: editing as a sheet with a real text field (no alert). Earlier versions listed below.
struct BearbeitenBlatt: View {
    let nachricht: ChatModell.Nachricht
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @FocusState private var fokussiert: Bool

    private var neu: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Nachricht", text: $text, axis: .vertical)
                    .lineLimit(1...10)
                    .focused($fokussiert)
                if !nachricht.fassungen.isEmpty {
                    Section("Frühere Fassungen") {
                        ForEach(Array(nachricht.fassungen.enumerated()), id: \.offset) { _, alt in
                            Text(alt).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern", action: sichern)
                        .disabled(neu.isEmpty || neu == nachricht.text)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .onAppear {
            text = nachricht.text ?? ""
            fokussiert = true
        }
    }

    private func sichern() {
        // The sheet may have stayed open past the window (Z-33.3).
        guard let aktuell = ChatModell.shared.nachricht(nachricht.id),
              ChatZeitfenster.darfBearbeiten(gesendet: aktuell.zeit, bearbeitungen: aktuell.fassungen.count, jetzt: Date())
        else {
            Haptik.warnung()
            dismiss()
            return
        }
        ChatModell.shared.bearbeiten(nachricht.id, text: neu)
        Haptik.erfolg()
        dismiss()
    }
}
