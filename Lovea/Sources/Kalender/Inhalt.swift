import Foundation

/// Findet eine gebündelte Inhaltsdatei aus `Kalender/Inhalt/` (`fragen.json`, `dates.json`).
/// Je nach XcodeGen-Gruppenart landen lose Ressourcen flach im Bundle oder unter ihrem
/// Quellordner — beide Pfade abklopfen statt einen zu erraten.
enum Inhalt {
    static func url(datei: String, typ: String) -> URL? {
        Bundle.main.url(forResource: datei, withExtension: typ)
            ?? Bundle.main.url(forResource: datei, withExtension: typ, subdirectory: "Kalender/Inhalt")
    }
}
