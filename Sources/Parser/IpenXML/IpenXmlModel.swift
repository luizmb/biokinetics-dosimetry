// MARK: - Model metadata record

/// The `<Modelo>` metadata record from an IPEN XML file.
public struct IpenXmlModelo: Decodable, Sendable {
    public let name:        String?
    public let description: String?
    public let halfLife:    Double?

    enum CodingKeys: String, CodingKey {
        case name        = "nmModelo"
        case description = "Descricao"
        case halfLife    = "meiaVida"
    }
}

// MARK: - Top-level model

/// The top-level model decoded from an IPEN XML file.
///
/// Represents the raw structure of the IPEN ADO.NET `DataSet` XML format —
/// a `Modelo` metadata record, compartments (`TableCaixas`), and connections
/// (`TableLinhas`). Use `toCompartmentalModel()` to convert to the domain.
public struct IpenXmlModel: Decodable, Sendable {
    public let modelo:      IpenXmlModelo?
    public let compartments: [IpenXmlCompartment]
    public let connections:  [IpenXmlConnection]

    #if DEBUG
    public init(
        modelo:       IpenXmlModelo? = nil,
        compartments: [IpenXmlCompartment],
        connections:  [IpenXmlConnection]
    ) {
        self.modelo       = modelo
        self.compartments = compartments
        self.connections  = connections
    }
    #endif

    enum CodingKeys: String, CodingKey {
        case modelo       = "Modelo"
        case compartments = "TableCaixas"
        case connections  = "TableLinhas"
    }
}
