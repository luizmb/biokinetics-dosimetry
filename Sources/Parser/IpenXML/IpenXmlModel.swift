/// The top-level model decoded from an IPEN XML file.
///
/// Represents the raw structure of the IPEN ADO.NET `DataSet` XML format —
/// a list of compartments (`TableCaixas`) and connections (`TableLinhas`).
/// Use `toCompartmentalModel()` to convert to the domain representation.
public struct IpenXmlModel: Decodable, Sendable {
    public let compartments: [IpenXmlCompartment]
    public let connections: [IpenXmlConnection]

    enum CodingKeys: String, CodingKey {
        case compartments = "TableCaixas"
        case connections  = "TableLinhas"
    }
}
