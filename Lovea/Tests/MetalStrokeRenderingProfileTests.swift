import XCTest
@testable import Lovea

final class MetalStrokeRenderingProfileTests: XCTestCase {
    func testPressureTogglesControlRadiusAndAlphaIndependently() {
        var stroke = sampleStroke()
        stroke.pressureControlsSize = false
        stroke.pressureControlsOpacity = false
        XCTAssertEqual(MetalStrokeRenderingProfile.radius(stroke, pressure: 0.25), 10)
        XCTAssertEqual(MetalStrokeRenderingProfile.alpha(stroke, pressure: 0.25), 0.8)

        stroke.pressureControlsSize = true
        XCTAssertEqual(MetalStrokeRenderingProfile.radius(stroke, pressure: 0.25), 2.5)
        XCTAssertEqual(MetalStrokeRenderingProfile.alpha(stroke, pressure: 0.25), 0.8)

        stroke.pressureControlsOpacity = true
        XCTAssertEqual(MetalStrokeRenderingProfile.alpha(stroke, pressure: 0.25), 0.2)
    }

    func testStabilizerSmoothsInteriorWithoutMovingEndpoints() {
        var stroke = sampleStroke()
        stroke.stabilizer = 0
        XCTAssertEqual(MetalStrokeRenderingProfile.smoothedPoints(stroke), stroke.points)

        stroke.stabilizer = 4
        let smoothed = MetalStrokeRenderingProfile.smoothedPoints(stroke)
        XCTAssertEqual(smoothed.first, stroke.points.first)
        XCTAssertEqual(smoothed.last, stroke.points.last)
        XCTAssertLessThan(smoothed[1].y, stroke.points[1].y)
        XCTAssertGreaterThan(smoothed[1].y, 0)
    }

    private func sampleStroke() -> MetalPaintStroke {
        MetalPaintStroke(
            points: [
                StrokePoint(x: 0, y: 0, pressure: 0.25),
                StrokePoint(x: 10, y: 10, pressure: 0.25),
                StrokePoint(x: 20, y: 0, pressure: 0.25),
                StrokePoint(x: 30, y: 0, pressure: 0.25)
            ],
            color: RGBAColor(red: 0, green: 0, blue: 0),
            width: 20,
            opacity: 0.8,
            tool: .brush,
            brushPreset: "pen"
        )
    }
}
