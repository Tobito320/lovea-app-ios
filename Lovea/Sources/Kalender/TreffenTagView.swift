import SwiftUI

/// Z-9.6 Treffen-Tag: Herz, Uhrzeit, „Was machen wir", Notizen beider mit Namen, Checkliste,
/// dazu Im-/Export mit dem iPhone-Kalender.
struct TreffenTagView: View {
    let datum: String
    let kalender = KalenderModell.shared

    @State private var wasMachenWir = ""
    @State private var hatZeit = false
    @State private var uhrzeit = Date()
    @State private var neueAufgabe = ""
    @State private var neueNotiz = ""
    @State private var zeigtExport = false
    @State private var zeigtImport = false

    // Fresh formatter per call: DateFormatter is a class and not Sendable, so a shared `static
    // let` would trip Swift 6 strict concurrency (same reasoning as `Op.isoFormatierer`).
    private static func titel(_ datum: Date) -> String {
        let f = DateFormatter()
        f.calendar = Datum.kalender
        f.locale = Locale(identifier: "de_DE")
        f.dateFormat = "EEEE, d. MMMM"
        return f.string(from: datum)
    }

    private var eintrag: KalenderModell.TreffenEintrag? { kalender.zustand.treffenText[datum] }
    private var checkliste: [KalenderModell.ChecklistEintrag] { kalender.zustand.checklisten[datum] ?? [] }
    private var ich: Person { Raum.shared.ich ?? .ahmed }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Label(Self.titel(Datum.datum(datum)), systemImage: "heart.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.loveaRose)

                if let vorherige = eintrag?.vorherige {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Vorherige Fassung von \(vorherige.von.name)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(vorherige.text)
                            .font(.callout)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Was machen wir")
                        .font(.subheadline.weight(.semibold))
                    TextField("z. B. Kino", text: $wasMachenWir)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { senden() }
                    Toggle("Mit Uhrzeit", isOn: $hatZeit)
                    if hatZeit {
                        DatePicker("Uhrzeit", selection: $uhrzeit, displayedComponents: .hourAndMinute)
                    }
                    Button("Sichern") { senden() }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.loveaRose)
                        .disabled(wasMachenWir.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Notizen")
                        .font(.subheadline.weight(.semibold))
                    ForEach(Person.allCases, id: \.self) { person in
                        notizZeile(person)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Checkliste")
                        .font(.subheadline.weight(.semibold))
                    ForEach(checkliste) { aufgabe in
                        checklistZeile(aufgabe)
                    }
                    HStack {
                        TextField("Neuer Punkt", text: $neueAufgabe)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit { aufgabeHinzufuegen() }
                        Button("Hinzufügen", action: aufgabeHinzufuegen)
                            .disabled(neueAufgabe.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }

                HStack(spacing: 10) {
                    Button("Zum iPhone-Kalender") { zeigtExport = true }
                        .buttonStyle(.bordered)
                    Button("Aus iPhone-Kalender holen") { zeigtImport = true }
                        .buttonStyle(.bordered)
                }
                .frame(minHeight: 44)
            }
            .padding()
        }
        .navigationTitle("Treffen")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            wasMachenWir = eintrag?.text ?? ""
            if let uhrzeitText = eintrag?.uhrzeit { hatZeit = true; uhrzeit = IPhoneKalenderDatum.kombiniert(datum, uhrzeitText) }
        }
        .sheet(isPresented: $zeigtExport) {
            let start = IPhoneKalenderDatum.kombiniert(datum, hatZeit ? Self.uhrzeitText(uhrzeit) : nil)
            IPhoneKalenderExportBlatt(titel: wasMachenWir.isEmpty ? "Treffen" : wasMachenWir, start: start, ende: start.addingTimeInterval(2 * 60 * 60))
        }
        .sheet(isPresented: $zeigtImport) { IPhoneKalenderImport(datum: datum) }
    }

    private func notizZeile(_ person: Person) -> some View {
        let gespeichert = kalender.zustand.notizen[datum]?[person]
        return VStack(alignment: .leading, spacing: 4) {
            Text(person.name)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.person(person))
            if person == ich {
                TextField("Deine Notiz", text: $neueNotiz)
                    .textFieldStyle(.roundedBorder)
                    .onAppear { if neueNotiz.isEmpty { neueNotiz = gespeichert ?? "" } }
                    .onSubmit {
                        Raum.shared.senden("notiz.setzen", ["datum": datum, "text": neueNotiz])
                    }
            } else {
                Text(gespeichert?.isEmpty == false ? gespeichert! : "Noch keine Notiz")
                    .font(.callout)
                    .foregroundStyle(gespeichert == nil ? .secondary : .primary)
            }
        }
    }

    private func checklistZeile(_ aufgabe: KalenderModell.ChecklistEintrag) -> some View {
        HStack {
            Button {
                Raum.shared.senden("checkliste.setzen", CheckOp(datum: datum, id: aufgabe.id, text: aufgabe.text, erledigt: !aufgabe.erledigt))
            } label: {
                Image(systemName: aufgabe.erledigt ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(aufgabe.erledigt ? Color.loveaRose : .secondary)
            }
            Text(aufgabe.text)
                .strikethrough(aufgabe.erledigt)
                .foregroundStyle(aufgabe.erledigt ? .secondary : .primary)
            Spacer()
            Button {
                Raum.shared.senden("checkliste.loeschen", ["datum": datum, "id": aufgabe.id])
            } label: {
                Image(systemName: "trash").foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .frame(minHeight: 32)
    }

    private func aufgabeHinzufuegen() {
        let text = neueAufgabe.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        Raum.shared.senden("checkliste.setzen", CheckOp(datum: datum, id: UUID().uuidString, text: text, erledigt: false))
        neueAufgabe = ""
    }

    private func senden() {
        let text = wasMachenWir.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        Raum.shared.senden("treffen.setzen", TreffenOp(datum: datum, uhrzeit: hatZeit ? Self.uhrzeitText(uhrzeit) : nil, wasMachenWir: text))
    }

    private static func uhrzeitText(_ datum: Date) -> String {
        let komponenten = Datum.kalender.dateComponents([.hour, .minute], from: datum)
        return String(format: "%02d:%02d", komponenten.hour ?? 0, komponenten.minute ?? 0)
    }
}

private struct TreffenOp: Codable { var datum: String; var uhrzeit: String?; var wasMachenWir: String? }
private struct CheckOp: Codable { var datum: String; var id: String; var text: String; var erledigt: Bool }
