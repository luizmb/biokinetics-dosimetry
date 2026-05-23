import Foundation
import Core
import FP

public func loadCompartmentalModel(
    using factory: DataDecoderFactory
) -> Convert<Data, CompartmentalModel, DecodingError> {
    factory
        .dataDecoder(for: CompartmentalModelDTO.self)
        .map(CompartmentalModelDTO.toDomain)
}

struct CompartmentalModelDTO: Decodable {
    let compartments: [CompartmentDTO]
    let connections: [ConnectionDTO]

    enum CodingKeys: String, CodingKey {
        case compartments = "TableCaixas"
        case connections = "TableLinhas"
    }

    struct CompartmentDTO: Decodable {
        let number: Int
        let name: String
        let follow: Bool
        let dispose: Bool

        enum CodingKeys: String, CodingKey {
            case number = "Numero"
            case name = "Nome"
            case follow = "Acompanhar"
            case dispose = "Eliminacao"
        }
    }

    struct ConnectionDTO: Decodable {
        let fromCompartmentNumber: Int
        let toCompartmentNumber: Int
        let rateAtoB: Double
        let rateBtoA: Double

        enum CodingKeys: String, CodingKey {
            case fromCompartmentNumber = "CaixaInicio"
            case toCompartmentNumber = "CaixaFim"
            case rateAtoB = "ValorAB"
            case rateBtoA = "ValorBA"
        }
    }

    static func toDomain(_ dto: CompartmentalModelDTO) -> CompartmentalModel {
        CompartmentalModel(
            compartments: dto.compartments.map(CompartmentDTO.toDomain),
            connections: dto.connections.flatMap(ConnectionDTO.toDomain)
        )
    }
}

extension CompartmentalModelDTO.CompartmentDTO {
    static func toDomain(_ dto: CompartmentalModelDTO.CompartmentDTO) -> Compartment {
        Compartment(
            id: String(dto.number),
            name: dto.name,
            follow: dto.follow,
            intake: false,
            dispose: dto.dispose,
            fraction: 0
        )
    }
}

extension CompartmentalModelDTO.ConnectionDTO {
    static func toDomain(_ dto: CompartmentalModelDTO.ConnectionDTO) -> [CompartmentConnection] {
        let from = String(dto.fromCompartmentNumber)
        let to = String(dto.toCompartmentNumber)
        let aToB = dto.rateAtoB == 0 ? [] : [CompartmentConnection(from: from, to: to, rate: dto.rateAtoB)]
        let bToA = dto.rateBtoA == 0 ? [] : [CompartmentConnection(from: to, to: from, rate: dto.rateBtoA)]
        return aToB <> bToA
    }
}
