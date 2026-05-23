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
