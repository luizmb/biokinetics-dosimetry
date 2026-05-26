import Core
import Foundation

/// Returns a converter that decodes `Data` into an ``IpenXmlModel``.
///
/// Use `XMLDecoder()` from `XMLCoder` as the factory for IPEN XML files.
/// Compose with `IpenXmlModel.toCompartmentalModel()` to produce a domain model:
///
/// ```swift
/// let model = data
///     |> loadIpenXml(using: XMLDecoder())
///     |> map(IpenXmlModel.toCompartmentalModel)
/// ```
public func loadIpenXml(
    using factory: DataDecoderFactory
) -> DataDecoder<IpenXmlModel> {
    factory.dataDecoder(for: IpenXmlModel.self)
}
