import AppDomain
import CalculatorFeature
import EditorFeature
import HomeFeature
import SwiftRex
import SwiftRexArchitecture
import SwiftUI

// MARK: - AppRoute → View

public extension AppRoute {

    /// Produces the view for this route, already lifted to `AppAction / AppState / World`.
    /// `@ViewBuilder` unifies the concrete per-route view types without `AnyView` erasure.
    @MainActor @ViewBuilder
    func view(in store: Store<AppAction, AppState, World>) -> some View {
        switch self {
        case .home:       Module.home.lift().view(for: store)
        case .editor:     Module.editor.lift().view(for: store)
        case .calculator: Module.calculator.lift().view(for: store)
        }
    }
}
