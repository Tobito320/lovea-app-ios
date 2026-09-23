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
    }
}

private struct FotoFrageView: View {
    let entry: WidgetStandEntry

    var body: some View {
        ZStack(alignment: .bottom) {
            FotoHintergrund(bild: entry.partnerFoto)
            if let frage = entry.stand.frageDesTages {
                Text(frage)
                    .font(.callout).bold()
                    .foregroundStyle(.white)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.black.opacity(0.55))
            }
        }
        .widgetURL(URL(string: "lovea://chat"))
        .containerBackground(.background, for: .widget)
    }
}

private struct FotoHintergrund: View {
    let bild: UIImage?
    var body: some View {
        if let bild {
            Image(uiImage: bild).resizable().scaledToFill()
        } else {
            ZStack {
                Rectangle().fill(Color.secondary.opacity(0.2))
                Image(systemName: "photo").font(.largeTitle).foregroundStyle(.secondary)
            }
        }
    }
}
