import PencilKit
import UIKit

enum StudioTool: String, CaseIterable, Identifiable {
    case brush
    case eraser
    case lasso
    case fill
    case eyedropper

    var id: String { rawValue }

    var title: String {
        switch self {
        case .brush: "Pinsel"
        case .eraser: "Radierer"
        case .lasso: "Auswahl"
        case .fill: "Füllen"
        case .eyedropper: "Pipette"
        }
    }

    var symbol: String {
        switch self {
        case .brush: "paintbrush.pointed.fill"
        case .eraser: "eraser.fill"
        case .lasso: "lasso"
        case .fill: "paintbucket.fill"
        case .eyedropper: "eyedropper"
        }
    }
}

enum BrushPreset: String, CaseIterable, Identifiable {
    case pen
    case gPen
    case pencil
    case marker
    case airbrush
    case watercolor
    case chalk
    case calligraphy
    case highlighter
    case pixel

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pen: "Stift"
        case .gPen: "Tinte / G-Pen"
        case .pencil: "Bleistift"
        case .marker: "Marker"
        case .airbrush: "Airbrush"
        case .watercolor: "Aquarell"
        case .chalk: "Kreide"
        case .calligraphy: "Kalligrafie"
        case .highlighter: "Leuchtstift"
        case .pixel: "Pixel"
        }
    }

    var inkType: PKInkingTool.InkType {
        switch self {
        case .pen: .pen
        case .gPen: .fountainPen
        case .pencil: .pencil
        case .marker: .marker
        case .airbrush: .watercolor
        case .watercolor: .watercolor
        case .chalk: .crayon
        case .calligraphy: .fountainPen
        case .highlighter: .marker
        case .pixel: .monoline
        }
    }

    var defaultWidth: CGFloat {
        switch self {
        case .pen: 7
        case .gPen: 5
        case .pencil: 5
        case .marker: 18
        case .airbrush: 32
        case .watercolor: 24
        case .chalk: 16
        case .calligraphy: 12
        case .highlighter: 26
        case .pixel: 4
        }
    }

    var defaultOpacity: CGFloat {
        switch self {
        case .airbrush: 0.35
        case .watercolor: 0.55
        case .highlighter: 0.4
        default: 1
        }
    }
}

extension RGBAColor {
    static let studioBlack = RGBAColor(red: 0.06, green: 0.06, blue: 0.07)

    var uiColor: UIColor {
        UIColor(
            red: CGFloat(red),
            green: CGFloat(green),
            blue: CGFloat(blue),
            alpha: CGFloat(alpha)
        )
    }

    init(uiColor: UIColor) {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        self.init(
            red: Double(red),
            green: Double(green),
            blue: Double(blue),
            alpha: Double(alpha)
        )
    }
}
