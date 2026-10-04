import SwiftUI

/// Studio, Öffnungszeit und Slot in einer Zeile. Reine Ansicht, ohne Steuerelemente.
struct StudioKopf: View {
    let studio: GymStudio
    let slotStart: Int?
    let dauer: Int

    private var slotText: String {
        guard let slotStart else { return "keine feste Uhrzeit" }
        return "Slot \(Datum.uhrzeit(minuten: slotStart)) · \(dauer) min"
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "building.2.fill")
                .foregroundStyle(.tint)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(studio.name).font(.headline)
                Text("\(GymOeffnung.kurztext(studio)) · \(slotText)")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.up.chevron.down").font(.caption).foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
    }
}

/// Warnung: geplanter Slot liegt außerhalb der Öffnungszeiten. Reine Ansicht.
struct OeffnungsWarnKarte: View {
    let studio: GymStudio
    let zeilen: [String]

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 4) {
                Text("Slot außerhalb der Öffnungszeit").font(.subheadline.weight(.semibold))
                ForEach(zeilen, id: \.self) { Text($0).font(.footnote) }
                Text("\(studio.name): Zeiten unsicher, vorher prüfen.").font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color.orange.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// Die eine Einhänge-Stelle im Trainingsplan: Studio wählen, Slot setzen, Warnung (nur wenn es eine gibt).
struct StudioEinhang: View {
    let person: Person
    /// Wochentage aller festen Trainingstage des Plans, 1 = Mo … 7 = So.
    let wochentage: [Int]
    private var gedaechtnis: StudioGedaechtnis { .shared }

    private var profil: StudioProfil { gedaechtnis.profil(person) }

    private var uhrzeit: Binding<Date> {
        Binding {
            let m = profil.slotStart ?? 5 * 60
            return Calendar.current.date(bySettingHour: m / 60, minute: m % 60, second: 0, of: Date()) ?? Date()
        } set: { neu in
            let t = Calendar.current.dateComponents([.hour, .minute], from: neu)
            var p = profil
            p.slotStart = (t.hour ?? 0) * 60 + (t.minute ?? 0)
            gedaechtnis.setzen(p, person)
        }
    }

    private var festeUhrzeit: Binding<Bool> {
        Binding {
            profil.slotStart != nil
        } set: { an in
            var p = profil
            p.slotStart = an ? (p.slotStart ?? 5 * 60) : nil
            gedaechtnis.setzen(p, person)
        }
    }

    var body: some View {
        let p = profil
        let zeilen = GymOeffnung.zeilen(GymOeffnung.warnungen(p.studio, wochentage: wochentage, start: p.slotStart, dauer: p.dauer))
        Section {
            Menu {
                Picker("Studio", selection: Binding(get: { p.studio }, set: { neu in
                    var x = p
                    x.studio = neu
                    gedaechtnis.setzen(x, person)
                })) {
                    ForEach(GymStudio.allCases, id: \.self) { Text($0.name).tag($0) }
                }
            } label: {
                StudioKopf(studio: p.studio, slotStart: p.slotStart, dauer: p.dauer)
            }
            .buttonStyle(.plain)
            Toggle("Feste Uhrzeit", isOn: festeUhrzeit)
            if p.slotStart != nil {
                DatePicker("Beginn", selection: uhrzeit, displayedComponents: .hourAndMinute)
            }
            if !zeilen.isEmpty {
                OeffnungsWarnKarte(studio: p.studio, zeilen: zeilen)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            }
        } header: {
            Text("Studio")
        }
    }
}
