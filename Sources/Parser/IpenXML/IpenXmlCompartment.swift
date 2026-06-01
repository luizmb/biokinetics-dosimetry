/// One `<TableCaixas>` record from an IPEN XML file.
///
/// Field names follow the original Portuguese schema; English properties
/// are used throughout Swift code. Visual layout fields are preserved
/// for future UI use.
public struct IpenXmlCompartment: Sendable {
    public let number: Int
    public let name: String
    public let follow: Bool
    /// Whether this is an intake/incorporation compartment (XML field `Incorporacao`).
    /// May be absent in older files; defaults to `false`.
    public let intake: Bool
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
        intake:    Bool   = false,
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
        self.intake    = intake
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
        case intake    = "Incorporacao"
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

extension IpenXmlCompartment: Decodable {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        number    = try  c.decode(Int.self,    forKey: .number)
        name      = try  c.decode(String.self, forKey: .name)
        follow    = try  c.decode(Bool.self,   forKey: .follow)
        intake    = (try? c.decode(Bool.self,  forKey: .intake))  ?? false
        dispose   = try  c.decode(Bool.self,   forKey: .dispose)
        posLeft   = try? c.decode(Int.self,    forKey: .posLeft)
        posTop    = try? c.decode(Int.self,    forKey: .posTop)
        posWidth  = try? c.decode(Int.self,    forKey: .posWidth)
        posHeight = try? c.decode(Int.self,    forKey: .posHeight)
        colorR    = try? c.decode(UInt8.self,  forKey: .colorR)
        colorG    = try? c.decode(UInt8.self,  forKey: .colorG)
        colorB    = try? c.decode(UInt8.self,  forKey: .colorB)
    }
}
