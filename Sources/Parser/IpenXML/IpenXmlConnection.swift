/// One `<TableLinhas>` record from an IPEN XML file.
///
/// A single record may encode a bidirectional transfer: `rateAtoB` is the
/// A→B rate and `rateBtoA` is the B→A rate. Zero means no transfer in
/// that direction.
public struct IpenXmlConnection: Decodable, Sendable {
    public let fromCompartmentNumber: Int
    public let toCompartmentNumber: Int
    /// Transfer rate from the *from* compartment to the *to* compartment (day⁻¹).
    public let rateAtoB: Double
    /// Transfer rate from the *to* compartment back to the *from* compartment (day⁻¹).
    /// `0` means the connection is unidirectional.
    public let rateBtoA: Double

    // Visual layout (reserved for future model editor UI)
    public let direction: UInt8?
    public let colorR: UInt8?
    public let colorG: UInt8?
    public let colorB: UInt8?

    #if DEBUG
    public init(
        fromCompartmentNumber: Int,
        toCompartmentNumber:   Int,
        rateAtoB:              Double,
        rateBtoA:              Double = 0,
        direction:             UInt8? = nil,
        colorR:                UInt8? = nil,
        colorG:                UInt8? = nil,
        colorB:                UInt8? = nil
    ) {
        self.fromCompartmentNumber = fromCompartmentNumber
        self.toCompartmentNumber   = toCompartmentNumber
        self.rateAtoB              = rateAtoB
        self.rateBtoA              = rateBtoA
        self.direction             = direction
        self.colorR                = colorR
        self.colorG                = colorG
        self.colorB                = colorB
    }
    #endif

    enum CodingKeys: String, CodingKey {
        case fromCompartmentNumber = "CaixaInicio"
        case toCompartmentNumber   = "CaixaFim"
        case rateAtoB              = "ValorAB"
        case rateBtoA              = "ValorBA"
        case direction             = "Direcao"
        case colorR                = "CorR"
        case colorG                = "CorG"
        case colorB                = "CorB"
    }
}
