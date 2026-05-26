import AppDomain
import CalculatorFeature
import Core
import EditorFeature
import FP
import Foundation
import SwiftRex
import SwiftRexArchitecture
import SwiftUI
@preconcurrency import XMLCoder

// MARK: - AppState

/// Flat application state. Every feature is a sibling — none is parent to another.
@Lenses
public struct AppState: Sendable {
    public var navigation: NavigationFeature.State = .init()
    public var home:       HomeFeature.State       = HomeFeature.initialState()
    public var editor:     EditorFeature.State     = EditorFeature.initialState()
    public var calculator: CalculatorFeature.State = CalculatorFeature.initialState()
    public init() {}
}

// MARK: - AppAction

/// Flat action space. Navigation actions are their own case, not a parent wrapper.
@Prisms @dynamicMemberLookup
public enum AppAction: Sendable {
    case navigation(NavigationFeature.Action)
    case home(HomeFeature.Action)
    case editor(EditorFeature.Action)
    case calculator(CalculatorFeature.Action)
}

// MARK: - World

/// Live dependencies injected once at app startup.
public struct World: Sendable {
    public let xmlDecoder: Sendable & DataDecoderFactory

    public init(xmlDecoder: Sendable & DataDecoderFactory) {
        self.xmlDecoder = xmlDecoder
    }

    public static var live: Self { .init(xmlDecoder: XMLDecoder()) }
}

// MARK: - Store conveniences

public extension Store where Action == AppAction, State == AppState, Environment == World {

    /// Builds the live app store: all features lifted to the flat AppState/AppAction level,
    /// plus the bridge behavior that converts Home edit/calculate actions into navigation pushes.
    @MainActor static var app: Store<AppAction, AppState, World> {
        Store(
            initial: AppState(),
            behavior: navigationBehavior()
                <> homeBehavior()
                <> editorBehavior()
                <> calculatorBehavior()
                <> bridgeBehavior(),
            environment: .live
        )
    }

    /// The root navigation view, ready to be placed in a `WindowGroup`.
    @MainActor var rootView: some View {
        AppRootView(viewModel: AppRootViewModel(store: self))
    }
}

// MARK: - Lifted sub-behaviors

private func navigationBehavior() -> Behavior<AppAction, AppState, World> {
    NavigationFeature.behavior()
        .lift(
            action:      AppAction.prism.navigation,
            state:       AppState.lens.navigation,
            environment: ignore
        )
}

private func homeBehavior() -> Behavior<AppAction, AppState, World> {
    FeatureHost.home.behavior
        .lift(
            action:      AppAction.prism.home,
            state:       AppState.lens.home,
            environment: \.xmlDecoder >>> HomeFeature.Environment.init
        )
}

private func editorBehavior() -> Behavior<AppAction, AppState, World> {
    FeatureHost.editor.behavior
        .lift(
            action:      AppAction.prism.editor,
            state:       AppState.lens.editor,
            environment: ignore
        )
}

private func calculatorBehavior() -> Behavior<AppAction, AppState, World> {
    FeatureHost.calculator.behavior
        .lift(
            action:      AppAction.prism.calculator,
            state:       AppState.lens.calculator,
            environment: const(.live)
        )
}

// MARK: - Bridge behavior

/// Intercepts Home actions that imply navigation and dispatches the appropriate
/// route push + target-feature document load. Lives here — not inside NavigationFeature —
/// because NavigationFeature is intentionally unaware of other features.
private func bridgeBehavior() -> Behavior<AppAction, AppState, World> {
    Behavior { dispatched, _ in
        switch dispatched.action {
        case let .home(.edit(document: doc)):
            .reduce { $0.editor.document = doc }
            .produce(const(.just(.navigation(.setPath([.editor])))))

        case let .home(.calculate(document: doc)):
            .reduce { $0.calculator.document = doc }
            .produce(const(.just(.navigation(.setPath([.calculator])))))

        default:
            .doNothing
        }
    }
}
