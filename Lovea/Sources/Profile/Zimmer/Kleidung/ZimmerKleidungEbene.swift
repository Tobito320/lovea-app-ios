import SwiftUI

/// Merkt sich je Person die zuletzt getragenen Outfits (neueste zuerst), gefaltet aus den eigenen
/// `figur.aussehen`-Ops. Eigene Ops kommen doppelt an, darum wird nach `op.id` entdoppelt.
@MainActor @Observable
final class ZimmerKleiderVerlauf {
    static let shared = ZimmerKleiderVerlauf()
    private(set) var verlauf: [Person: [FigurAussehen]] = [:]
    @ObservationIgnored private var gesehen: Set<String> = []

    private init() {
        Raum.shared.beobachten(["figur.aussehen", "figur.aussehenFuer"]) { [weak self] op in
            guard let self, self.gesehen.insert(op.id).inserted,
                  let ziel = FigurenModell.aussehenZiel(op) else { return }
            self.verlauf[ziel.person] = ZimmerZustandLogik.verlauf(self.verlauf[ziel.person] ?? [], neu: ziel.aussehen)
        }
    }
}

/// Kleiderstange mit den letzten fünf Outfits, aufklappbarer Schrank mit der gekauften Kleidung und
/// das Paket am Boden für einen neuen Kauf. Nur im Panorama; liegt über dem Kleiderschrank-Slot.
struct ZimmerKleidungEbene: View {
    let welt: ProfilWelt
    let eigen: Bool

    init(welt: ProfilWelt = .panorama, eigen: Bool = true) {
        self.welt = welt
        self.eigen = eigen
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var offen = false
    @State private var blatt = false
    @State private var gesehen: Set<String>?
    @State private var auspacken: String?
    @State private var zaehler = 0
    @State private var erfolg = 0

    private var person: Person {
        let ich = Raum.shared.ich ?? .ahmed
        return eigen ? ich : ich.partner
    }

    private var kleidung: [String] {
        let besitz = PunkteModell.shared.einkaufsStand(preis: { ShopKatalog.artikel($0)?.preis }).besitz.besitz[person] ?? []
        return besitz
            .filter { FigurAussehen.shopTeile[$0] != nil && ShopKatalog.artikel($0) != nil }
            .sorted { (ShopKatalog.artikel($0)?.name ?? $0) < (ShopKatalog.artikel($1)?.name ?? $1) }
    }

    private var schluessel: String { "lovea.zimmer.schrank.gesehen.\(person.rawValue)" }

    var body: some View {
        if welt == .panorama {
            let haptik = Haptik.an
            let stand = kleidung
            let paket: String? = {
                guard eigen, let gesehen else { return nil }
                return ZimmerZustandLogik.neuePakete(besitz: Set(stand), gesehen: gesehen).first
            }()
            GeometryReader { geo in
                let k = geo.size.width / welt.breite
                let oben = geo.size.height - SzenenZeichnung.hoehe * k
                let v = welt.versatz(.kleiderschrank)
                let schrankRect = CGRect(x: 291 + v.width, y: 196 + v.height, width: 90, height: 116)
                ZStack {
                    stange(k: k, rect: ZimmerMoebel.stange.offsetBy(dx: v.width, dy: v.height), oben: oben)
                    schrank(k: k, rect: schrankRect, oben: oben, anzahl: stand.count)
                    if let paket {
                        paketKnopf(paket, k: k, rect: CGRect(x: 261 + v.width, y: 318 + v.height, width: 28, height: 28), schrankX: schrankRect.midX, oben: oben)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
            .sensoryFeedback(.selection, trigger: zaehler) { _, _ in haptik }
            .sensoryFeedback(.success, trigger: erfolg) { _, _ in haptik }
            .sheet(isPresented: $blatt, onDismiss: { bewegen { offen = false } }) { schrankBlatt(stand) }
            .task(id: schluessel) { laden(stand) }
        }
    }

    // MARK: Kleiderstange

    @ViewBuilder
    private func stange(k: CGFloat, rect r: CGRect, oben: CGFloat) -> some View {
        let aktuell = FigurenModell.shared.aussehen(person)
        let liste = ZimmerKleiderVerlauf.shared.verlauf[person] ?? []
        let looks = liste.isEmpty ? [aktuell] : liste
        let zelle = max(40, CGFloat(ProfilSlots.tippMinimum) / k)
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(Array(looks.enumerated()), id: \.offset) { i, look in
                    let traegt = ZimmerZustandLogik.gleicheKleidung(aktuell, look)
                    Button { anziehen(look) } label: {
                        VStack(spacing: 0) {
                            Capsule().fill(Pal.holz.farbe).frame(width: 2 * k, height: 6 * k)
                            FigurView(look, zustand: .ruhig, groesse: r.height * k * 0.9, animiert: false, ganzkoerper: true)
                                .overlay(alignment: .bottomTrailing) {
                                    if traegt {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 24 * k))
                                            .foregroundStyle(.green)
                                    }
                                }
                        }
                        .frame(width: zelle * k, height: r.height * k)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!eigen)
                    .accessibilityLabel("Outfit \(i + 1) von \(looks.count) anziehen")
                    .accessibilityValue(traegt ? "Gerade getragen" : "")
                }
            }
        }
        .simultaneousGesture(DragGesture(minimumDistance: 20).onChanged { w in
            if abs(w.translation.width) > abs(w.translation.height) { TabWischSperre.shared.beanspruchen() }
        })
        .frame(width: r.width * k, height: r.height * k)
        .position(x: r.midX * k, y: oben + r.midY * k)
    }

    private func anziehen(_ look: FigurAussehen) {
        guard eigen else { return }
        let jetzt = FigurenModell.shared.aussehen(person)
        let neuer = jetzt.mitKleidung(von: look)
        guard neuer != jetzt else { return }
        FigurenModell.shared.aussehenSichern(neuer)
        zaehler += 1
    }

    // MARK: Schrank

    private func schrank(k: CGFloat, rect r: CGRect, oben: CGFloat, anzahl: Int) -> some View {
        let holz = Pal.holz.farbe
        let tuer = r.width / 2 * k
        return Button { oeffnen() } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 4 * k).fill(.black.opacity(0.55))
                    .overlay {
                        Image(systemName: "tshirt.fill").font(.system(size: 22 * k)).foregroundStyle(.white.opacity(0.5))
                    }
                HStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 3 * k).fill(holz)
                        .overlay(alignment: .trailing) { Circle().fill(.white.opacity(0.8)).frame(width: 4 * k).padding(.trailing, 4 * k) }
                        .frame(width: tuer)
                        .rotation3DEffect(.degrees(offen ? -100 : 0), axis: (x: 0, y: 1, z: 0), anchor: .leading, perspective: 0.5)
                    RoundedRectangle(cornerRadius: 3 * k).fill(holz)
                        .overlay(alignment: .leading) { Circle().fill(.white.opacity(0.8)).frame(width: 4 * k).padding(.leading, 4 * k) }
                        .frame(width: tuer)
                        .rotation3DEffect(.degrees(offen ? 100 : 0), axis: (x: 0, y: 1, z: 0), anchor: .trailing, perspective: 0.5)
                }
            }
            .frame(width: r.width * k, height: r.height * k)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .position(x: r.midX * k, y: oben + r.midY * k)
        .accessibilityLabel("Kleiderschrank öffnen")
        .accessibilityValue("\(anzahl) Teile")
    }

    private func oeffnen() {
        zaehler += 1
        bewegen { offen = true }
        Task {
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 0 : 450))
            blatt = true
        }
    }

    private func bewegen(_ f: () -> Void) {
        if reduceMotion { f() } else { withAnimation(Feder.federnd) { f() } }
    }

    private func schrankBlatt(_ stand: [String]) -> some View {
        NavigationStack {
            ScrollView {
                if stand.isEmpty {
                    Text("Noch keine Kleidung gekauft.").foregroundStyle(.secondary).padding(.top, 40)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 10)], spacing: 10) {
                        ForEach(stand, id: \.self) { id in
                            let name = ShopKatalog.artikel(id)?.name ?? id
                            let brille = FigurAussehen.shopTeile[id]?.feld == .brille
                            Button { teilAnziehen(id) } label: {
                                VStack(spacing: 6) {
                                    Image(systemName: brille ? "eyeglasses" : "tshirt.fill").font(.title2)
                                    Text(name).font(.caption).lineLimit(2).multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity, minHeight: 80)
                                .padding(6)
                                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                            .disabled(!eigen)
                            .accessibilityLabel("\(name) anziehen")
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Kleiderschrank")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
    }

    private func teilAnziehen(_ id: String) {
        guard eigen else { return }
        var a = FigurenModell.shared.aussehen(person)
        a.anziehen(id)
        FigurenModell.shared.aussehenSichern(a)
        zaehler += 1
    }

    // MARK: Paket

    private func paketKnopf(_ id: String, k: CGFloat, rect r: CGRect, schrankX: CGFloat, oben: CGFloat) -> some View {
        let name = ShopKatalog.artikel(id)?.name ?? "Kleidung"
        let weg = auspacken == id
        return Button { packeAus(id) } label: {
            Image(systemName: weg ? "gift.fill" : "shippingbox.fill")
                .font(.system(size: 22 * k))
                .foregroundStyle(Pal.holz.farbe)
                .frame(width: max(r.width * k, 44), height: max(r.height * k, 44))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .scaleEffect(weg ? 0.2 : 1)
        .opacity(weg ? 0 : 1)
        .offset(weg ? CGSize(width: (schrankX - r.midX) * k, height: -60 * k) : .zero)
        .position(x: r.midX * k, y: oben + r.midY * k)
        .accessibilityLabel("Neues Paket auspacken: \(name)")
    }

    private func packeAus(_ id: String) {
        erfolg += 1
        if reduceMotion {
            markieren(id)
            return
        }
        withAnimation(.spring(duration: 0.35, bounce: 0.5)) { auspacken = id }
        bewegen { offen = true }
        Task {
            try? await Task.sleep(for: .milliseconds(700))
            markieren(id)
            auspacken = nil
            bewegen { offen = false }
        }
    }

    private func markieren(_ id: String) {
        var s = gesehen ?? []
        s.insert(id)
        gesehen = s
        UserDefaults.standard.set(Array(s), forKey: schluessel)
    }

    private func laden(_ stand: [String]) {
        if let a = UserDefaults.standard.stringArray(forKey: schluessel) {
            gesehen = Set(a)
        } else {
            // Erster Start: bisheriger Besitz gilt als ausgepackt, nur neue Käufe kommen als Paket.
            gesehen = Set(stand)
            UserDefaults.standard.set(stand, forKey: schluessel)
        }
    }
}
