import UIKit

enum StudioTool: String, CaseIterable, Identifiable {
    case brush
    case eraser
    case lasso
    case fill
    case eyedropper
    case shape
    case transform
    case text

    var id: String { rawValue }

    var title: String {
        switch self {
        case .brush: "Pinsel"
        case .eraser: "Radierer"
        case .lasso: "Auswahl"
        case .fill: "Füllen"
        case .eyedropper: "Pipette"
        case .shape: "Formen"
        case .transform: "Transformieren"
        case .text: "Text"
        }
    }

    var symbol: String {
        switch self {
        case .brush: "paintbrush.pointed"
        case .eraser: "eraser"
        case .lasso: "lasso"
        case .fill: "drop"
        case .eyedropper: "eyedropper"
        case .shape: "square.on.circle"
        case .transform: "arrow.up.and.down.and.arrow.left.and.right"
        case .text: "textformat"
        }
    }

    var activeSymbol: String {
        switch self {
        case .brush: "paintbrush.pointed.fill"
        case .eraser: "eraser.fill"
        case .fill: "drop.fill"
        case .eyedropper: "eyedropper.full"
        case .shape: "square.on.circle.fill"
        default: symbol
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
        case .gPen: "Tinte"
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

    var defaultWidth: Double {
        switch self {
        case .pen: 7
        case .gPen: 5
        case .pencil: 5
        case .marker: 18
        case .airbrush: 60
        case .watercolor: 30
        case .chalk: 16
        case .calligraphy: 14
        case .highlighter: 26
        case .pixel: 4
        }
    }

    var defaultOpacity: Double {
        switch self {
        case .airbrush: 0.6
        case .watercolor: 0.7
        case .highlighter: 0.4
        default: 1
        }
    }
}

extension RGBAColor {
    static let studioBlack = RGBAColor(red: 0.06, green: 0.06, blue: 0.07)

    var uiColor: UIColor {
        UIColor(red: CGFloat(red), green: CGFloat(green), blue: CGFloat(blue), alpha: CGFloat(alpha))
    }

    init(uiColor: UIColor) {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        self.init(red: Double(red), green: Double(green), blue: Double(blue), alpha: Double(alpha))
    }
}
