import Core
import Foundation
@preconcurrency import XMLCoder

// MARK: - App-level typealiases

/// The full action space of the app — defined inside `NavigationFeature`.
/// `push` and `setPath` are direct cases on this type (no `NavigationAction` wrapper).
public typealias AppAction = NavigationFeature.Action

/// The full state tree of the app — defined inside `NavigationFeature`.
public typealias AppState  = NavigationFeature.State

// MARK: - World

/// Live dependencies injected once at app startup.
/// Feature environments are derived from these primitives in the `lift` step.
public struct World: Sendable {
    public let xmlDecoder: Sendable & DataDecoderFactory

    public init(xmlDecoder: Sendable & DataDecoderFactory) {
        self.xmlDecoder = xmlDecoder
    }

    public static var live: Self {
        .init(xmlDecoder: XMLDecoder())
    }
}
