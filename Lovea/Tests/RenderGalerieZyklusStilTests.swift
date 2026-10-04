import SwiftUI
import XCTest
@testable import Lovea

/// Render boards for the Zyklus theme: colours, cards, chips, buttons, phase rings and decoration, light and dark.
@MainActor
final class RenderGalerieZyklusStilTests: XCTestCase {
    private func zelle<Inhalt: View>(_ titel: String, _ schema: ColorScheme, breite: CGFloat = 360, @ViewBuilder _ inhalt: () -> Inhalt) -> (titel: String, ansicht: AnyView) {
        let ansicht = ZStack { ZyklusHintergrund(deko: false); inhalt().padding(16) }
            .frame(width: breite)
            .environment(\.colorScheme, schema)
        return (titel, AnyView(ansicht))
    }

    private func tafel(_ schema: ColorScheme) -> [(titel: String, ansicht: AnyView)] {
        let name = schema == .light ? "hell" : "dunkel"
        return [
            zelle("Farben, \(name)", schema) {
                VStack(spacing: 10) {
                    HStack(spacing: 8) {
                        ForEach(ZyklusFarbe.allCases, id: \.self) { f in
                            Circle().fill(f.farbe(schema)).frame(width: 52, height: 52)
                                .overlay(Circle().strokeBorder(ZyklusFarbe.tinteLeise(schema).opacity(0.4), lineWidth: 1))
                        }
                    }
                    HStack(spacing: 8) {
                        ForEach(ZyklusPhasenTon.allCases, id: \.self) { p in
                            Circle().fill(p.farbe(schema)).frame(width: 52, height: 52)
                        }
                    }
                }
            },
            zelle("Karte, Chips, Knöpfe, \(name)", schema) {
                VStack(spacing: 14) {
                    ZyklusKarte {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Heute").font(.system(.headline, design: .rounded)).foregroundStyle(ZyklusFarbe.tinte(schema))
                            Text("Periode in 6 Tagen. Trink genug Wasser und gönn dir etwas Süßes.")
                                .font(.system(.subheadline, design: .rounded)).foregroundStyle(ZyklusFarbe.tinteLeise(schema))
                        }
                    }
                    HStack {
                        ZyklusChip(titel: "Krämpfe", gewaehlt: true)
                        ZyklusChip(titel: "Müde", symbol: "moon.zzz.fill")
                        ZyklusChip(titel: "Glücklich", farbe: ZyklusPhasenTon.fruchtbar.farbe(schema))
                    }
                    ZyklusKnopf(titel: "Periode beginnt", symbol: "drop.fill")
                    ZyklusKnopf(titel: "Später", leise: true)
                }
            },
            zelle("Ring Periode 20 %, \(name)", schema) {
                ZyklusRing(fortschritt: 0.2, phase: .periode, titel: "Tag 3", untertitel: "Periode")
            },
            zelle("Ring Fruchtbar 50 %, \(name)", schema) {
                ZyklusRing(fortschritt: 0.5, phase: .fruchtbar, titel: "Tag 13", untertitel: "Fruchtbar")
            },
            zelle("Phasen klein, \(name)", schema) {
                HStack(spacing: 10) {
                    ForEach(Array(ZyklusPhasenTon.allCases.enumerated()), id: \.offset) { i, p in
                        VStack(spacing: 4) {
                            ZyklusRing(fortschritt: Double(i + 1) / 5, phase: p, titel: "\(i + 1)", untertitel: "")
                                .scaleEffect(0.2).frame(width: 52, height: 52)
                            Text(p.name).font(.system(size: 10, design: .rounded).weight(.semibold))
                                .foregroundStyle(ZyklusFarbe.tinte(schema)).lineLimit(1).minimumScaleFactor(0.6)
                        }
                    }
                }
            },
            zelle("Deko, \(name)", schema) {
                ZStack {
                    ZyklusDeko().frame(width: 328, height: 200)
                    ZyklusKarte { Text("Ganz sanft und süß").font(.system(.title3, design: .rounded).weight(.bold)).foregroundStyle(ZyklusFarbe.tinte(schema)) }
                        .frame(width: 220)
                }
            },
        ]
    }

    func testStilHell() {
        RenderTafel.speichern("zyklus-stil-hell", spalten: 2, zellen: tafel(.light))
    }

    func testStilDunkel() {
        RenderTafel.speichern("zyklus-stil-dunkel", spalten: 2, zellen: tafel(.dark))
    }
}
