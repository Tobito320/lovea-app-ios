import SwiftUI

/// Ein Punkt des Ablaufs in der Lesen-Ansicht: Zeit links, rechts Titel, Ort, Notiz und Kartenvorschau.
/// Ein versteckter Punkt des Partners ist ein unkenntlicher Block ohne Inhalt (nur Zeit, Schloss und
/// „sichtbar ab"), auch für VoiceOver.
struct PunktZeile: View {
    let punkt: TreffenPunkt
    let ansicht: PunktAnsicht
    let jetzt: Date

    var body: some View {
        switch ansicht {
        case .voll:
            zeile { voll }
        case .versteckt(let ab, let gleich):
            let text = TreffenAnsichtWerte.verstecktText(ab: ab, gleich: gleich, jetzt: jetzt)
            zeile { versteckt(text) }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(punkt.start.map { "\(text), um \($0)" } ?? text)
        }
    }

    private func zeile(@ViewBuilder _ inhalt: () -> some View) -> some View {
        HStack(alignment: .top, spacing: 0) {
            zeitSpalte
            inhalt().frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 12)
    }

    private var zeitSpalte: some View {
        let z = TreffenAnsichtWerte.zeitSpalte(start: punkt.start, ende: punkt.ende)
        return VStack(alignment: .leading, spacing: 2) {
            Text(z.oben)
                .font(.callout.weight(.semibold))
            if let unten = z.unten {
                Text(unten)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .monospacedDigit()
        .frame(width: 64, alignment: .leading)
    }

    private var voll: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(punkt.titel ?? "")
                .font(.headline)
            if let ort = punkt.ort {
                Label(ort.name, systemImage: "mappin.and.ellipse")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            if let notiz = punkt.notiz, !notiz.isEmpty {
                Text(notiz)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if let ort = punkt.ort {
                OrtVorschau(ort: ort)
                    .padding(.top, 6)
            }
            if punkt.versteckt {
                Label(TreffenAnsichtWerte.erstellerHinweis(fuer: punkt.von.partner, ab: punkt.sichtbarAb ?? jetzt, jetzt: jetzt), systemImage: "eye.slash")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }
        }
    }

    private func versteckt(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            balken(breite: 150, hoehe: 17)
            balken(breite: 220, hoehe: 13)
            balken(breite: 100, hoehe: 13)
            Label(text, systemImage: "lock.fill")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.top, 3)
        }
    }

    private func balken(breite: CGFloat, hoehe: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 7)
            .fill(Color.primary.opacity(0.07))
            .frame(maxWidth: breite, minHeight: hoehe, maxHeight: hoehe)
    }
}
