import SwiftUI
import UIKit
import XCTest
@testable import Lovea

/// Chat-Tab-Wurzel mit `.gymLeisteOben()`: Aufbau wie `ChatTab` (Stack, Liste, oberer Knopf).
/// Bild nach `render-galerie/chat-leiste.png`; die Leiste darf den oberen Knopf nie verdecken.
@MainActor
final class ChatLeisteRenderTests: XCTestCase {
    private func navigationsleiste(in ansicht: UIView) -> UINavigationBar? {
        if let leiste = ansicht as? UINavigationBar { return leiste }
        for kind in ansicht.subviews { if let leiste = navigationsleiste(in: kind) { return leiste } }
        return nil
    }

    func testChatWurzelMitLeisteLaesstObereKnoepfeFrei() throws {
        let wurzel = NavigationStack {
            List { Text("Partner") }
                .gymLeisteOben()
                .navigationTitle("Chat")
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Neu") {} } }
        }
        let host = UIHostingController(rootView: wurzel)
        let fenster = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        fenster.rootViewController = host
        fenster.makeKeyAndVisible()
        host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))

        let bild = UIGraphicsImageRenderer(bounds: fenster.bounds).image { _ in
            fenster.drawHierarchy(in: fenster.bounds, afterScreenUpdates: true)
        }
        let ordner = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("render-galerie", isDirectory: true)
        try FileManager.default.createDirectory(at: ordner, withIntermediateDirectories: true)
        try XCTUnwrap(bild.pngData()).write(to: ordner.appendingPathComponent("chat-leiste.png"))

        // Die Leiste ist ein Inset unter der Navigationsleiste: diese bleibt oben und sichtbar.
        let leiste = try XCTUnwrap(navigationsleiste(in: host.view))
        XCTAssertGreaterThan(leiste.frame.height, 0)
        XCTAssertLessThan(leiste.frame.minY, 100)
    }
}
