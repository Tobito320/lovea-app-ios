import Darwin
import Foundation
import MachO

/// Build 78 (Ahmed: Absturzverdacht Build 76/77, kein eindeutiger Befund im Diff, keine Absturz-Logs
/// verfügbar) — fängt einen Absturz VOR dem Start aller anderen App-Logik ab, damit der nächste Start
/// zeigt, wo der vorige starb. `installieren()` muss als ALLERERSTES in `LoveaApp.init` laufen.
///
/// `fd` und `framesBuffer` sind bewusst `nonisolated(unsafe) static var`: der POSIX-Signal-Handler
/// unten ist ein `@convention(c)`-C-Callback, der auf jedem Thread und mitten in einem kaputten
/// Programmzustand laufen kann — dort ist weder ein Lock noch `MainActor` noch irgendeine
/// Swift-Allokation sicher (siehe Kommentar am Handler). Ein globaler Dateideskriptor und ein einmal
/// vorab allokierter Puffer sind hier unvermeidbar, kein normaler Anwendungsfall für geteilten
/// Zustand — deshalb keine Klasse mit `NSLock` wie bei `StartProtokoll`.
enum AbsturzFaenger {
    nonisolated(unsafe) static var fd: Int32 = -1
    /// Vorab allokiert, damit der Signal-Handler nie ein Swift-Array erzeugen muss (verboten im
    /// Signal-Kontext — siehe Regeln im Auftrag).
    nonisolated(unsafe) static var framesBuffer = UnsafeMutablePointer<UnsafeMutableRawPointer?>.allocate(capacity: 64)

    private static let absturzName = "absturz.txt"
    private static let infoName = "absturz-info.txt"
    private static let absturzVorherName = "absturz.txt.vorher"
    private static let infoVorherName = "absturz-info.txt.vorher"

    private static var ordner: URL? { FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first }

    /// Installiert Exception- und Signal-Handler. Rotiert eine vorhandene `absturz.txt` ZUERST nach
    /// `.vorher`, bevor sie mit `O_TRUNC` geöffnet (= geleert) wird — sonst wäre der Absturz des
    /// letzten Laufs schon weg, bevor der nächste Start ihn zeigen kann.
    static func installieren() {
        guard let ordner else { return }
        try? FileManager.default.createDirectory(at: ordner, withIntermediateDirectories: true)
        let absturzPfad = ordner.appendingPathComponent(absturzName)
        let infoPfad = ordner.appendingPathComponent(infoName)
        rotieren(absturzPfad: absturzPfad, infoPfad: infoPfad)

        fd = absturzPfad.path.withCString { open($0, O_WRONLY | O_CREAT | O_TRUNC, 0o644) }
        guard fd >= 0 else { return }
        // Unwinder einmal im Normalbetrieb aufwärmen, nicht zum ersten Mal mitten im Signal-Handler.
        _ = backtrace(framesBuffer, 1)

        NSSetUncaughtExceptionHandler(absturzExceptionHandler)
        for sig in [SIGABRT, SIGTRAP, SIGILL, SIGSEGV, SIGBUS, SIGFPE] {
            signal(sig, absturzSignalHandler)
        }
        infoSchreiben(nach: infoPfad)
    }

    private static func rotieren(absturzPfad: URL, infoPfad: URL) {
        guard let groesse = try? FileManager.default.attributesOfItem(atPath: absturzPfad.path)[.size] as? Int,
            groesse > 0 else { return }
        guard let ordner else { return }
        let vorherPfad = ordner.appendingPathComponent(absturzVorherName)
        let vorherInfoPfad = ordner.appendingPathComponent(infoVorherName)
        try? FileManager.default.removeItem(at: vorherPfad)
        try? FileManager.default.moveItem(at: absturzPfad, to: vorherPfad)
        try? FileManager.default.removeItem(at: vorherInfoPfad)
        try? FileManager.default.moveItem(at: infoPfad, to: vorherInfoPfad)
    }

    /// Build, Lade-Adresse und ASLR-Slide DIESES Laufs — für die Symbolisierung des nächsten
    /// Absturzes (die Adressen im Backtrace sind nur mit genau diesem Slide auflösbar).
    private static func infoSchreiben(nach pfad: URL) {
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        var text = "Build: \(build)\n"
        if let kopf = _dyld_get_image_header(0) {
            text += "Bild-Adresse: 0x\(String(UInt(bitPattern: kopf), radix: 16))\n"
        }
        text += "Slide: 0x\(String(UInt(bitPattern: _dyld_get_image_vmaddr_slide(0)), radix: 16))\n"
        var sys = utsname()
        uname(&sys)
        let modell = withUnsafePointer(to: &sys.machine) { ptr in
            ptr.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
        }
        text += "Geraet: \(modell)\n"
        text += "iOS: \(ProcessInfo.processInfo.operatingSystemVersionString)\n"
        try? text.write(to: pfad, atomically: true, encoding: .utf8)
    }

    /// Absturz-Text des VORIGEN Laufs (nach `.vorher` rotiert) plus dessen Info-Datei, oder nil,
    /// wenn keine Absturz-Datei da war (z. B. sauberer letzter Lauf).
    static func vorherigerBerichtText() -> String? {
        guard let ordner else { return nil }
        let absturz = (try? String(contentsOf: ordner.appendingPathComponent(absturzVorherName), encoding: .utf8)) ?? ""
        guard !absturz.isEmpty else { return nil }
        let info = (try? String(contentsOf: ordner.appendingPathComponent(infoVorherName), encoding: .utf8)) ?? ""
        return info + "\nAbsturz:\n" + absturz
    }

    /// Nach dem Anzeigen: löschen, damit der Bericht nur einmal erscheint.
    static func vorherigenBerichtLoeschen() {
        guard let ordner else { return }
        try? FileManager.default.removeItem(at: ordner.appendingPathComponent(absturzVorherName))
        try? FileManager.default.removeItem(at: ordner.appendingPathComponent(infoVorherName))
    }
}

/// NICHT im Signal-Kontext — normaler Swift-Code (String, Data) ist hier erlaubt, anders als im
/// POSIX-Handler unten. `@convention(c)` ohne Captures: referenziert nur `AbsturzFaenger`-Statics.
private let absturzExceptionHandler: @convention(c) (NSException) -> Void = { exception in
    guard AbsturzFaenger.fd >= 0 else { return }
    let text = "NSException: \(exception.name.rawValue): \(exception.reason ?? "")\n"
        + exception.callStackSymbols.joined(separator: "\n") + "\n"
    guard let daten = text.data(using: .utf8) else { return }
    daten.withUnsafeBytes { buf in _ = write(AbsturzFaenger.fd, buf.baseAddress, buf.count) }
    fsync(AbsturzFaenger.fd)
}

/// `StaticString`, nicht `String`: ihre Bytes liegen fest im Binary, kein Alloc beim Zugriff — der
/// Signal-Handler darf nicht allokieren.
private func absturzSignalName(_ sig: Int32) -> StaticString {
    switch sig {
    case SIGABRT: return "SIGABRT\n"
    case SIGTRAP: return "SIGTRAP\n"
    case SIGILL: return "SIGILL\n"
    case SIGSEGV: return "SIGSEGV\n"
    case SIGBUS: return "SIGBUS\n"
    case SIGFPE: return "SIGFPE\n"
    default: return "SIGNAL\n"
    }
}

/// Der eigentliche Signal-Handler. NUR async-signal-sichere Aufrufe: `write`, `fsync`, `backtrace`,
/// `backtrace_symbols_fd`, `signal`, `raise`. Kein Swift-Alloc, keine String-Interpolation — alle
/// Puffer sind in `AbsturzFaenger` vorab allokiert. `@convention(c)`, keine Captures. Stellt am Ende
/// den Standard-Handler wieder her und `raise`t das Signal erneut, damit iOS/der Debugger den Absturz
/// normal sieht (dieser Handler ersetzt den Crash nicht, er protokolliert ihn nur vorher).
private let absturzSignalHandler: @convention(c) (Int32) -> Void = { sig in
    guard AbsturzFaenger.fd >= 0 else {
        signal(sig, SIG_DFL)
        raise(sig)
        return
    }
    let name = absturzSignalName(sig)
    name.withUTF8Buffer { buf in _ = write(AbsturzFaenger.fd, buf.baseAddress, buf.count) }
    let anzahl = backtrace(AbsturzFaenger.framesBuffer, 64)
    backtrace_symbols_fd(AbsturzFaenger.framesBuffer, anzahl, AbsturzFaenger.fd)
    fsync(AbsturzFaenger.fd)
    signal(sig, SIG_DFL)
    raise(sig)
}
