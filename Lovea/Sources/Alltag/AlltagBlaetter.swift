import PhotosUI
import SwiftUI
import UIKit

/// Der Plattenspieler: ein Song für beide. Der Link kommt aus Spotify (Teilen, Link kopieren) und wird
/// hier eingefügt; Titel, Künstler und Cover holt `SpotifyAbfrage` einmal und die Op trägt sie zum Gegenüber.
/// Es gibt keinen Ton und keine Anmeldung: Tippen öffnet den Song in Spotify.
struct PlatteBlatt: View {
    private let speicher = AlltagSpeicher.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var eingabe = ""
    @State private var laedt = false
    @State private var fehler: String?
    @FocusState private var fokus: Bool

    var body: some View {
        NavigationStack {
            List {
                if let p = speicher.stand.platte {
                    Section { aufgelegt(p) }
                }
                Section {
                    TextField("Spotify-Link", text: $eingabe)
                        .focused($fokus)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .onSubmit(auflegen)
                    PasteButton(payloadType: String.self) { texte in
                        guard let text = texte.first else { return }
                        Task { @MainActor in
                            eingabe = text
                            auflegen()
                        }
                    }
                    Button(action: auflegen) {
                        if laedt {
                            ProgressView().frame(maxWidth: .infinity, minHeight: 44)
                        } else {
                            Text("Auflegen").frame(maxWidth: .infinity, minHeight: 44)
                        }
                    }
                    .disabled(laedt || AlltagLogik.spotifyId(in: eingabe) == nil)
                    if let fehler {
                        Text(fehler).font(.footnote).foregroundStyle(.red)
                    }
                } header: {
                    Text("Neuer Song")
                } footer: {
                    Text("In Spotify beim Song auf Teilen und Link kopieren, dann hier einfügen. Die Platte dreht sich nur, Ton gibt es in Spotify.")
                }
            }
            .navigationTitle("Plattenspieler")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
        }
    }

    private func aufgelegt(_ p: PlatteEintrag) -> some View {
        Button { if let url = p.link { openURL(url) } } label: {
            HStack(spacing: 14) {
                cover(p.cover)
                VStack(alignment: .leading, spacing: 3) {
                    Text(p.titel).font(.headline).multilineTextAlignment(.leading)
                    if let kuenstler = p.kuenstler {
                        Text(kuenstler).font(.subheadline).foregroundStyle(.secondary)
                    }
                    Text("\(p.von.name) hat sie aufgelegt").font(.caption).foregroundStyle(.secondary)
                    Label("In Spotify öffnen", systemImage: "arrow.up.forward.app")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.loveaRose)
                }
                Spacer(minLength: 0)
            }
            .frame(minHeight: 44)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Öffnet den Song in Spotify")
    }

    /// Das Cover als Schallplatte mit Loch. Lädt erst, wenn dieses Blatt offen ist.
    private func cover(_ adresse: String?) -> some View {
        AsyncImage(url: adresse.flatMap { URL(string: $0) }) { phase in
            switch phase {
            case .success(let bild):
                bild.resizable().scaledToFill()
            default:
                Color(uiColor: .tertiarySystemFill).overlay { Image(systemName: "music.note").foregroundStyle(.secondary) }
            }
        }
        .frame(width: 88, height: 88)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.primary.opacity(0.15), lineWidth: 1))
        .overlay(Circle().fill(Color(uiColor: .systemBackground)).frame(width: 14, height: 14))
        .accessibilityHidden(true)
    }

    private func auflegen() {
        guard !laedt else { return }
        guard let id = AlltagLogik.spotifyId(in: eingabe) else {
            fehler = "Das ist kein Link zu einem Spotify-Song."
            return
        }
        fehler = nil
        laedt = true
        Task {
            let titel = await SpotifyAbfrage.laden(id: id)
            laedt = false
            guard let titel else {
                fehler = "Der Song konnte nicht geladen werden. Prüf die Verbindung und versuch es nochmal."
                return
            }
            speicher.platteSetzen(titel)
            Haptik.erfolg()
            eingabe = ""
            fokus = false
        }
    }
}

/// Der Wecker auf dem Nachttisch: wann die andere Person aufsteht, wer zuerst, meine eigene Zeit und ein
/// Tipp für "Guten Morgen". Der Wecker ist ein Hinweis für euch beide, das Handy klingelt davon nicht.
struct WeckerBlatt: View {
    private let speicher = AlltagSpeicher.shared
    @Environment(\.dismiss) private var dismiss
    @AppStorage("lovea.gruss.morgenTag") private var morgenTag = ""
    @State private var an: Bool
    @State private var zeit: Date

    init() {
        let meiner = AlltagSpeicher.shared.ich.flatMap { AlltagSpeicher.shared.stand.wecker[$0] }
        _an = State(initialValue: meiner?.an ?? false)
        _zeit = State(initialValue: Self.uhrzeit(minuten: meiner?.minuten ?? 7 * 60))
    }

    private static func uhrzeit(minuten: Int) -> Date {
        Calendar.current.date(bySettingHour: minuten / 60, minute: minuten % 60, second: 0, of: Date()) ?? Date()
    }

    private var minuten: Int {
        let k = Calendar.current.dateComponents([.hour, .minute], from: zeit)
        return (k.hour ?? 7) * 60 + (k.minute ?? 0)
    }

    private var morgenGesendet: Bool { morgenTag == Datum.text(Date()) }

    private var morgenFrei: Bool {
        let jetzt = Date()
        return GrussFenster.knopf(stunde: Calendar.berlin.component(.hour, from: jetzt), jetzt: jetzt, letzteNacht: nil,
                                  morgenGesendetHeute: morgenGesendet) == "morgen"
    }

    var body: some View {
        let ich = speicher.ich
        let partner = ich?.partner
        let wecker = speicher.stand.wecker
        let seine = AlltagLogik.weckzeit(partner.flatMap { wecker[$0] })
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 4) {
                        Text(seine ?? "–:–")
                            .font(.system(size: 52, weight: .bold, design: .rounded))
                            .monospacedDigit()
                        Text(partner.map { "Wecker von \($0.name)" } ?? "Wecker")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        if let ich {
                            Text(AlltagLogik.aufstehSatz(ich: ich, wecker))
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Color.loveaRose)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .accessibilityElement(children: .combine)
                }
                Section {
                    Toggle("Mein Wecker", isOn: $an).tint(Color.loveaRose)
                    DatePicker("Weckzeit", selection: $zeit, displayedComponents: .hourAndMinute).disabled(!an)
                } footer: {
                    Text("Nur ein Hinweis für euch beide. Dein Handy klingelt davon nicht.")
                }
                Section {
                    Button {
                        Haptik.mittel()
                        FigurenModell.shared.grussSenden("morgen")
                        morgenTag = Datum.text(Date())
                    } label: {
                        Label(morgenGesendet ? "Guten Morgen gesagt" : "Guten Morgen sagen", systemImage: "sun.max.fill")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .disabled(!morgenFrei)
                } footer: {
                    Text(morgenGesendet ? "Heute schon gesagt." : "Guten Morgen geht einmal am Tag, von 4 bis 9 Uhr.")
                }
            }
            .navigationTitle("Wecker")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
        }
        .onChange(of: an) { _, _ in speichern() }
        .onChange(of: zeit) { _, _ in speichern() }
        .presentationDetents([.medium, .large])
    }

    private func speichern() {
        speicher.weckerSetzen(minuten: minuten, an: an)
    }
}

/// Der Spiegel: das Outfit-Foto der anderen Person von heute und mein eigenes. Ein Foto hängt einen Tag.
struct SpiegelBlatt: View {
    private let speicher = AlltagSpeicher.shared
    @Environment(\.dismiss) private var dismiss
    @State private var laedt = false
    @State private var fehler: String?

    private var heute: String { Datum.text(Date()) }

    var body: some View {
        let ich = speicher.ich
        let partner = ich?.partner
        let seins = partner.flatMap { AlltagLogik.outfit(speicher.stand, von: $0, heute: heute) }
        let meins = ich.flatMap { AlltagLogik.outfit(speicher.stand, von: $0, heute: heute) }
        let name = partner?.name ?? "deinem Schatz"
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Outfit von \(name)").font(.headline)
                        if let seins {
                            polaroid(seins)
                        } else {
                            Text("Heute hängt noch nichts am Spiegel.").font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Mein Outfit heute").font(.headline)
                        if let meins {
                            polaroid(meins)
                            Button("Abnehmen", role: .destructive) { speicher.outfitHaengen(medium: nil) }
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        AlltagFotoKnoepfe(gewaehlt: foto)
                        if laedt { ProgressView("Foto wird aufgehängt").frame(maxWidth: .infinity) }
                        if let fehler { Text(fehler).font(.footnote).foregroundStyle(.red) }
                        Text("Das Foto hängt einen Tag am Spiegel von \(name).").font(.footnote).foregroundStyle(.secondary)
                    }
                }
                .padding(16)
            }
            .navigationTitle("Spiegel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
        }
    }

    private func polaroid(_ id: String) -> some View {
        ProfilFoto(medienId: id)
            .frame(width: 240, height: 320)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .padding(10)
            .padding(.bottom, 22)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: .black.opacity(0.15), radius: 8, y: 3)
            .rotationEffect(.degrees(-2))
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Outfit-Foto")
    }

    private func foto(_ daten: Data) {
        Task {
            laedt = true
            fehler = nil
            let id = await AlltagFoto.hochladen(daten)
            laedt = false
            guard let id else {
                fehler = "Das Foto konnte nicht hochgeladen werden. Versuch es gleich nochmal."
                return
            }
            speicher.outfitHaengen(medium: id)
            Haptik.erfolg()
        }
    }
}

/// Der Kühlschrank: Einkaufs- und Aufgabenzettel für beide. Abhaken geht auf beiden Handys, der Zettel
/// darf ein Essensfoto tragen und einen TikTok- oder Instagram-Link mit kurzer Beschreibung. Tippen
/// öffnet den Link, langes Drücken zeigt die Beschreibung.
struct KuehlschrankBlatt: View {
    private let speicher = AlltagSpeicher.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var neu = ""
    @State private var link = ""
    @State private var notiz = ""
    @State private var bild: String?
    @State private var bildLaedt = false
    @State private var mehr = false
    @State private var fehler: String?
    @FocusState private var fokus: Bool

    private var linkOk: Bool {
        let t = link.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty || AlltagLogik.zettelLink(t) != nil
    }

    private var darfHaengen: Bool {
        AlltagLogik.kurz(neu, hoechstens: AlltagLogik.zettelMaxZeichen) != nil && linkOk && !bildLaedt
    }

    var body: some View {
        NavigationStack {
            let liste = speicher.zettel
            List {
                Section {
                    TextField("Was fehlt oder ist zu tun?", text: $neu)
                        .focused($fokus)
                        .submitLabel(.done)
                        .onSubmit(haengen)
                    DisclosureGroup("Video, Beschreibung, Foto", isExpanded: $mehr) {
                        TextField("TikTok- oder Instagram-Link", text: $link)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        if !linkOk {
                            Text("Nur Links von TikTok oder Instagram.").font(.footnote).foregroundStyle(.red)
                        }
                        TextField("Kurze Beschreibung", text: $notiz, axis: .vertical).lineLimit(1...4)
                        if let bild {
                            ProfilFoto(medienId: bild)
                                .frame(height: 140)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            Button("Foto entfernen", role: .destructive) { self.bild = nil }
                        } else {
                            AlltagFotoKnoepfe(gewaehlt: bildHochladen)
                        }
                        if bildLaedt { ProgressView().frame(maxWidth: .infinity) }
                        if let fehler { Text(fehler).font(.footnote).foregroundStyle(.red) }
                    }
                    Button("Aufhängen", action: haengen)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .disabled(!darfHaengen)
                } footer: {
                    Text("Ihr seht beide dieselben Zettel und dürft beide abhaken.")
                }
                Section("Am Kühlschrank") {
                    if liste.isEmpty {
                        Text("Noch nichts am Kühlschrank.").foregroundStyle(.secondary)
                    }
                    ForEach(liste) { z in zeile(z) }
                }
            }
            .navigationTitle("Kühlschrank")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
        }
    }

    private func zeile(_ z: KuehlZettel) -> some View {
        let url = z.link.flatMap { URL(string: $0) }
        return HStack(spacing: 8) {
            Button {
                Haptik.auswahl()
                speicher.zettelAbhaken(z)
            } label: {
                Image(systemName: z.erledigt ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(z.erledigt ? Color.loveaRose : .secondary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(z.erledigt ? "Wieder offen setzen" : "Abhaken")
            Button { if let url { openURL(url) } } label: {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(z.text)
                            .strikethrough(z.erledigt)
                            .foregroundStyle(z.erledigt ? .secondary : .primary)
                            .multilineTextAlignment(.leading)
                        if url != nil {
                            Label("Video", systemImage: "play.rectangle.fill")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer(minLength: 0)
                    if let bild = z.bild {
                        ProfilFoto(medienId: bild)
                            .frame(width: 52, height: 52)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
                .frame(minHeight: 44)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityHint(url != nil ? "Öffnet das Video" : "")
        }
        .accessibilityValue(z.erledigt ? "erledigt" : "offen")
        .contextMenu {
            if let url {
                Button { openURL(url) } label: { Label("Video öffnen", systemImage: "play.rectangle") }
            }
            Button(role: .destructive) { speicher.zettelLoeschen(z) } label: { Label("Wegnehmen", systemImage: "trash") }
        } preview: {
            ZettelVorschau(zettel: z)
        }
        .swipeActions { Button("Wegnehmen", role: .destructive) { speicher.zettelLoeschen(z) } }
    }

    private func haengen() {
        guard darfHaengen else { return }
        let l = link.trimmingCharacters(in: .whitespacesAndNewlines)
        let n = notiz.trimmingCharacters(in: .whitespacesAndNewlines)
        guard speicher.zettelNeu(neu, link: l.isEmpty ? nil : l, notiz: n.isEmpty ? nil : n, bild: bild) else { return }
        Haptik.erfolg()
        neu = ""
        link = ""
        notiz = ""
        bild = nil
        mehr = false
        fokus = true
    }

    private func bildHochladen(_ daten: Data) {
        Task {
            bildLaedt = true
            fehler = nil
            let id = await AlltagFoto.hochladen(daten)
            bildLaedt = false
            if let id { bild = id } else { fehler = "Das Foto konnte nicht hochgeladen werden." }
        }
    }
}

/// Was beim langen Drücken auf einen Zettel aufgeht: Text, Beschreibung und das Foto.
private struct ZettelVorschau: View {
    let zettel: KuehlZettel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(zettel.text).font(.headline)
            if let notiz = zettel.notiz {
                Text(notiz).font(.subheadline).foregroundStyle(.secondary)
            }
            if let bild = zettel.bild {
                ProfilFoto(medienId: bild)
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .padding(16)
        .frame(width: 280, alignment: .leading)
    }
}

/// Foto aus der Mediathek oder von der Kamera; gibt die rohen Bilddaten weiter.
struct AlltagFotoKnoepfe: View {
    let gewaehlt: (Data) -> Void
    @State private var auswahl: PhotosPickerItem?
    @State private var kameraOffen = false

    var body: some View {
        HStack(spacing: 12) {
            PhotosPicker(selection: $auswahl, matching: .images) {
                Label("Fotos", systemImage: "photo.on.rectangle").frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered)
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button { kameraOffen = true } label: {
                    Label("Kamera", systemImage: "camera").frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
            }
        }
        .tint(Color.loveaRose)
        .onChange(of: auswahl) { _, item in
            guard let item else { return }
            auswahl = nil
            Task {
                if let daten = try? await item.loadTransferable(type: Data.self) { gewaehlt(daten) }
            }
        }
        .fullScreenCover(isPresented: $kameraOffen) {
            NaehrwertKamera(aufgenommen: { bild in
                kameraOffen = false
                if let daten = bild?.jpegData(compressionQuality: 0.9) { gewaehlt(daten) }
            })
            .ignoresSafeArea()
        }
    }
}

/// Foto hochladen auf dem Weg der Snaps und des Chats, aber nur in der kleinen Fassung (1280 px, JPEG):
/// Outfit und Essensbild brauchen keine Originalgröße.
enum AlltagFoto {
    /// Die Medien-ID des hochgeladenen Fotos, bei einem Fehler nil.
    @MainActor
    static func hochladen(_ daten: Data) async -> String? {
        let id = UUID().uuidString
        guard let ergebnis = await Task.detached(priority: .userInitiated, operation: { MedienKodierung.foto(daten, id: id) }).value else { return nil }
        let datei = ergebnis.klein ?? ergebnis.original
        ChatMedien.eigeneQuellen[id] = datei
        do {
            try await Medien.hochladen(id: id, original: datei, klein: nil)
            return id
        } catch {
            ChatMedien.eigeneQuellen[id] = nil
            return nil
        }
    }
}
