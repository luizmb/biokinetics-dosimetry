import AppDomain
import EditorFeature
import CalculatorFeature
import Foundation
import SwiftRexArchitecture

@Prisms @dynamicMemberLookup
public enum AppAction: Sendable {
    case home(HomeFeature.Action)
    case editor(EditorFeature.Action)
    case calculator(CalculatorFeature.Action)
}

@Lenses
public struct AppState: Sendable {
    public var home:       HomeFeature.State       = HomeFeature.initialState()
    public var editor:     EditorFeature.State     = EditorFeature.initialState()
    public var calculator: CalculatorFeature.State = CalculatorFeature.initialState()

    public init() {}
}

/// Live dependencies injected at app startup. Feature environments are derived
/// from these primitives during the `lift` step in `AppCoordinator`.
public struct AppEnvironment: Sendable {
    public let parseXML: @Sendable (Data) -> Result<ModelDocument, ParseError>

    public init(parseXML: @escaping @Sendable (Data) -> Result<ModelDocument, ParseError>) {
        self.parseXML = parseXML
    }

    public static var live: Self {
        .init(parseXML: parseIpenXMLData)
    }

    public static var mock: Self {
        .init(parseXML: { _ in .failure(ParseError("Mock environment: XML parsing unavailable")) })
    }
}
