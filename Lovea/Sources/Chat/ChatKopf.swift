import CoreLocation
import SwiftUI
import UIKit

/// Status line pieces of the header (pure, tested).
enum ChatKopfLogik {
    /// A saved place's short label: its own name when short, else the category's word.
    static func ortLabel(name: String, kategorie: String) -> String {
        let getrimmt = name.trimmingCharacters(in: .whitespaces)
        if !getrimmt.isEmpty, getrimmt.count <= 12 { return getrimmt }
        switch kategorie {
        case "zuhause": return "Home"
        case "gym": return "Gym"
        case "arbeit": return "Arbeit"
        case "schule": return "Schule"
        default: return getrimmt.isEmpty ? "Ort" : getrimmt
        }
    }
}

/// Street + number for a coordinate, reverse-geocoded once per ~100 m and kept for the session.
@MainActor
enum KurzAdresse {
    private static var cache: [String: String] = [:]

    static func schluessel(_ lat: Double, _ lon: Double) -> String {
        String(format: "%.3f,%.3f", lat, lon)
    }

    static func laden(lat: Double, lon: Double) async -> String? {
        let k = schluessel(lat, lon)
        if let bekannt = cache[k] { return bekannt }
        // ponytail: `CLGeocoder` like InfoKarteView/ProfilKarte/OrtePOI; all move to
        // `MKReverseGeocodingRequest` together once it's compiled against.
        guard let orte = try? await CLGeocoder().reverseGeocodeLocation(CLLocation(latitude: lat, longitude: lon)),
              let p = orte.first
        else { return nil }
        let text = [p.thoroughfare, p.subThoroughfare].compactMap { $0 }.joined(separator: " ")
        guard !text.isEmpty else { return p.locality }
        cache[k] = text
        return text
    }
}

/// Where the partner is, for the header and the chat list: saved place (short label) → live street
/// address (loaded by the caller into `adresse`) → the figure's place state as last resort.
@MainActor
enum PartnerOrt {
    private static let figurOrte: Set<FigurZustand> = [.schule, .arbeit, .gym, .zuhause, .fahrschule, .supermarkt]

    static func text(_ partner: Person, adresse: String?) -> String? {
        if let position = Standort.shared.positionen[partner] {
            if let ort = gespeichert(partner, position) { return ChatKopfLogik.ortLabel(name: ort.name, kategorie: ort.kategorie) }
            if let adresse { return adresse }
        }
        let figurOrt = FigurenModell.shared.zustand[partner]?.haupt
        return figurOrt.flatMap { figurOrte.contains($0) ? $0.titel : nil }
    }

    /// Changes whenever the address would need a new lookup (~100 m cell).
    static func adressSchluessel(_ partner: Person) -> String {
        guard let position = Standort.shared.positionen[partner] else { return "" }
        return KurzAdresse.schluessel(position.lat, position.lon)
    }

    /// Only outside every saved place; cached per cell.
    static func adresseLaden(_ partner: Person) async -> String? {
        guard let position = Standort.shared.positionen[partner], gespeichert(partner, position) == nil else { return nil }
        return await KurzAdresse.laden(lat: position.lat, lon: position.lon)
    }

    /// The partner's own saved places first, then any (e.g. a shared "Home").
    private static func gespeichert(_ partner: Person, _ position: StandortDaten) -> Ort? {
        let hier = CLLocation(latitude: position.lat, longitude: position.lon)
        let treffer = OrteModell.shared.orte.filter {
            CLLocation(latitude: $0.lat, longitude: $0.lon).distance(from: hier) <= $0.radius
        }
        return treffer.first { $0.person == partner } ?? treffer.first
    }
}

/// Z-32.2 (fix round 2): the conversation header is ONE glass capsule — back chevron (→ chat list), the
/// partner's live figure head, name and status "zuletzt … · Home" (tap → partner profile), and
/// FaceTime audio/video as compact icon buttons inside the capsule on the right.
struct ChatKopf: View {
    let partner: Person
    let modell: ChatModell
    let onZurueck: () -> Void
    let onProfil: () -> Void
    @State private var hinweis: String?
    @State private var adresse: String?

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 2) {
                zurueckKnopf
                profilKnopf
                anrufKnopf(audio: true)
                anrufKnopf(audio: false)
            }
            .padding(.leading, 4)
            .padding(.trailing, 6)
            .frame(minHeight: 56)
            .glassEffect(.regular, in: .capsule)
            if let hinweis {
                Text(hinweis)
                    .font(.footnote.weight(.medium))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .glassEffect(.regular, in: .capsule)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 2)
        .task(id: hinweis) {
            guard hinweis != nil else { return }
            try? await Task.sleep(for: .seconds(2.5))
            withAnimation(Feder.weich) { hinweis = nil }
        }
        // Street address only when the partner is outside every saved place; cached per ~100 m.
        .task(id: PartnerOrt.adressSchluessel(partner)) {
            if let neu = await PartnerOrt.adresseLaden(partner) { adresse = neu }
        }
    }

    private var zurueckKnopf: some View {
        Button {
            Haptik.leicht()
            onZurueck()
        } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 40, height: 44)
                .contentShape(.rect)
        }
        .buttonStyle(.federnd)
        .accessibilityLabel("Zurück zu den Chats")
    }

    private var profilKnopf: some View {
        Button {
            Haptik.leicht()
            onProfil()
        } label: {
            HStack(spacing: 10) {
                KopfFigur(person: partner, groesse: 40)
                VStack(alignment: .leading, spacing: 1) {
                    // Name with "online"/"zuletzt …" beside it; the line below is only "tippt …" or the place.
                    TimelineView(.everyMinute) { _ in
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(partner.name).font(.headline).lineLimit(1).layoutPriority(1)
                            Text(anwesenheit).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                    if let zweite = tippt ? "tippt …" : PartnerOrt.text(partner, adresse: adresse) {
                        Text(zweite)
                            .font(.caption)
                            .foregroundStyle(tippt ? Color.person(partner) : Color.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
                .layoutPriority(1)
                Spacer(minLength: 0)
            }
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(partner.name), \(status)")
        .accessibilityHint("Profil öffnen")
        .accessibilityAddTraits(.isButton)
    }

    /// Compact icon button inside the capsule: a tinted circle, not a second glass layer (no glass on glass).
    private func anrufKnopf(audio: Bool) -> some View {
        Button { anrufen(audio: audio) } label: {
            Image(systemName: audio ? "phone.fill" : "video.fill")
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 36, height: 36)
                .background(Color.primary.opacity(0.1), in: .circle)
                .frame(width: 44, height: 44)
                .contentShape(.circle)
        }
        .buttonStyle(.federnd)
        .accessibilityLabel(audio ? "FaceTime Audio" : "FaceTime Video")
    }

    private var tippt: Bool { FigurenModell.shared.anzeige(partner).haupt == .tippt }

    /// "tippt …" wins; otherwise "online"/"zuletzt …" plus where the partner is right now.
    private var status: String {
        if tippt { return "tippt …" }
        return [anwesenheit, PartnerOrt.text(partner, adresse: adresse)].compactMap { $0 }.joined(separator: " · ")
    }

    private var anwesenheit: String {
        if Raum.shared.partnerDa { return "online" }
        let zuletzt = [FigurenModell.shared.partnerZuletztGesehen[partner], modell.letzteAktivitaet[partner]].compactMap { $0 }.max()
        guard let zuletzt else { return "offline" }
        return "zuletzt " + ZeitText.relativ(zuletzt)
    }

    private func anrufen(audio: Bool) {
        guard let url = FaceTime.url(audio: audio, kontakt: FaceTime.kontakt(von: partner)) else {
            Haptik.warnung()
            withAnimation(Feder.federnd) { hinweis = "\(partner.name) hat noch keine FaceTime-Nummer eingetragen" }
            return
        }
        Haptik.leicht()
        UIApplication.shared.open(url)
    }
}

/// Round head crop of a figure (header 40 pt live, read receipt 18 pt still): the head sits in the
/// top of FigurView's canvas, so the view is drawn 1.35× and clipped to a top-aligned circle.
struct KopfFigur: View {
    let person: Person
    let groesse: CGFloat
    var animiert = true

    var body: some View {
        let anzeige = FigurenModell.shared.anzeige(person)
        FigurView(FigurenModell.shared.aussehen(person), zustand: anzeige.haupt, abzeichen: anzeige.abzeichen, groesse: groesse * 1.35, animiert: animiert, bildrate: 20)
            .frame(width: groesse, height: groesse, alignment: .top)
            .clipShape(.circle)
            .background(Color.person(person).opacity(0.18), in: .circle)
    }
}

/// Z-33.4: pinned messages as one slim glass bar under the header, at most three, tap jumps there.
struct ChatAngeheftetLeiste: View {
    let modell: ChatModell
    let onSpringeZu: (String) -> Void

    var body: some View {
        let angeheftet = Array(modell.angeheftete.suffix(3))
        if !angeheftet.isEmpty {
            HStack(spacing: 8) {
                Image(systemName: "pin.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                ForEach(Array(angeheftet.enumerated()), id: \.element.id) { index, nachricht in
                    if index > 0 { Divider().frame(height: 18) }
                    Button {
                        Haptik.auswahl()
                        onSpringeZu(nachricht.id)
                    } label: {
                        Text(ChatVorschau.inhalt(nachricht))
                            .font(.footnote)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Angeheftet: \(ChatVorschau.inhalt(nachricht))")
                    .accessibilityHint("Zur Nachricht springen")
                }
            }
            .padding(.horizontal, 16)
            .glassEffect(.regular, in: .capsule)
            .padding(.horizontal, 12)
        }
    }
}
