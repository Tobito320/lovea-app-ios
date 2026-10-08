import SwiftUI
import XCTest
@testable import Lovea

/// p43 render board: new camera chrome and new editor chrome over a bright ("hell") and a dark
/// ("dunkel") scene. The live preview and the editor's photo cannot be rendered (AVFoundation, UIKit
/// views), so a plain gradient stands in for the picture; only the control layer is the real code.
@MainActor
final class RenderGalerieSnapsTests: XCTestCase {
    private func szene(hell: Bool) -> some View {
        LinearGradient(
            colors: hell ? [Color(red: 0.96, green: 0.92, blue: 0.84), Color(red: 0.78, green: 0.72, blue: 0.62)]
                         : [Color(red: 0.10, green: 0.11, blue: 0.16), Color(red: 0.03, green: 0.03, blue: 0.05)],
            startPoint: .top, endPoint: .bottom
        )
    }

    private func kamera(hell: Bool, filterOffen: Bool) -> AnyView {
        let steuerung = SnapKameraSteuerung()
        return AnyView(
            ZStack {
                szene(hell: hell)
                VStack {
                    HStack(alignment: .top) {
                        KameraSchliessenKnopf {}
                        Spacer()
                        KameraSeitenMenu(
                            steuerung: steuerung, onWechseln: {},
                            erweitert: .constant(false), timer: .constant(.aus), rasterAn: .constant(false),
                            freihandAn: .constant(false), multiSnapAn: .constant(false),
                            filterOffen: .constant(filterOffen), filterGewaehlt: filterOffen, nimmtVideoAuf: false
                        )
                    }
                    .padding(.horizontal, 12).padding(.top, 8)
                    Spacer()
                    if filterOffen { KameraFilterLeiste(auswahl: .constant(.warm)).padding(.bottom, 12) }
                    KameraLinsenPille(werte: [0.5, 1, 2], aktuellerZoom: 1, onWahl: { _ in }).padding(.bottom, 14)
                    HStack {
                        KameraMemoriesKnopf(laedt: false).frame(maxWidth: .infinity)
                        KameraAusloeserBild(fortschritt: 0)
                        Color.clear.frame(maxWidth: .infinity, maxHeight: 1)
                    }
                    .padding(.bottom, 32)
                }
            }
            .frame(width: 300, height: 600)
            .clipShape(.rect(cornerRadius: 24))
            .environment(\.colorScheme, hell ? .light : .dark)
        )
    }

    private func editor(hell: Bool) -> AnyView {
        AnyView(
            ZStack {
                szene(hell: hell)
                Text("Bis später")
                    .font(.system(size: 300 * 0.07, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(radius: 3)
                    .position(x: 300 * 0.35, y: 600 * 0.4)
                VStack {
                    HStack(alignment: .top) {
                        KameraSchliessenKnopf {}
                        Spacer()
                        SnapEditorWerkzeuge(zeichnenAktiv: false, onText: {}, onKritzeln: {}, onSticker: {})
                    }
                    .padding(.horizontal, 12).padding(.top, 8)
                    Spacer()
                    SnapSendenLeiste(bleibt: .constant(false), sendetGerade: false, tray: false, onSenden: {})
                        .padding(.bottom, 12)
                }
            }
            .frame(width: 300, height: 600)
            .clipShape(.rect(cornerRadius: 24))
            .environment(\.colorScheme, hell ? .light : .dark)
        )
    }

    func testKameraUndEditorTafel() {
        RenderTafel.speichern("snaps-kamera-editor", spalten: 4, zellen: [
            (titel: "Kamera hell", ansicht: kamera(hell: true, filterOffen: false)),
            (titel: "Kamera dunkel, Filter offen", ansicht: kamera(hell: false, filterOffen: true)),
            (titel: "Editor hell", ansicht: editor(hell: true)),
            (titel: "Editor dunkel", ansicht: editor(hell: false)),
        ])
    }
}
