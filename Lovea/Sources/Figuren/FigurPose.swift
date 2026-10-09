import CoreGraphics

/// p65: the poses of the whole-body figure on the profile stage. The pose is a drawing instruction
/// on top of the state (`FigurZustand`): the state says what the person does (waves, sleeps, walks),
/// the pose says where the body is (stands, sits on the sofa or the bed edge, lies).
enum FigurPose: String, CaseIterable, Sendable, Equatable {
    case stehen, gehen, winken, sitzenSofa, sitzenBettkante, liegen

    var sitzt: Bool { self == .sitzenSofa || self == .sitzenBettkante }
    var liegt: Bool { self == .liegen }
}

/// The pose rules and the body numbers they need, without any drawing. Units are the 200 x 400 canvas
/// of the full-body figure unless a function says "Szene". `FigurView` reads the same numbers, so the
/// sofa, the bed and the hips can never drift apart.
enum FigurPoseLogik {
    static let leinwand = CGSize(width: 200, height: 400)
    /// Leg length per height step (`FigurAussehen.groesse`): taller figures have longer legs.
    static let beinLaengen: [CGFloat] = [112, 124, 136]
    static let mittelStufe = 1
    /// Where the ankles are; shoes and soles hang below.
    static let fussY: CGFloat = 372
    /// Where the soles touch the floor (the stage puts it on its floor line).
    static let bodenY: CGFloat = 392
    /// The seat touches the pelvis this far below the hip joint.
    static let sitzFlaecheUnterHuefte: CGFloat = 14

    static func beinLaenge(stufe: Int) -> CGFloat {
        beinLaengen[min(max(stufe, 0), beinLaengen.count - 1)]
    }

    static func hueftY(stufe: Int) -> CGFloat { fussY - beinLaenge(stufe: stufe) }

    /// How far the upper body drops when sitting: the hips go to knee height, minus 4.
    static func sitzVersatz(beinLaenge: CGFloat) -> CGFloat { beinLaenge * 0.5 - 4 }

    static func sitzHueftY(stufe: Int) -> CGFloat {
        hueftY(stufe: stufe) + sitzVersatz(beinLaenge: beinLaenge(stufe: stufe))
    }

    /// The seat plane the seated body rests on.
    static func sitzFlaecheY(stufe: Int) -> CGFloat { sitzHueftY(stufe: stufe) + sitzFlaecheUnterHuefte }

    /// Szene: how high the seat plane is over the floor for a figure `hoehe` tall.
    static func sitzHoehe(stufe: Int, hoehe: CGFloat) -> CGFloat {
        (bodenY - sitzFlaecheY(stufe: stufe)) * hoehe / leinwand.height
    }

    /// Szene: how far to move a figure down (+) or up (-) so it sits on a seat built for the middle step.
    static func sitzKorrektur(stufe: Int, hoehe: CGFloat) -> CGFloat {
        sitzHoehe(stufe: stufe, hoehe: hoehe) - sitzHoehe(stufe: mittelStufe, hoehe: hoehe)
    }

    /// The view frame of a pose: lying turns the body by 90 degrees, so the frame is wide, not tall.
    static func rahmen(_ pose: FigurPose, hoehe: CGFloat) -> CGSize {
        pose.liegt ? CGSize(width: hoehe, height: hoehe / 2) : CGSize(width: hoehe / 2, height: hoehe)
    }

    /// Degrees the canvas turns around its centre; -90 puts the head to the left.
    static func drehung(_ pose: FigurPose) -> Double { pose.liegt ? -90 : 0 }

    /// Which pose a place asks for. Walking beats everything; lying only in the bed.
    static func pose(platz: Platz, geht: Bool, liegt: Bool, geste: Bool) -> FigurPose {
        if geht { return .gehen }
        switch platz {
        case .sofa: return .sitzenSofa
        case .bett: return liegt ? .liegen : .sitzenBettkante
        case .fenster, .blumen: return geste ? .winken : .stehen
        }
    }

    /// The state a pose is drawn with. `schlaeft`: eyes closed (night), only meaningful lying.
    static func zustand(_ pose: FigurPose, schlaeft: Bool = false) -> FigurZustand {
        switch pose {
        case .gehen: .laeuft
        case .winken: .imChat
        case .liegen: schlaeft ? .schlaeft : .ruhig
        case .stehen, .sitzenSofa, .sitzenBettkante: .ruhig
        }
    }
}
