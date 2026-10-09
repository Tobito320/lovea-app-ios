import AppIntents
import SwiftUI
import WidgetKit

/// One habit of your choice (Gym, Wasser, …) like the card in the app, dark and monochrome.
/// The ring top right ticks today off (or +1 for counted habits) without opening the app.
struct HabitWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "Habit", intent: HabitWahlIntent.self, provider: HabitProvider()) { entry in
            HabitWidgetView(kachel: entry.kachel)
        }
        .configurationDisplayName("Habit")
        .description("Eins deiner Habits, heute direkt abhaken.")
        .supportedFamilies([.systemSmall])
    }
}

struct HabitEntity: AppEntity {
    let id: String
    let name: String
    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Habit" }
    static let defaultQuery = HabitQuery()
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
}

struct HabitQuery: EntityQuery {
    private var alle: [HabitEntity] {
        (WidgetLesen.stand().habits ?? []).map { HabitEntity(id: $0.id, name: $0.name) }
    }
    func entities(for identifiers: [String]) async throws -> [HabitEntity] { alle.filter { identifiers.contains($0.id) } }
    func suggestedEntities() async throws -> [HabitEntity] { alle }
    func defaultResult() async -> HabitEntity? { alle.first { $0.id == "gym" } ?? alle.first }
}

struct HabitWahlIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Habit wählen" }
    @Parameter(title: "Habit") var habit: HabitEntity?
}

struct HabitEintrag: TimelineEntry {
    let date: Date
    let kachel: WidgetStand.HabitKachel?
}

struct HabitProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> HabitEintrag {
        HabitEintrag(date: Date(), kachel: .init(id: "gym", name: "Gym", symbol: "dumbbell.fill", untertitel: "3 Tage/Woche", zaehlen: false, ziel: 1, heute: 0, woche: [1, 0, 1, 0, 0, 0, 0], serie: 1))
    }
    func snapshot(for configuration: HabitWahlIntent, in context: Context) async -> HabitEintrag { eintrag(configuration) }
    func timeline(for configuration: HabitWahlIntent, in context: Context) async -> Timeline<HabitEintrag> {
        Timeline(entries: [eintrag(configuration)], policy: .after(WidgetDatum.naechsteMitternacht()))
    }
    private func eintrag(_ c: HabitWahlIntent) -> HabitEintrag {
        let habits = WidgetLesen.stand().habits ?? []
        let id = c.habit?.id ?? "gym"
        return HabitEintrag(date: Date(), kachel: habits.first { $0.id == id } ?? habits.first)
    }
}

/// Toggles today (or +1, wrapping to 0 after the goal) and sends `habit.setzen` like the Gym intent.
struct HabitTippenIntent: AppIntent {
    static var title: LocalizedStringResource { "Habit abhaken" }
    @Parameter(title: "Habit") var habitId: String
    init() {}
    init(habitId: String) { self.habitId = habitId }

    func perform() async throws -> some IntentResult {
        guard var stand = WidgetLesen.standOderNil(), var habits = stand.habits,
              let i = habits.firstIndex(where: { $0.id == habitId }) else { return .result() }
        var k = habits[i]
        let neu = k.zaehlen ? (k.heute >= k.ziel ? 0 : k.heute + 1) : (k.heute > 0 ? 0 : 1)
        k.heute = neu
        let tag = (WidgetDatum.berlin.component(.weekday, from: Date()) + 5) % 7 // Mo = 0
        if k.woche.indices.contains(tag) { k.woche[tag] = k.zaehlen ? min(1, Double(neu) / Double(max(1, k.ziel))) : Double(neu) }
        habits[i] = k
        stand.habits = habits
        if let url = WidgetGruppe.standURL(), let daten = try? JSONEncoder().encode(stand) { try? daten.write(to: url, options: .atomic) }
        await WidgetOpPoster.gymHeuteSenden(von: stand.eigenePerson, datum: WidgetDatum.heute(), wert: neu, habit: habitId)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

private struct HabitWidgetView: View {
    let kachel: WidgetStand.HabitKachel?

    var body: some View {
        Group {
            if let k = kachel { inhalt(k) } else {
                Text("Öffne Lovea einmal, dann erscheinen deine Habits hier.").font(.caption).foregroundStyle(.secondary)
            }
        }
        .widgetURL(URL(string: "lovea://health"))
        .containerBackground(for: .widget) {
            LinearGradient(colors: [Color(white: 0.13), Color(white: 0.04)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        .environment(\.colorScheme, .dark)
    }

    private func inhalt(_ k: WidgetStand.HabitKachel) -> some View {
        let fertig = k.zaehlen ? k.heute >= k.ziel : k.heute > 0
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                Image(systemName: k.symbol).font(.title3.weight(.semibold)).foregroundStyle(.white)
                Spacer()
                Button(intent: HabitTippenIntent(habitId: k.id)) {
                    ZStack {
                        Circle().stroke(.white.opacity(0.18), lineWidth: 3)
                        Circle().trim(from: 0, to: k.zaehlen ? min(1, Double(k.heute) / Double(k.ziel)) : (fertig ? 1 : 0))
                            .stroke(.white, style: StrokeStyle(lineWidth: 3, lineCap: .round)).rotationEffect(.degrees(-90))
                        if fertig { Image(systemName: "checkmark").font(.caption.bold()) }
                        else if k.zaehlen { Text("+1").font(.caption2.bold()) }
                    }
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
            Text(k.name).font(.headline).foregroundStyle(.white).lineLimit(1)
            Text(k.untertitel).font(.caption2).foregroundStyle(.white.opacity(0.55)).lineLimit(1)
            HStack(spacing: 3) {
                ForEach(Array(k.woche.enumerated()), id: \.offset) { _, anteil in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(.white.opacity(0.12))
                        .overlay(alignment: .bottom) {
                            GeometryReader { g in
                                RoundedRectangle(cornerRadius: 3).fill(.white.opacity(0.9))
                                    .frame(height: g.size.height * anteil).frame(maxHeight: .infinity, alignment: .bottom)
                            }
                        }
                        .frame(width: 12, height: 12)
                }
                Spacer(minLength: 4)
                if k.serie > 0 {
                    Label("\(k.serie)", systemImage: "flame.fill").font(.caption2.bold()).foregroundStyle(.white.opacity(0.8)).labelStyle(.titleAndIcon)
                }
            }
            .padding(.top, 6)
        }
    }
}
