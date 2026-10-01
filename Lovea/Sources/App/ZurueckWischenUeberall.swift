import UIKit

/// App-weit: Zurück-Wischen vom linken Rand soll überall gehen, auch wenn ein Screen den System-
/// Zurück-Knopf versteckt (`navigationBarBackButtonHidden`) – das schaltet sonst nebenbei auch die
/// Wisch-Geste ab. `ZurueckWischenAus` (Zeichenstudio, Trainingsplan während des Bearbeitens) bleibt
/// davon unberührt: ein deaktivierter Recognizer (`isEnabled = false`) fragt den Delegate gar nicht erst.
///
/// Nur für echte `UINavigationController`-Instanzen, nicht für Unterklassen: `UIImagePickerController`
/// (Kamera in `NaehrwertFoto.swift`, Barcode-Scanner) IST selbst ein `UINavigationController` – ohne
/// diese Sperre würde sich dessen internes Zurück-Wischen (z. B. aus dem Kamera-Bild raus) mitändern,
/// ein Systembestandteil, der hier nicht angefasst werden soll. SwiftUI erzeugt für `NavigationStack`
/// nach bisheriger Beobachtung einen reinen `UINavigationController`, keine eigene Unterklasse – trifft
/// das nicht mehr zu, bleibt dieser Fix dort einfach wirkungslos (fail-safe), statt versehentlich auf
/// ein fremdes Verhalten zuzugreifen.
extension UINavigationController: @retroactive UIGestureRecognizerDelegate {
    open override func viewDidLoad() {
        super.viewDidLoad()
        guard type(of: self) == UINavigationController.self else { return }
        interactivePopGestureRecognizer?.delegate = self
        // iOS 26: `UINavigationController` kann zusätzlich vom ganzen Inhalt aus wischen lassen
        // (nicht nur vom Rand). Gleiche Behandlung wie beim Rand-Wisch, per Selektor wie in
        // `ZurueckWischenAus` (DrawingStudioView.swift), damit der Build nicht vom SDK-Symbol abhängt.
        let inhaltsWischen = NSSelectorFromString("interactiveContentPopGestureRecognizer")
        if responds(to: inhaltsWischen) {
            (value(forKey: "interactiveContentPopGestureRecognizer") as? UIGestureRecognizer)?.delegate = self
        }
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        let inhaltsWischen = NSSelectorFromString("interactiveContentPopGestureRecognizer")
        let istZurueckGeste = gestureRecognizer == interactivePopGestureRecognizer
            || (responds(to: inhaltsWischen) && gestureRecognizer === (value(forKey: "interactiveContentPopGestureRecognizer") as? UIGestureRecognizer))
        guard istZurueckGeste else { return true }
        return viewControllers.count > 1
    }
}
