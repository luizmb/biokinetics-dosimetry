import Vitral

/// What a model's editor canvas sits on. A document can keep its own (`ModelDocument.backdrop`);
/// without one it gets its field's (`ModelField.backdrop`). Graph paper is the only one that moves
/// with the canvas: the others are a picture behind it.
public enum EditorBackdrop: String, Codable, CaseIterable, Hashable, Sendable {
    case graphPaper, dots, paper, busFloor, wood, linen, slate, aurora, glow, waves, contours, laser, fractal

    /// The name it goes by in the picker.
    public var title: String {
        switch self {
        case .graphPaper: "Graph paper"
        case .dots: "Dots"
        case .paper: "Paper"
        case .busFloor: "Chrome"
        case .wood: "Wood"
        case .linen: "Linen"
        case .slate: "Slate"
        case .aurora: "Aurora"
        case .glow: "Glow"
        case .waves: "Waves"
        case .contours: "Contours"
        case .laser: "Laser"
        case .fractal: "Fractal"
        }
    }

    /// The Vitral backdrop it draws; graph paper here at rest (the canvas slides its own).
    public var style: BackdropStyle {
        switch self {
        case .graphPaper: .grid()
        case .dots: .dots()
        case .paper: .paper
        case .busFloor: .busFloor(angle: .degrees(45))
        case .wood: .texture(.wood)
        case .linen: .texture(.linen)
        case .slate: .texture(.slate)
        case .aurora: .aurora()
        case .glow: .glow()
        case .waves: .waves()
        case .contours: .contours()
        case .laser: .laser()
        case .fractal: .fractal()
        }
    }
}

public extension ModelField {
    /// The backdrop a model in this field gets unless it keeps its own.
    var backdrop: EditorBackdrop {
        switch self {
        case .nuclear: .aurora
        case .pharmacology: .glow
        case .toxicology: .laser
        case .ecology: .contours
        case .generic: .graphPaper
        }
    }
}

public extension ModelDocument {
    /// The backdrop the editor shows: the document's own, else its field's.
    var resolvedBackdrop: EditorBackdrop { backdrop ?? field.backdrop }
}
