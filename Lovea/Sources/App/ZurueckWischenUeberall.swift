import UIKit

/// App-weit: Zurück-Wischen vom linken Rand soll überall gehen, auch wenn ein Screen den System-
/// Zurück-Knopf versteckt (`navigationBarBackButtonHidden`) – das schaltet sonst nebenbei auch die
/// Wisch-Geste ab. `ZurueckWischenAus` (Zeichenstudio, Trainingsplan während des Bearbeitens) bleibt
/// davon unberührt: ein deaktivierter Recognizer (`isEnabled = false`) fragt den Delegate gar nicht erst.
extension UINavigationController: @retroactive UIGestureRecognizerDelegate {
    open override func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer == interactivePopGestureRecognizer else { return true }
        return viewControllers.count > 1
    }
}
