import SwiftUI

/// Reine SwiftUI-Teile des Date-Ideen-Fensters (Entwurf A "Verzeichnis"). Ohne List, Swipe und TextField,
/// damit `DatesRenderInhalt` sie in der Render-Tafel zeichnen kann.
enum DatesStil {
    static let grau = Color(uiColor: .systemGray)
    static let haarlinie = Color.primary.opacity(0.11)
    static let chipGrund = Color.primary.opacity(0.07)
    static let umgekehrt = Color(uiColor: .systemBackground)
}

struct DatesHaarlinie: View {
    var body: some View { Rectangle().fill(DatesStil.haarlinie).frame(height: 0.5) }
}

struct DatesHaken: View {
    let erledigt: Bool

    var body: some View {
        ZStack {
            if erledigt {
                Circle().fill(Color.loveaRose)
                Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)).foregroundStyle(.white)
            } else {
                Circle().strokeBorder(DatesStil.grau, lineWidth: 2)
            }
        }
        .frame(width: 26, height: 26)
        .frame(width: 44, height: 44)
        .contentShape(Rectangle())
    }
}

struct DatesZeileInhalt: View {
    let idee: DateIdee
    /// nil in der Render-Tafel: dann nur das Bild des Hakens.
    var beiHaken: (() -> Void)?
    var beiOeffnen: (() -> Void)?

    var body: some View {
        HStack(spacing: 5) {
            haken
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(idee.titel)
                        .font(.body.weight(.semibold))
                        .strikethrough(idee.erledigt, color: DatesStil.grau)
                        .foregroundStyle(idee.erledigt ? DatesStil.grau : Color.primary)
                        .lineLimit(2)
                    if let ort = DatesAnsichtLogik.ortZeile(idee) {
                        HStack(spacing: 5) {
                            Image(systemName: "mappin").font(.caption2).foregroundStyle(DatesStil.grau)
                            Text(ort).font(.subheadline.weight(.medium)).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                }
                Spacer(minLength: 0)
                if !idee.links.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "link").font(.caption2)
                        Text("\(idee.links.count)").font(.footnote.weight(.semibold))
                    }
                    .foregroundStyle(DatesStil.grau)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture { beiOeffnen?() }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(DatesAnsichtLogik.sprechtext(idee))
            .accessibilityAddTraits(beiOeffnen == nil ? [] : .isButton)
            .accessibilityHint(beiOeffnen == nil ? "" : "Öffnet die Idee")
        }
        .padding(.leading, 8)
        .padding(.trailing, 20)
        .padding(.vertical, 6)
        .frame(minHeight: 56)
        .overlay(alignment: .bottom) { DatesHaarlinie() }
    }

    @ViewBuilder private var haken: some View {
        if let beiHaken {
            Button(action: beiHaken) { DatesHaken(erledigt: idee.erledigt) }
                .buttonStyle(.plain)
                .accessibilityLabel(idee.erledigt ? "Als offen markieren" : "Als erledigt markieren")
                .accessibilityValue(idee.erledigt ? "erledigt" : "offen")
        } else {
            DatesHaken(erledigt: idee.erledigt)
        }
    }
}

struct DatesAbschnittKopf: View {
    let abschnitt: DatesAbschnitt

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(abschnitt.kategorie.titel.uppercased())
                .font(.caption.weight(.bold))
                .tracking(1)
                .foregroundStyle(DatesStil.grau)
            Spacer()
            Text(abschnitt.zaehler)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 7)
        .overlay(alignment: .bottom) { DatesHaarlinie() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(abschnitt.kategorie.titel), \(abschnitt.erledigt) von \(abschnitt.gesamt) erledigt")
        .accessibilityAddTraits(.isHeader)
    }
}

struct DatesKopf: View {
    let erledigt: Int
    let gesamt: Int
    @ScaledMetric(relativeTo: .largeTitle) private var gross: CGFloat = 84

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("\(erledigt)")
                    .font(.system(size: gross, weight: .bold))
                    .tracking(-4)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text("von \(gesamt) erledigt")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            DatesLineal(erledigt: erledigt, gesamt: gesamt)
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
        .padding(.bottom, 14)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(erledigt) von \(gesamt) Ideen erledigt")
    }
}

/// Ein Strich je Idee, die erledigten zuerst und hoch in Rose.
struct DatesLineal: View {
    let erledigt: Int
    let gesamt: Int

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<min(gesamt, 150), id: \.self) { i in
                Rectangle()
                    .fill(i < erledigt ? Color.loveaRose : DatesStil.haarlinie)
                    .frame(maxWidth: 4)
                    .frame(height: i < erledigt ? 18 : 10)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 18, alignment: .leading)
        .frame(height: 18, alignment: .bottom)
    }
}

struct DatesChip: View {
    let titel: String
    var symbol: String?
    var pfeil = false
    var aktiv = false

    var body: some View {
        HStack(spacing: 5) {
            if let symbol { Image(systemName: symbol).font(.caption2.weight(.semibold)).opacity(0.8) }
            Text(titel).font(.subheadline.weight(.semibold)).lineLimit(1)
            if pfeil { Image(systemName: "chevron.down").font(.caption2.weight(.bold)).opacity(0.8) }
        }
        .padding(.horizontal, 13)
        .frame(minHeight: 34)
        .foregroundStyle(aktiv ? DatesStil.umgekehrt : Color.primary)
        .background(aktiv ? Color.primary : DatesStil.chipGrund, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }
}

struct DatesUndoLeiste: View {
    let titel: String
    /// 1 = voll, 0 = Zeit um.
    let rest: Double
    /// nil in der Render-Tafel.
    var beiRueckgaengig: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            Text("„\(titel)“ gelöscht")
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .foregroundStyle(DatesStil.umgekehrt)
            Spacer(minLength: 8)
            if let beiRueckgaengig {
                Button(action: beiRueckgaengig) { rueckgaengig }
                    .buttonStyle(.plain)
            } else {
                rueckgaengig
            }
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 52)
        .background(Color.primary)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.loveaRose).frame(height: 3)
                .scaleEffect(x: max(rest, 0), anchor: .leading)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.2), radius: 12, y: 4)
        .padding(.horizontal, 12)
        .accessibilityElement(children: .contain)
    }

    private var rueckgaengig: some View {
        Text("Rückgängig")
            .font(.subheadline.weight(.bold))
            .foregroundStyle(Color.loveaRose)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
    }
}
