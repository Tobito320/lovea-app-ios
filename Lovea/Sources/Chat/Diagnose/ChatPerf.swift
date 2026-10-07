import Foundation
import Observation

/// Misst den Sendepfad einer Textnachricht (A Tippen → B Anfrage raus → C Bestätigung → D gerendert).
/// Isoliert und leicht entfernbar: Aufrufer sind je eine Zeile in ChatModell, ChatEingabeleiste, Raum
/// und ChatTab. Fehler hier dürfen den Chat nie beeinflussen — alles ist non-throwing und ohne Inhalt.
@MainActor
@Observable
final class ChatPerf {
    static let shared = ChatPerf()

    /// Monotone Uhr (Nanosekunden seit Boot) — unabhängig von Wanduhr-Sprüngen.
    nonisolated static func jetztNs() -> UInt64 { DispatchTime.now().uptimeNanoseconds }
    nonisolated static func ms(von: UInt64, bis: UInt64) -> Double { Double(bis &- von) / 1_000_000 }

    private struct Offen {
        let messageId: String
        let tap: UInt64
        var anfrage: UInt64?
        var antwort: UInt64?
        var lokalSichtbar: UInt64?
        let geladen: Int
        let anhaenge: Int
    }

    static let conversationId = "paar"
    static let timeoutMs = 30_000.0

    private(set) var speicher: ChatPerfSpeicher
    /// Zählt Bestätigungen; die Liste beobachtet das und meldet danach das Rendern (`gerendert()`).
    private(set) var antwortZaehler = 0
    private var offen: [String: Offen] = [:]
    private var messageZuOp: [String: String] = [:]
    private var letzterTap: UInt64?
    private let uhr: @Sendable () -> UInt64

    // Ladewerte
    private(set) var letzteFaltungMs: Double?
    private(set) var letzteFaltungAnzahl = 0
    private(set) var ersteSichtbarMs: Double?
    private var oeffnenStart: UInt64?

    init(limit: Int = 100, uhr: @escaping @Sendable () -> UInt64 = ChatPerf.jetztNs) {
        speicher = ChatPerfSpeicher(limit: limit)
        self.uhr = uhr
    }

    var traces: [ChatPerfTrace] { speicher.traces }
    var statistik: ChatPerfStatistik { ChatPerfStatistik.berechnen(speicher.traces) }
    var engpass: ChatPerfEngpass { ChatPerfEngpass.klassifizieren(speicher.traces) }

    // MARK: A

    /// Ganz am Anfang des Senden-Knopfs (vor Draft-Aufräumen und Task-Hop).
    func tippen() { letzterTap = uhr() }

    /// Direkt vor `Raum.einreihen`. Nutzt den Tap-Zeitpunkt, wenn frisch (< 5 s), sonst jetzt.
    func beginn(opId: String, messageId: String, geladen: Int, anhaenge: Int = 0) {
        let jetzt = uhr()
        var tap = jetzt
        if let t = letzterTap, Self.ms(von: t, bis: jetzt) < 5_000 { tap = t }
        letzterTap = nil
        aufraeumen(jetzt: jetzt)
        offen[opId] = Offen(messageId: messageId, tap: tap, geladen: geladen, anhaenge: anhaenge)
        messageZuOp[messageId] = opId
    }

    // MARK: B

    func anfrageGestartet(opId: String) {
        guard offen[opId] != nil, offen[opId]?.anfrage == nil else { return }
        offen[opId]?.anfrage = uhr()
    }

    // MARK: C

    /// Server-Echo mit `seq` für unsere Op. Nur das erste Mal zählt (Redelivery wird ignoriert).
    func antwortErhalten(opId: String) {
        guard offen[opId] != nil, offen[opId]?.antwort == nil else { return }
        offen[opId]?.antwort = uhr()
        antwortZaehler += 1
    }

    // MARK: D

    /// Eigene Nachricht erstmals lokal (optimistisch) in der Liste.
    func lokalSichtbar(messageId: String) {
        guard let op = messageZuOp[messageId], offen[op]?.lokalSichtbar == nil else { return }
        offen[op]?.lokalSichtbar = uhr()
    }

    /// Aus `onChange(of: antwortZaehler)` der Liste: SwiftUI hat den neuen Zustand verarbeitet.
    /// Schließt jeden bestätigten Trace genau einmal ab (er wird dabei aus `offen` entfernt).
    func gerendert() {
        let jetzt = uhr()
        for (opId, o) in offen {
            guard let anfrage = o.anfrage, let antwort = o.antwort else { continue }
            abschliessen(opId: opId, o: o, anfrage: anfrage, antwort: antwort, render: jetzt, fehler: nil)
        }
    }

    // MARK: intern

    private func abschliessen(opId: String, o: Offen, anfrage: UInt64, antwort: UInt64, render: UInt64, fehler: String?) {
        offen[opId] = nil
        messageZuOp[o.messageId] = nil
        speicher.hinzufuegen(ChatPerfTrace(
            traceId: opId, conversationId: Self.conversationId, zeitpunkt: Date(),
            tapToRequestStartMs: Self.ms(von: o.tap, bis: anfrage),
            requestToResponseMs: Self.ms(von: anfrage, bis: antwort),
            responseToRenderMs: Self.ms(von: antwort, bis: render),
            totalSendToVisibleMs: Self.ms(von: o.tap, bis: render),
            tapToLocalVisibleMs: o.lokalSichtbar.map { Self.ms(von: o.tap, bis: $0) },
            success: fehler == nil, errorCategory: fehler,
            loadedMessageCount: o.geladen, attachmentCount: o.anhaenge
        ))
    }

    /// Unbestätigte Traces älter als 30 s werden als Fehlschlag abgelegt (offline, Server weg).
    private func aufraeumen(jetzt: UInt64) {
        for (opId, o) in offen where Self.ms(von: o.tap, bis: jetzt) > Self.timeoutMs {
            let a = o.anfrage ?? jetzt
            abschliessen(opId: opId, o: o, anfrage: a, antwort: o.antwort ?? jetzt, render: jetzt, fehler: "timeout")
        }
    }

    func leeren() {
        speicher.leeren(); offen = [:]; messageZuOp = [:]
    }

    // MARK: Ladewerte

    /// Dauer eines `ChatModell.anwenden`-Folds (wächst mit der Nachrichtenzahl).
    func faltung(ms: Double, anzahl: Int) {
        letzteFaltungMs = ms
        letzteFaltungAnzahl = anzahl
    }

    /// Unterhaltung wird geöffnet (aus `onChange(of: offen)` im ChatTab).
    func oeffnenBeginn() { oeffnenStart = uhr(); ersteSichtbarMs = nil }

    /// Erste Nachrichtenliste erschienen.
    func ersteListeSichtbar() {
        guard let s = oeffnenStart else { return }
        oeffnenStart = nil
        ersteSichtbarMs = Self.ms(von: s, bis: uhr())
    }
}
