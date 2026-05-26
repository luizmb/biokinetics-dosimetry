import Core
import Foundation
import SwiftRex
import SwiftUI
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

// MARK: - Store conveniences

public extension Store where Action == AppAction, State == AppState, Environment == World {
    /// The live app store: initial state + full behavior wired up.
    @MainActor static var app: Store<AppAction, AppState, World> {
        Store(
            initial: AppState(),
            behavior: NavigationFeature.behavior(),
            environment: .live
        )
    }

    /// The root navigation view, ready to be placed in a `WindowGroup`.
    @MainActor var rootView: some View {
        AppRootView(store: self)
    }
}
