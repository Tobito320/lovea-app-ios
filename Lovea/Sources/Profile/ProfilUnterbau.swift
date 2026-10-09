import SwiftUI

/// p69: the four tabs of the part under the scene.
enum ProfilReiter: String, CaseIterable, Identifiable {
    case zimmer, wir, erinnerungen, quests

    var id: String { rawValue }

    var titel: String {
        switch self {
        case .zimmer: "Zimmer"
        case .wir: "Wir"
        case .erinnerungen: "Erinnerungen"
        case .quests: "Quests"
        }
    }
}

/// p69: one block of the part under the scene. `titel` nil: a bar of buttons or chips that is always there;
/// with a `titel`: a card that folds open and shut. `inhalt` runs only when the block is on screen, so a
/// closed card builds nothing (the map of "Die Karte" does not load until it is opened).
struct ProfilAbschnitt: Identifiable {
    let id: String
    let reiter: ProfilReiter
    var titel: String?
    /// False: the block has nothing to show and is left out instead of drawing an empty card.
    var sichtbar: Bool
    let inhalt: () -> AnyView

    @MainActor
    init<V: View>(_ id: String, _ reiter: ProfilReiter, titel: String? = nil, sichtbar: Bool = true,
                  @ViewBuilder inhalt: @escaping () -> V) {
        self.id = id
        self.reiter = reiter
        self.titel = titel
        self.sichtbar = sichtbar
        self.inhalt = { AnyView(inhalt()) }
    }
}

/// p69: which tabs show, which one is chosen, which cards start open. Pure, so it is tested.
enum ProfilReiterLogik {
    /// The tabs with at least one block to show, in the fixed order. A tab with nothing in it is not drawn.
    static func sichtbar(_ abschnitte: [ProfilAbschnitt]) -> [ProfilReiter] {
        ProfilReiter.allCases.filter { r in abschnitte.contains { $0.reiter == r && $0.sichtbar } }
    }

    /// The chosen tab, or the first one when nothing is chosen yet or the chosen one has vanished.
    static func gewaehlt(_ wahl: ProfilReiter?, unter sichtbar: [ProfilReiter]) -> ProfilReiter? {
        if let wahl, sichtbar.contains(wahl) { return wahl }
        return sichtbar.first
    }

    /// The blocks of one tab that have something to show.
    static func abschnitte(_ alle: [ProfilAbschnitt], in reiter: ProfilReiter?) -> [ProfilAbschnitt] {
        alle.filter { $0.reiter == reiter && $0.sichtbar }
    }

    /// Cards start shut. The one exception: a card alone in its tab starts open, a shut card as the only
    /// thing in a tab would be a second tap for nothing.
    static func startOffen(_ abschnitt: ProfilAbschnitt, in liste: [ProfilAbschnitt]) -> Bool {
        abschnitt.titel != nil && liste.filter { $0.titel != nil }.count == 1
    }

    /// A tab strip only makes sense with a choice.
    static func zeigtLeiste(_ sichtbar: [ProfilReiter]) -> Bool { sichtbar.count > 1 }
}

/// p69: pull-to-refresh of the part under the scene: fetches what the partner changed since, and the weather.
enum ProfilAktualisieren {
    @MainActor
    static func laufen() async {
        await Raum.shared.nachholenBisFertig(timeout: .seconds(6))
        await WetterModell.shared.aktualisieren()
    }
}

/// p69: the part under the scene. The scene (`kopf`) stands still on top when `klebt` and only the rest
/// scrolls; otherwise everything scrolls as one. One tab at a time is built, lazily; cards are shut and
/// build their content only when opened. Pull-to-refresh sits on the lower scroll view, so it can only
/// start at its top and never in the scene (in the whole-scroll fallback there is none).
struct ProfilUnterbau<Kopf: View>: View {
    let abschnitte: [ProfilAbschnitt]
    let klebt: Bool
    let kopf: Kopf

    @State private var wahl: ProfilReiter?
    /// Cards the person flipped away from their start state. Kept here, so they stay as they are after a
    /// sheet, the editor or the shop closes.
    @State private var umgeschaltet: Set<String> = []
    @State private var position = ScrollPosition(edge: .top)

    /// `start`: the tab that shows first (nil: the first one with something in it).
    init(abschnitte: [ProfilAbschnitt], klebt: Bool, start: ProfilReiter? = nil, @ViewBuilder kopf: () -> Kopf) {
        self.abschnitte = abschnitte
        self.klebt = klebt
        self.kopf = kopf()
        _wahl = State(initialValue: start)
    }

    var body: some View {
        if klebt {
            VStack(spacing: 0) {
                kopf
                rolle(mitKopf: false)
            }
        } else {
            rolle(mitKopf: true)
        }
    }

    /// The scroll view with the tabs. Pull-to-refresh only where the scene stands outside it (`klebt`): with
    /// the scene inside, a pull at the top would start the refresh from the picture.
    @ViewBuilder
    private func rolle(mitKopf: Bool) -> some View {
        let scroll = rolleOhneRefresh(mitKopf: mitKopf)
        if klebt {
            scroll.refreshable { await ProfilAktualisieren.laufen() }
        } else {
            scroll
        }
    }

    private func rolleOhneRefresh(mitKopf: Bool) -> some View {
        let sichtbar = ProfilReiterLogik.sichtbar(abschnitte)
        let aktiv = ProfilReiterLogik.gewaehlt(wahl, unter: sichtbar)
        let liste = ProfilReiterLogik.abschnitte(abschnitte, in: aktiv)
        return ScrollView {
            VStack(spacing: 0) {
                if mitKopf { kopf }
                LazyVStack(alignment: .leading, spacing: 16, pinnedViews: klebt ? [.sectionHeaders] : []) {
                    Section {
                        ForEach(liste) { a in zeile(a, liste) }
                    } header: {
                        if ProfilReiterLogik.zeigtLeiste(sichtbar) { ProfilReiterLeiste(reiter: sichtbar, aktiv: aktiv, waehle: waehle) }
                    }
                }
                .padding(.top, 6)
                .padding(.bottom, ProfilLayout.schlussPolster)
            }
        }
        .scrollPosition($position)
    }

    @ViewBuilder
    private func zeile(_ a: ProfilAbschnitt, _ liste: [ProfilAbschnitt]) -> some View {
        Group {
            if let titel = a.titel {
                let start = ProfilReiterLogik.startOffen(a, in: liste)
                ProfilKlappKarte(titel: titel, offen: Binding(
                    get: { start != umgeschaltet.contains(a.id) },
                    set: { neu in
                        if neu == start { umgeschaltet.remove(a.id) } else { umgeschaltet.insert(a.id) }
                    }
                ), inhalt: a.inhalt)
            } else {
                a.inhalt()
            }
        }
        .padding(.horizontal, 16)
    }

    private func waehle(_ r: ProfilReiter) {
        Haptik.auswahl()
        wahl = r
        // A new tab starts at its top, not wherever the last one was left. (Whole-scroll mode leaves the
        // place alone: the scene is up there and the strip is what the person is looking at.)
        if klebt { position.scrollTo(edge: .top) }
    }
}

/// p69: a card under the scene that folds open and shut. The header is a button over its whole width and at
/// least 52 pt tall; the content is built only while the card is open.
struct ProfilKlappKarte: View {
    let titel: String
    @Binding var offen: Bool
    let inhalt: () -> AnyView
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Written out: the private `reduceMotion` would make the memberwise one private, and the render gallery builds it too.
    init(titel: String, offen: Binding<Bool>, inhalt: @escaping () -> AnyView) {
        self.titel = titel
        _offen = offen
        self.inhalt = inhalt
    }

    var body: some View {
        VStack(spacing: 0) {
            Button {
                Haptik.auswahl()
                withAnimation(reduceMotion ? nil : Feder.weich) { offen.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Text(titel)
                        .font(.title3.bold())
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(offen ? 90 : 0))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .frame(minHeight: 52)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(.isHeader)
            .accessibilityValue(offen ? "geöffnet" : "geschlossen")
            if offen {
                Divider()
                VStack(spacing: 0) { inhalt() }
            }
        }
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}
