import PhotosUI
import SwiftUI
import UIKit

private typealias SD = ZimmerSammlungDaten
private typealias SL = ZimmerSammlungLogik

/// Mixtape-Regal: eine Kassette pro Woche und Person (Spotify-Link). Tippen öffnet den Link.
struct ZimmerKassettenBlatt: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var link = ""
    @State private var titel = ""
    @State private var gelegt = 0
    @State private var fehler = false

    private var ich: Person { SD.ich }

    var body: some View {
        NavigationStack {
            Form {
                Section("Diese Woche") {
                    TextField("Spotify-Link", text: $link)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                    TextField("Titel (Lied und Name)", text: $titel)
                    if fehler { Text("Das ist kein Spotify-Link.").font(.footnote).foregroundStyle(.secondary) }
                    Button("Kassette ins Regal legen") { legen() }
                        .disabled(link.isEmpty || SL.bereinigt(titel, maximal: SL.titelMaximum) == nil)
                        .accessibilityLabel("Kassette ins Regal legen")
                }
                reihe(ich)
                reihe(ich.partner)
            }
            .navigationTitle("Mixtape")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
        }
        .sensoryFeedback(.success, trigger: gelegt)
        .presentationDetents([.medium, .large])
    }

    @ViewBuilder private func reihe(_ person: Person) -> some View {
        let liste = SD.kassetten(von: person).reversed()
        Section(person == ich ? "Meine Kassetten" : "Kassetten von \(person.name)") {
            if liste.isEmpty {
                Text("Noch keine Kassette. Ein Lied pro Woche reicht.").foregroundStyle(.secondary)
            }
            ForEach(Array(liste)) { k in
                Button {
                    if let url = SL.spotifyURL(k.url) { openURL(url) }
                } label: {
                    HStack {
                        Image(systemName: "recordingtape")
                        VStack(alignment: .leading) {
                            Text(k.titel)
                            Text(k.woche).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "play.circle")
                    }
                    .frame(minHeight: ProfilSlots.tippMinimum)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Kassette \(k.titel), Woche \(k.woche). In Spotify öffnen")
            }
        }
    }

    private func legen() {
        guard let url = SL.spotifyURL(link), let t = SL.bereinigt(titel, maximal: SL.titelMaximum) else { fehler = true; return }
        fehler = false
        SD.kassetteLegen(url: url.absoluteString, titel: t)
        link = ""
        titel = ""
        gelegt += 1
    }
}

/// Rezeptkasten: Karten mit Foto und Titel, "nochmal gekocht" gibt einen Stern.
struct ZimmerRezeptBlatt: View {
    @Environment(\.dismiss) private var dismiss
    @State private var titel = ""
    @State private var auswahl: PhotosPickerItem?
    @State private var foto: Data?
    @State private var gespeichert = 0

    var body: some View {
        NavigationStack {
            Form {
                Section("Neue Karte") {
                    TextField("Name des Gerichts", text: $titel)
                    PhotosPicker(selection: $auswahl, matching: .images) {
                        Label(foto == nil ? "Foto wählen" : "Foto gewählt", systemImage: "photo")
                            .frame(minHeight: ProfilSlots.tippMinimum)
                    }
                    Button("Karte in den Kasten") { speichern() }
                        .disabled(SL.bereinigt(titel, maximal: SL.titelMaximum) == nil)
                        .accessibilityLabel("Rezeptkarte speichern")
                }
                Section("Unsere Rezepte") {
                    let karten = SD.alleRezepte()
                    let gekocht = SD.gekochtAlle()
                    let meine = Set(SD.meineRezepte().map(\.id))
                    if karten.isEmpty { Text("Noch keine Karte.").foregroundStyle(.secondary) }
                    ForEach(karten) { r in
                        HStack(spacing: 12) {
                            miniatur(r.foto)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(r.titel)
                                sterne(SL.sterne(rezeptId: r.id, gekocht: gekocht))
                            }
                            Spacer()
                            Button {
                                SD.nochmalGekocht(rezeptId: r.id)
                                gespeichert += 1
                            } label: {
                                Image(systemName: "frying.pan").frame(minWidth: ProfilSlots.tippMinimum, minHeight: ProfilSlots.tippMinimum)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(r.titel) nochmal gekocht")
                        }
                        .swipeActions {
                            if meine.contains(r.id) {
                                Button("Löschen", role: .destructive) { SD.rezeptLoeschen(id: r.id) }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Rezeptkasten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
            .onChange(of: auswahl) { _, item in
                guard let item else { return }
                Task {
                    if let daten = try? await item.loadTransferable(type: Data.self), let bild = UIImage(data: daten) {
                        foto = SD.vorschau(bild)
                    }
                    auswahl = nil
                }
            }
        }
        .sensoryFeedback(.success, trigger: gespeichert)
        .presentationDetents([.medium, .large])
    }

    @ViewBuilder private func miniatur(_ daten: Data?) -> some View {
        if let daten, let bild = UIImage(data: daten) {
            Image(uiImage: bild).resizable().scaledToFill()
                .frame(width: 44, height: 44).clipShape(.rect(cornerRadius: 8))
                .accessibilityHidden(true)
        } else {
            Image(systemName: "fork.knife").frame(width: 44, height: 44)
                .background(.thinMaterial, in: .rect(cornerRadius: 8))
                .accessibilityHidden(true)
        }
    }

    private func sterne(_ n: Int) -> some View {
        HStack(spacing: 2) {
            ForEach(0..<min(n, 5), id: \.self) { _ in Image(systemName: "star.fill").font(.caption).foregroundStyle(ZimmerRitualeZeichnung.gold) }
            if n > 5 { Text("+\(n - 5)").font(.caption) }
            if n == 0 { Text("Noch nicht gekocht").font(.caption).foregroundStyle(.secondary) }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(n == 1 ? "1 Stern" : "\(n) Sterne")
    }

    private func speichern() {
        guard let t = SL.bereinigt(titel, maximal: SL.titelMaximum) else { return }
        SD.rezeptSpeichern(SL.Rezept(id: UUID().uuidString, titel: t, foto: foto))
        titel = ""
        foto = nil
        gespeichert += 1
    }
}

/// Wunschrolle: gemeinsame Wünsche. Beide haken ab, erst dann zählt der Punkt (Kühlschrank-Aufkleber).
struct ZimmerWunschrolleBlatt: View {
    @Environment(\.dismiss) private var dismiss
    @State private var eingabe = ""
    @State private var getippt = 0

    var body: some View {
        NavigationStack {
            Form {
                Section("Neuer Wunsch") {
                    TextField("Das wollen wir mal machen", text: $eingabe)
                    Button("Auf die Rolle schreiben") {
                        SD.wunschHinzu(eingabe)
                        eingabe = ""
                        getippt += 1
                    }
                    .disabled(SL.bereinigt(eingabe, maximal: SL.titelMaximum) == nil)
                    .accessibilityLabel("Wunsch aufschreiben")
                }
                Section("Unsere Rolle") {
                    let alle = SD.alleWuensche()
                    let meine = Set(SD.haken(von: SD.ich))
                    let partner = Set(SD.haken(von: SD.ich.partner))
                    let eigeneIds = Set(SD.wuensche(von: SD.ich).map(\.id))
                    if alle.isEmpty { Text("Noch leer. Ein Wunsch genügt.").foregroundStyle(.secondary) }
                    ForEach(alle) { w in
                        let beide = meine.contains(w.id) && partner.contains(w.id)
                        Button {
                            SD.hakenUmschalten(id: w.id)
                            getippt += 1
                        } label: {
                            HStack {
                                Image(systemName: beide ? "checkmark.circle.fill" : (meine.contains(w.id) ? "checkmark.circle" : "circle"))
                                    .foregroundStyle(beide ? ZimmerSammlungZeichnung.blatt : .secondary)
                                Text(w.text).strikethrough(beide)
                                Spacer()
                                if partner.contains(w.id) && !beide { Text(SD.ich.partner.name).font(.caption).foregroundStyle(.secondary) }
                            }
                            .frame(minHeight: ProfilSlots.tippMinimum)
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(w.text + (beide ? ", gemeinsam erledigt" : (meine.contains(w.id) ? ", von dir abgehakt" : ", offen")))
                        .accessibilityHint("Antippen zum Abhaken")
                        .swipeActions {
                            if eigeneIds.contains(w.id) {
                                Button("Löschen", role: .destructive) { SD.wunschLoeschen(id: w.id) }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Wunschrolle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
        }
        .sensoryFeedback(.selection, trigger: getippt)
        .presentationDetents([.medium, .large])
    }
}

/// Wachstumsleiste: Meilensteine ab dem Start, plus eigene Marken wie "Eingezogen".
struct ZimmerWachstumBlatt: View {
    @Environment(\.dismiss) private var dismiss
    @State private var titel = ""
    @State private var tag = Date()
    @State private var gesetzt = 0

    var body: some View {
        NavigationStack {
            Form {
                Section("Marken") {
                    let liste = SL.marken(heute: SD.heute, start: Meilenstein.start, eigene: SD.eigeneMarken())
                    ForEach(liste) { m in
                        HStack {
                            Image(systemName: m.erreicht ? "heart.fill" : "heart").foregroundStyle(m.erreicht ? Color.pink : .secondary)
                            Text(m.titel)
                            Spacer()
                            Text(m.tag).font(.caption).foregroundStyle(.secondary)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(m.titel), \(m.erreicht ? "erreicht" : "kommt noch"), \(m.tag)")
                    }
                }
                Section("Eigene Marke") {
                    HStack {
                        Button("Eingezogen") { titel = "Eingezogen" }.buttonStyle(.bordered)
                        Button("Erste Reise") { titel = "Erste Reise" }.buttonStyle(.bordered)
                    }
                    TextField("Name der Marke", text: $titel)
                    DatePicker("Datum", selection: $tag, displayedComponents: .date)
                    Button("Marke setzen") {
                        SD.markeHinzu(titel: titel, tag: Datum.text(tag))
                        titel = ""
                        gesetzt += 1
                    }
                    .disabled(SL.bereinigt(titel, maximal: 24) == nil)
                    .accessibilityLabel("Marke setzen")
                }
            }
            .navigationTitle("Wachstumsleiste")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
        }
        .sensoryFeedback(.success, trigger: gesetzt)
        .presentationDetents([.medium, .large])
    }
}
