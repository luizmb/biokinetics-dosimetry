import AppDomain
import CalculatorFeature
import EditorFeature
import HomeFeature
import SwiftRexArchitecture
import SwiftUI

// MARK: - AppRoute → Module

public extension AppRoute {

    /// Returns the `Module` for this route — behavior + view both lifted to
    /// `AppAction / AppState / World`. Lives in AppCore (not AppDomain) because
    /// it references `Module` lift extensions and the app-level type aliases.
    @MainActor
    func module() -> Module<AppAction, AppState, World, AnyView> {
        switch self {
        case .home:       Module.home.lift()
        case .editor:     Module.editor.lift()
        case .calculator: Module.calculator.lift()
        }
    }
}
