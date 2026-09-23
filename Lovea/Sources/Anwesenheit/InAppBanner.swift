import Observation
import SwiftUI

/// Z-7.3 ("Nur in der App", Spec 12): partner online (höchstens einmal pro 15 min), „zeichnet
/// gerade an …“, Anstupsen/Kuss. `AppRootView` overlays `InAppBannerView` on the tab bar.
@MainActor
@Observable
final class BannerZentrale {
    static let shared = BannerZentrale()

    struct Banner: Identifiable, Equatable, Sendable {
        enum Aktion: Equatable, Sendable { case keine, zeichnung(String) }
        let id = UUID()
        var text: String
        var aktion: Aktion = .keine
    }

    private(set) var aktuell: Banner?

    private var ausblendenTask: Task<Void, Never>?
    private var letztesOnlineBanner = Date.distantPast
    private var vorherPartnerDa = false
    private var vorherZeichnungDrin: String?

    private init() {
        FigurenModell.shared.aufFrischeGeste = { [weak self] person, art in
            guard person != Raum.shared.ich else { return }
            let text: String
            switch art {
            case .anstupsen: text = "\(person.name) stupst dich an"
            case .kuss: text = "\(person.name) schickt dir einen Kuss"
            default: return
            }
            self?.zeigenFallsErlaubt(Banner(text: text), kategorie: "geste")
        }

        Task { @MainActor [weak self] in
            while let self {
                self.periodischPruefen()
                try? await Task.sleep(for: .seconds(5))
            }
        }
    }

    private func periodischPruefen() {
        let partnerDa = Raum.shared.partnerDa
        if partnerDa, !vorherPartnerDa, Date().timeIntervalSince(letztesOnlineBanner) > 900 {
            letztesOnlineBanner = Date()
            zeigenFallsErlaubt(Banner(text: "\(Raum.shared.ich?.partner.name ?? "Er/Sie") ist online"), kategorie: nil)
        }
        vorherPartnerDa = partnerDa

        let drin = LiveZeichnung.shared.partnerDrin
        if let drin, drin != vorherZeichnungDrin {
            let name = TeilenModell.shared.stand.projekte[drin]?.wert.name
                ?? TeilenModell.shared.stand.staende[drin]?.wert.name ?? "ihrem Bild"
            let partner = Raum.shared.ich?.partner.name ?? "Sie"
            zeigenFallsErlaubt(Banner(text: "\(partner) zeichnet gerade an „\(name)“ – zuschauen?", aktion: .zeichnung(drin)), kategorie: "zeichnen")
        }
        vorherZeichnungDrin = drin
    }

    private func zeigenFallsErlaubt(_ banner: Banner, kategorie: String?) {
        if let kategorie, !EinstellungenModell.shared.bool("mitteilungen.\(kategorie)", default: true) { return }
        aktuell = banner
        ausblendenTask?.cancel()
        ausblendenTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled, let self, self.aktuell?.id == banner.id else { return }
            self.aktuell = nil
        }
    }

    /// Tapped or dismissed — always clears, tap on a drawing banner also runs `aufZeichnung`.
    func antippen(aufZeichnung: (String) -> Void) {
        if case .zeichnung(let id) = aktuell?.aktion { aufZeichnung(id) }
        ausblendenTask?.cancel()
        aktuell = nil
    }
}

/// Glas-Kapsel oben, 3 s, antippbar (Z-7.3).
struct InAppBannerView: View {
    var aufZeichnungGetippt: (String) -> Void = { _ in }

    private let zentrale = BannerZentrale.shared

    var body: some View {
        if let banner = zentrale.aktuell {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                Text(banner.text)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .glassEffect(.regular.interactive(), in: .capsule)
            .padding(.top, 8)
            .onTapGesture { zentrale.antippen(aufZeichnung: aufZeichnungGetippt) }
            .transition(.move(edge: .top).combined(with: .opacity))
            .animation(.spring(duration: 0.3), value: zentrale.aktuell?.id)
            .id(banner.id)
        }
    }
}
