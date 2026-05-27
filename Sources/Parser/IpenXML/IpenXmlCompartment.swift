/// One `<TableCaixas>` record from an IPEN XML file.
///
/// Field names follow the original Portuguese schema; English properties
/// are used throughout Swift code. Visual layout fields are preserved
/// for future UI use.
public struct IpenXmlCompartment: Decodable, Sendable {
    public let number: Int
    public let name: String
    public let follow: Bool
    public let dispose: Bool

    // Visual layout (reserved for future model editor UI)
    public let posLeft: Int?
    public let posTop: Int?
    public let posWidth: Int?
    public let posHeight: Int?
    public let colorR: UInt8?
    public let colorG: UInt8?
    public let colorB: UInt8?

    #if DEBUG
    public init(
        number:    Int,
        name:      String,
        follow:    Bool,
        dispose:   Bool,
        posLeft:   Int?   = nil,
        posTop:    Int?   = nil,
        posWidth:  Int?   = nil,
        posHeight: Int?   = nil,
        colorR:    UInt8? = nil,
        colorG:    UInt8? = nil,
        colorB:    UInt8? = nil
    ) {
        self.number    = number
        self.name      = name
        self.follow    = follow
        self.dispose   = dispose
        self.posLeft   = posLeft
        self.posTop    = posTop
        self.posWidth  = posWidth
        self.posHeight = posHeight
        self.colorR    = colorR
        self.colorG    = colorG
        self.colorB    = colorB
    }
    #endif

    enum CodingKeys: String, CodingKey {
        case number    = "Numero"
        case name      = "Nome"
        case follow    = "Acompanhar"
        case dispose   = "Eliminacao"
        case posLeft   = "PosLeft"
        case posTop    = "PosTop"
        case posWidth  = "PosWidth"
        case posHeight = "PosHeight"
        case colorR    = "CorR"
        case colorG    = "CorG"
        case colorB    = "CorB"
    }
}
