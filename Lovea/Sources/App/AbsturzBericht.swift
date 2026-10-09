import SwiftUI

/// Absturz-Bericht aus dem letzten, NICHT sauber beendeten Lauf. Liest `AbsturzFaenger`s rotierte
/// Dateien plus den vorigen Breadcrumb-Trail (`StartProtokoll`) — beides nur einmal pro Prozess, aus
/// `LoveaApp.init`, danach gelöscht, damit der Bericht nur einmal erscheint.
struct AbsturzBericht {
    let build: String
    let text: String

    static func erfassen(vorherCrash: Bool, altesStufenFeld: String?) -> AbsturzBericht? {
        let dateiInhalt = AbsturzFaenger.vorherigerBerichtText()
        guard vorherCrash || dateiInhalt != nil else { return nil }
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        var text = dateiInhalt ?? "(keine Absturz-Datei — vermutlich vom System getötet, kein normaler Crash)\n"
        if let altesStufenFeld {
            text += "\nAlte Stufe (Build 77, vor diesem Breadcrumb-Trail): \(altesStufenFeld)\n"
        }
        text += "\nBreadcrumbs (voriger Lauf):\n" + StartProtokoll.vorherigeListe().joined(separator: "\n")
        AbsturzFaenger.vorherigenBerichtLoeschen()
        return AbsturzBericht(build: build, text: text)
    }
}

/// Scrollbare, monospaced Ansicht des Berichts. Dient sowohl als Sheet (normaler Start, einmalig)
/// als auch als alleiniger Bildschirm im Sicherheitsmodus (`zeigtNormalStarten`).
struct AbsturzBerichtAnsicht: View {
    let bericht: AbsturzBericht?
    var zeigtSchliessen = true
    var zeigtNormalStarten = false
    var normalStarten: () -> Void = {}
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(bericht?.text ?? "Kein Absturzbericht verfügbar.")
                    .font(.system(.footnote, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .navigationTitle("Absturz-Bericht Build \(bericht?.build ?? "?")")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if zeigtSchliessen {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Schließen") { dismiss() }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 12) {
                    Button("Kopieren") { UIPasteboard.general.string = bericht?.text ?? "" }
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)
                    if zeigtNormalStarten {
                        Button("Normal starten", action: normalStarten)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding()
                .background(.bar)
            }
        }
    }
}
