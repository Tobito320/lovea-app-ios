import Foundation
import SwiftUI
import UIKit
import WidgetKit

/// Spec 10 "Foto und Frage" (groß): letztes Foto oder letzte als Foto geteilte Zeichnung des
/// Partners (nie ein Snap, siehe `WidgetStandSchreiber.letztesFotoDesPartners`), Frage des Tages.
struct FotoFrageWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "FotoFrage", provider: WidgetStandProvider()) { entry in
            FotoFrageView(entry: entry)
        }
        .configurationDisplayName("Foto und Frage")
        .description("Letztes Foto des Partners und die Frage des Tages.")
        .supportedFamilies([.systemLarge])
        .contentMarginsDisabled() // photo runs edge to edge; the question pads itself
    }
}

private struct FotoFrageView: View {
    let entry: WidgetStandEntry

    var body: some View {
        ZStack(alignment: .bottom) {
            FotoHintergrund(bild: entry.partnerFoto)
            if let frage = entry.stand.frageDesTages {
                VStack(alignment: .leading, spacing: 4) {
                    Text("FRAGE DES TAGES").font(.caption2.weight(.semibold)).foregroundStyle(.white.opacity(0.8))
                    Text(frage).font(.title3.weight(.semibold)).fontDesign(.rounded).foregroundStyle(.white)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: .top, endPoint: .bottom))
            }
        }
        .widgetURL(URL(string: "lovea://chat"))
        .widgetHintergrund(WidgetStil.rose)
    }
}

private struct FotoHintergrund: View {
    let bild: UIImage?
    var body: some View {
        if let bild {
            Image(uiImage: bild).resizable().scaledToFill()
        } else {
            ZStack {
                LinearGradient(colors: [WidgetStil.rose.opacity(0.35), WidgetStil.rose.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing)
                Image(systemName: "photo").font(.largeTitle).foregroundStyle(.secondary)
            }
        }
    }
}
