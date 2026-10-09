import UIKit

/// Welche `UINavigationController`-Klassen ihr Zurück-Wischen selbst regeln und hier nicht
/// angefasst werden sollen (Kamera, Mail, SMS, Video-Schnitt bringen ihr eigenes Verhalten mit).
/// Eine Deny-Liste statt eines exakten Typ-Checks: SwiftUI steckt `NavigationStack` ab iOS 16 in
/// eine private Unterklasse (im View-Debugger `UIKitNavigationController`), ein `type(of: self) ==
/// UINavigationController.self`-Vergleich hätte also genau die Screens ausgeschlossen, die den Fix
/// eigentlich brauchen (Review, Runde 2).
enum ZurueckWischenSystemklassen {
    /// Als Name, nicht als Typ: `MessageUI` ist in diesem Ziel nicht importiert. `NSClassFromString`
    /// liefert für eine nicht gelinkte Klasse einfach `nil`, dafür braucht es kein `import MessageUI`.
    /// `UIDocumentPickerViewController`, `PHPickerViewController`, `QLPreviewController` und
    /// `SFSafariViewController` stehen bewusst NICHT in der Liste: laut Apples Klassenhierarchie sind
    /// das alles `UIViewController`-Unterklassen, keine `UINavigationController`-Unterklassen – unsere
    /// `viewDidLoad`-Erweiterung greift bei denen also ohnehin nie.
    static let gesperrt: Set<String> = [
        "UIImagePickerController",       // Kamera, Health/Ernaehrung/NaehrwertFoto.swift
        "MFMailComposeViewController",    // MessageUI, aktuell ungenutzt
        "MFMessageComposeViewController", // MessageUI, aktuell ungenutzt
        "UIVideoEditorController",        // UIKit, aktuell nur als Kommentar in MedienKodierung.swift
    ]

    /// Reine Funktion zum Testen: Namenskette von der Klasse bis `NSObject` hoch, ohne UIKit-Typen.
    /// `true`, sobald irgendein Name in der Kette in `gesperrt` steht (deckt auch Unterklassen ab).
    static func istGesperrt(klassenkette: [String]) -> Bool {
        !gesperrt.isDisjoint(with: klassenkette)
    }

    static func istGesperrt(_ klasse: AnyClass) -> Bool {
        var kette: [String] = []
        var aktuell: AnyClass? = klasse
        while let k = aktuell {
            kette.append(NSStringFromClass(k))
            aktuell = k.superclass()
        }
        return istGesperrt(klassenkette: kette)
    }
}

/// App-weit: Zurück-Wischen vom linken Rand soll überall gehen, auch wenn ein Screen den System-
/// Zurück-Knopf versteckt (`navigationBarBackButtonHidden`) – das schaltet sonst nebenbei auch die
/// Wisch-Geste ab. `ZurueckWischenAus` (Zeichenstudio, Trainingsplan während des Bearbeitens) bleibt
/// davon unberührt: ein deaktivierter Recognizer (`isEnabled = false`) fragt den Delegate gar nicht erst.
extension UINavigationController: @retroactive UIGestureRecognizerDelegate {
    open override func viewDidLoad() {
        super.viewDidLoad()
        guard !ZurueckWischenSystemklassen.istGesperrt(type(of: self)) else { return }
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
        guard viewControllers.count > 1 else { return false }
        // Der Inhalts-Wisch (iOS 26) gilt auf der ganzen Fläche: Eine innere horizontale Scroll-Fläche,
        // die nach rechts noch zurückscrollen kann (Karussell, Chips), behält die Berührung. Der
        // Rand-Wisch bleibt davon unberührt.
        if gestureRecognizer !== interactivePopGestureRecognizer {
            let punkt = gestureRecognizer.location(in: nil)
            if TabWischSperre.shared.innenBelegt(wurzel: view, punkt: punkt, fingerNachLinks: false) { return false }
        }
        return true
    }
}
