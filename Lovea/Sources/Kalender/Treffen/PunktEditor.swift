import SwiftUI

/// Der Editor eines Punkts, aufgeklappt in der Liste: Titel, Zeit von bis, Ort, Notiz, Schalter
/// „Vor <Name> verstecken" und Löschen. Ein schon sichtbarer Punkt lässt sich nicht mehr verstecken.
struct PunktEditor: View {
    let datum: String
    let partner: Person
    @Binding var punkt: PunktBearbeitung
    let jetzt: Date
    var einklappen: () -> Void = {}
    var loeschen: () -> Void = {}
    var jetztFreigeben: () -> Void = {}

    private var auswahl: FreigabeAuswahl? { punkt.ueberraschung.map(FreigabeAuswahl.von) }
    private var stundenN: Int { punkt.ueberraschung?.art == .stunden ? (punkt.ueberraschung?.n ?? 3) : 3 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            kopf
            Divider().padding(.horizontal, 20)
            zeitZeile
            Divider().padding(.horizontal, 20)
            OrtWahlZeile(ort: $punkt.ort)
                .padding(.horizontal, 20)
            Divider().padding(.horizontal, 20)
            notizZeile
            Divider().padding(.horizontal, 20)
            verstecken
            Button(role: .destructive, action: loeschen) {
                Label("Punkt löschen", systemImage: "trash")
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 4)
        .background(Color.primary.opacity(0.055))
    }

    private var kopf: some View {
        HStack(spacing: 12) {
            TextField("Titel", text: $punkt.titel)
                .font(.headline)
                .frame(minHeight: 44)
            Button(action: einklappen) {
                Image(systemName: "chevron.down")
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Zuklappen")
        }
        .padding(.horizontal, 20)
    }

    private var zeitZeile: some View {
        HStack(spacing: 8) {
            Text("Von")
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            ZeitPille(datum: datum, zeit: $punkt.start, standard: "12:00") { punkt.ende = nil }
            Text("bis")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            ZeitPille(datum: datum, zeit: $punkt.ende, standard: Datum.uhrzeit(punkt.start ?? "12:00", plus: 60))
        }
        .frame(minHeight: 44)
        .padding(.horizontal, 20)
    }

    private var notizZeile: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "text.alignleft")
                .foregroundStyle(.secondary)
                .frame(height: 44)
            TextField("Notiz", text: $punkt.notiz, axis: .vertical)
                .lineLimit(1...4)
                .frame(minHeight: 44)
        }
        .padding(.horizontal, 20)
    }

    private var verstecken: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Vor \(partner.name) verstecken", isOn: Binding(
                get: { punkt.ueberraschung != nil },
                set: { punkt.ueberraschung = $0 ? FreigabeAuswahl.amTag.wahl(stunden: 3) : nil }
            ))
            .tint(Color.loveaRose)
            .frame(minHeight: 44)
            .disabled(punkt.schonSichtbar)
            if punkt.schonSichtbar {
                Text("Schon sichtbar. Löschen und neu anlegen.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else if let wahl = punkt.ueberraschung {
                Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                    GridRow {
                        chip(.dreiTage)
                        chip(.einTag)
                    }
                    GridRow {
                        chip(.amTag)
                        chip(.stunden)
                    }
                }
                if auswahl == .stunden {
                    HStack(spacing: 8) {
                        ForEach(FreigabeAuswahl.stundenWahl, id: \.self) { n in
                            wahlChip("\(n) Std.", an: stundenN == n) {
                                punkt.ueberraschung = FreigabeAuswahl.stunden.wahl(stunden: n)
                            }
                        }
                    }
                }
                Label(TreffenAnsichtWerte.sichtbarZeile(wahl, datum: datum, start: punkt.start, fuer: partner, jetzt: jetzt), systemImage: "clock")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if !punkt.neu {
                    Button("Jetzt freigeben", action: jetztFreigeben)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.loveaRose)
                        .frame(minHeight: 44)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 4)
    }

    private func chip(_ art: FreigabeAuswahl) -> some View {
        wahlChip(art.titel, an: auswahl == art) {
            punkt.ueberraschung = art.wahl(stunden: stundenN)
        }
    }

    private func wahlChip(_ titel: String, an: Bool, aktion: @escaping () -> Void) -> some View {
        Button {
            aktion()
            Haptik.auswahl()
        } label: {
            Text(titel)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, minHeight: 44)
                .foregroundStyle(an ? Color(uiColor: .systemBackground) : Color.primary)
                .background(an ? Color.primary : Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
                .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(an ? .isSelected : [])
    }
}

/// Eine Uhrzeit „HH:mm" als Pille mit Rad-Auswahl. Ohne Zeit steht „+ Zeit", mit Zeit löscht das
/// kleine Kreuz sie wieder.
struct ZeitPille: View {
    let datum: String
    @Binding var zeit: String?
    let standard: String
    var beimLoeschen: () -> Void = {}

    var body: some View {
        if let aktuell = zeit {
            HStack(spacing: 0) {
                DatePicker("Uhrzeit", selection: Binding(
                    get: { IPhoneKalenderDatum.kombiniert(datum, aktuell) },
                    set: { zeit = Datum.uhrzeit($0) }
                ), displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .environment(\.timeZone, Datum.kalender.timeZone)
                Button {
                    zeit = nil
                    beimLoeschen()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                        .frame(width: 36, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Zeit entfernen")
            }
        } else {
            Button {
                zeit = standard
            } label: {
                Label("Zeit", systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.loveaRose)
                    .padding(.horizontal, 11)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}
