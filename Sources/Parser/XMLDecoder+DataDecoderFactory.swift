import Foundation
import Core
import XMLCoder

extension XMLDecoder: @retroactive DataDecoderFactory {
    public func dataDecoder<Output: Decodable>(for type: Output.Type = Output.self) -> DataDecoder<Output> {
        Convert { [self] data in
            Result { try decode(type, from: data) }
                .mapError {
                    $0 as? DecodingError
                        ?? DecodingError.dataCorrupted(.init(
                            codingPath: [],
                            debugDescription: "Unknown XML decoding error: \($0)"
                        ))
                }
        }
    }
}
