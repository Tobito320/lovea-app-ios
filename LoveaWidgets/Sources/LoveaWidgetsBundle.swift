import WidgetKit

@main
struct LoveaWidgetsBundle: WidgetBundle {
    var body: some Widget {
        GymWocheWidget()
        GymDuellWidget()
        SchritteDuellWidget()
        PartnerWidget()
        TreffenWidget()
        PunkteChallengeWidget()
        FotoFrageWidget()
    }
}
