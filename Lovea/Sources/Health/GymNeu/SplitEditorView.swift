import SwiftUI
import TipKit

// Der eigene Split, Tag für Tag (Entwurf `Lovea-bilder/gym-entwurf.html`, "Neuer Tag" A: Plus neben den
// Tagen). Jede Änderung sichert sofort den ganzen Plan (`gym.plan`, neuester gilt).

struct SplitEditorAktionen {
    var waehlen: (String) -> Void = { _ in }
    var neuerTag: () -> Void = {}
    var wochentag: (Int) -> Void = { _ in }
    var aufklappen: (String) -> Void = { _ in }
    var bearbeiten: (PlanUebung) -> Void = { _ in }
    /// Schnell geändert (Stepper für Sätze, Wiederholungen, kg, Minuten): die neue Übung.
    var aendern: (PlanUebung) -> Void = { _ in }
    var hinzufuegen: () -> Void = {}
}

/// Reiner Inhalt (Render-Tafel): Tagesleiste, Wochentage des gewählten Tags, seine Übungen.
struct SplitEditorInhalt: View {
    let plan: TrainingsPlan
    let tagId: String?
    var offen: String? = nil
    var aktionen = SplitEditorAktionen()

    private var tag: TrainingsTag? { plan.tage.first { $0.id == tagId } }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            tage
            if let tag {
                wochentage(tag)
                uebungen(tag).padding(.top, 6)
            } else {
                Text("Noch kein Trainingstag. Tipp auf das Plus.").font(.subheadline).foregroundStyle(.secondary).padding(.vertical, 14)
            }
        }
    }

    private var tage: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(plan.tage) { t in
                    Button { aktionen.waehlen(t.id) } label: { GymChip(text: t.name.isEmpty ? "Ohne Namen" : t.name, an: t.id == tagId) }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(t.id == tagId ? .isSelected : [])
                }
                if plan.tage.count < SplitFrei.tageBereich.upperBound {
                    Button(action: aktionen.neuerTag) {
                        Image(systemName: "plus")
                            .font(.footnote.weight(.bold))
                            .frame(width: 38, height: 32)
                            .foregroundStyle(Color.secondary)
                            .background(Color(uiColor: .tertiarySystemFill), in: Capsule())
                            .frame(minHeight: 44)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Trainingstag hinzufügen")
                }
            }
        }
    }

    private func wochentage(_ tag: TrainingsTag) -> some View {
        HStack(spacing: 4) {
            ForEach(1...7, id: \.self) { w in
                Button { aktionen.wochentag(w) } label: {
                    Text(HabitLogik.wochentagKuerzel[w - 1])
                        .font(.footnote.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 32)
                        .foregroundStyle(tag.wochentage.contains(w) ? Color(uiColor: .systemBackground) : Color.secondary)
                        .background(tag.wochentage.contains(w) ? Color.primary : Color(uiColor: .tertiarySystemFill), in: Capsule())
                        .frame(minHeight: 44)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(TrainingLogik.wochentagName[w - 1])
                .accessibilityAddTraits(tag.wochentage.contains(w) ? .isSelected : [])
            }
        }
    }

    private func uebungen(_ tag: TrainingsTag) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(tag.uebungen) { u in
                Button { aktionen.aufklappen(u.id) } label: {
                    GymUebungZeile(name: u.anzeigeName, unter: TrainingLogik.saetzeText(u)).contentShape(.rect)
                }
                .buttonStyle(.plain)
                if offen == u.id { saetze(u) }
                Divider()
            }
            Button(action: aktionen.hinzufuegen) {
                Label("Übung hinzufügen", systemImage: "plus")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
        }
    }

    private func saetze(_ u: PlanUebung) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            schnell(u)
            if let minuten = u.minuten {
                Text("\(minuten) min").font(.subheadline).foregroundStyle(.secondary).frame(minHeight: 36)
            }
            ForEach(Array(u.saetze.enumerated()), id: \.offset) { i, s in
                HStack(spacing: 10) {
                    Text(s.kuerzel ?? "\(i + 1)").frame(width: 28, alignment: .leading).foregroundStyle(.secondary)
                    Text("\(s.wdh) Wdh.").frame(maxWidth: .infinity, alignment: .leading)
                    Text(s.kg.map { "\(TrainingLogik.kgText($0)) kg" } ?? "ohne Gewicht").frame(maxWidth: .infinity, alignment: .leading).foregroundStyle(s.kg == nil ? Color.secondary : Color.primary)
                }
                .font(.subheadline)
                .monospacedDigit()
                .frame(minHeight: 36)
            }
            Button { aktionen.bearbeiten(u) } label: { GymChip(text: "Sätze ändern") }.buttonStyle(.plain)
        }
        .padding(.bottom, 8)
    }
}

extension SplitEditorInhalt {
    /// Sätze, Wiederholungen und kg für die ganze Übung mit je einem Stepper (Cardio: Minuten).
    @ViewBuilder
    fileprivate func schnell(_ u: PlanUebung) -> some View {
        if let minuten = u.minuten {
            zeile("Dauer", "\(minuten) min", Stepper("", value: Binding(get: { minuten }, set: { aktionen.aendern(SplitFrei.dauer(u, $0)) }), in: 5...180, step: 5))
        } else {
            zeile("Sätze", "\(u.saetze.count)", Stepper("", value: Binding(get: { u.saetze.count }, set: { aktionen.aendern(SplitFrei.saetzeAnzahl(u, $0)) }), in: 1...SplitFrei.maxSaetze))
            zeile("Wiederholungen", Set(u.saetze.map(\.wdh)).count > 1 ? "gemischt" : "\(u.saetze.first?.wdh ?? 10)",
                  Stepper("", value: Binding(get: { u.saetze.first?.wdh ?? 10 }, set: { aktionen.aendern(SplitFrei.alleWdh(u, $0)) }), in: 1...100))
            zeile("Gewicht", kgText(u), Stepper("", value: Binding(get: { u.saetze.first?.kg ?? 0 }, set: { aktionen.aendern(SplitFrei.alleKg(u, $0)) }), in: 0...500, step: 2.5))
        }
    }

    private func kgText(_ u: PlanUebung) -> String {
        let kg = Set(u.saetze.map(\.kg))
        guard kg.count == 1, let eins = kg.first else { return kg.count > 1 ? "gemischt" : "ohne" }
        return eins.map { "\(TrainingLogik.kgText($0)) kg" } ?? "ohne"
    }

    private func zeile(_ titel: String, _ wert: String, _ stepper: some View) -> some View {
        HStack(spacing: 10) {
            Text(titel).font(.subheadline)
            Spacer(minLength: 8)
            Text(wert).font(.subheadline.weight(.semibold)).monospacedDigit()
            stepper.labelsHidden().fixedSize()
        }
        .frame(minHeight: 44)
        .accessibilityElement(children: .combine)
    }
}

struct SplitEditorView: View {
    /// Der Tag, der zuerst gezeigt wird; nil = der erste.
    let start: String?

    @State private var tagId: String?
    @State private var offen: String?
    @State private var bearbeiten: PlanUebung?
    @State private var sucheOffen = false
    @State private var nameOffen = false
    @State private var name = ""
    @State private var loeschenFrage = false

    private var modell: TrainingModell { TrainingModell.shared }
    private var ich: Person { Raum.shared.ich ?? .ahmed }
    private var plan: TrainingsPlan { modell.plan(ich) }
    private var tag: TrainingsTag? { plan.tage.first { $0.id == gewaehlt } }
    private var gewaehlt: String? { tagId ?? start ?? plan.tage.first?.id }

    var body: some View {
        ScrollView {
            SplitEditorInhalt(plan: plan, tagId: tag?.id ?? plan.tage.first?.id, offen: offen, aktionen: aktionen)
                .padding(.horizontal, 18)
                .padding(.bottom, 28)
        }
        .navigationTitle(plan.splitName ?? "Mein Split")
        .navigationBarTitleDisplayMode(.large)
        .toolbar { ToolbarItem(placement: .primaryAction) { menue } }
        .sheet(isPresented: $sucheOffen) { UebungsSuche { neu in aendern { $0.uebungen.append(neu) } } }
        .sheet(item: $bearbeiten) { u in NavigationStack { SaetzeEditor(uebung: bindung(u), entfernen: { entfernen(u) }) } }
        .alert("Tag umbenennen", isPresented: $nameOffen) {
            TextField("z. B. Push", text: $name)
            Button("Abbrechen", role: .cancel) {}
            Button("Sichern") { aendern { $0.name = name.trimmingCharacters(in: .whitespacesAndNewlines) } }
        }
        .confirmationDialog("Diesen Trainingstag löschen?", isPresented: $loeschenFrage, titleVisibility: .visible) {
            Button("Tag löschen", role: .destructive) { tagLoeschen() }
            Button("Abbrechen", role: .cancel) {}
        }
    }

    private var menue: some View {
        Menu {
            Button("Tag umbenennen", systemImage: "pencil") {
                name = tag?.name ?? ""
                nameOffen = true
            }
            Button("Tag löschen", systemImage: "trash", role: .destructive) { loeschenFrage = true }
        } label: {
            Image(systemName: "ellipsis")
        }
        .disabled(tag == nil)
        .accessibilityLabel("Mehr")
        .popoverTip(SplitTagMehrTip())
    }

    private var aktionen: SplitEditorAktionen {
        SplitEditorAktionen(
            waehlen: { id in
                Haptik.auswahl()
                withAnimation(Feder.schnell) { tagId = id; offen = nil }
            },
            neuerTag: neuerTag,
            wochentag: { w in
                aendern { t in
                    if t.wochentage.contains(w) { t.wochentage.removeAll { $0 == w } } else { t.wochentage = (t.wochentage + [w]).sorted() }
                }
                Haptik.auswahl()
            },
            aufklappen: { id in withAnimation(Feder.schnell) { offen = offen == id ? nil : id } },
            bearbeiten: { bearbeiten = $0 },
            aendern: { neu in
                aendern { t in
                    if let i = t.uebungen.firstIndex(where: { $0.id == neu.id }) { t.uebungen[i] = neu }
                }
            },
            hinzufuegen: { sucheOffen = true }
        )
    }

    /// Ändert den gewählten Tag und sichert den Plan. `tagSetzen` nimmt den Wochentag anderen Tagen weg.
    private func aendern(_ f: (inout TrainingsTag) -> Void) {
        guard var t = tag else { return }
        f(&t)
        modell.planSichern(TrainingLogik.tagSetzen(plan, t))
    }

    private func neuerTag() {
        let neu = TrainingsTag(id: UUID().uuidString, name: "Tag \(plan.tage.count + 1)", wochentage: [], uebungen: [])
        modell.planSichern(TrainingLogik.tagSetzen(plan, neu))
        tagId = neu.id
        offen = nil
        Haptik.leicht()
    }

    private func tagLoeschen() {
        guard let t = tag else { return }
        var p = plan
        p.tage.removeAll { $0.id == t.id }
        modell.planSichern(p)
        tagId = nil
        Haptik.leicht()
    }

    private func entfernen(_ u: PlanUebung) {
        aendern { t in t.uebungen.removeAll { $0.id == u.id } }
    }

    /// `SaetzeEditor` schreibt erst bei "Fertig" zurück: ein Plan-Op pro Übung.
    private func bindung(_ u: PlanUebung) -> Binding<PlanUebung> {
        Binding { u } set: { neu in
            aendern { t in
                if let i = t.uebungen.firstIndex(where: { $0.id == neu.id }) { t.uebungen[i] = neu }
            }
        }
    }
}
