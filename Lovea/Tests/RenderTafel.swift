import SwiftUI
import UIKit
import XCTest

/// Z-31.3: draws a labeled grid of views to `<repo>/render-galerie/<name>.png` (scale 2, white
/// background, caption under each cell). CI uploads the folder as artifact `render-galerie`.
/// Pure SwiftUI only: `ImageRenderer` cannot draw UIKit-backed views or MapKit.
@MainActor
enum RenderTafel {
    private static let folder = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // Lovea/Tests
        .deletingLastPathComponent() // Lovea
        .deletingLastPathComponent() // repo root
        .appendingPathComponent("render-galerie", isDirectory: true)

    static func speichern(_ name: String, spalten: Int, zellen: [(titel: String, ansicht: AnyView)]) {
        let columns = max(spalten, 1)
        let rows: [[(titel: String, ansicht: AnyView)]] = stride(from: 0, to: zellen.count, by: columns).map {
            Array(zellen[$0..<min($0 + columns, zellen.count)])
        }
        let renderer = ImageRenderer(content: board(rows))
        renderer.scale = 2
        guard let png = renderer.uiImage?.pngData() else {
            XCTFail("render-galerie: \(name) could not be rendered")
            return
        }
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try png.write(to: folder.appendingPathComponent("\(name).png"))
        } catch {
            XCTFail("render-galerie: \(name) could not be written: \(error)")
        }
    }

    private static func board(_ rows: [[(titel: String, ansicht: AnyView)]]) -> some View {
        Grid(horizontalSpacing: 16, verticalSpacing: 16) {
            ForEach(rows.indices, id: \.self) { row in
                GridRow(alignment: .top) {
                    ForEach(rows[row].indices, id: \.self) { column in
                        cell(rows[row][column])
                    }
                }
            }
        }
        .padding(24)
        .background(Color.white)
        .environment(\.colorScheme, .light)
    }

    /// The view keeps its own size; the caption wraps inside a fixed width so long titles stay readable.
    private static func cell(_ item: (titel: String, ansicht: AnyView)) -> some View {
        VStack(spacing: 6) {
            item.ansicht.fixedSize()
            Text(item.titel)
                .font(.system(size: 11))
                .foregroundStyle(Color.black)
                .multilineTextAlignment(.center)
                .frame(width: 110)
        }
    }
}
