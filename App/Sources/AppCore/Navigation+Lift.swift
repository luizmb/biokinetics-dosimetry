import FP
import NavigationFeature
import SwiftRex

public extension Behavior
where Action == NavigationFeature.Action,
      State  == NavigationFeature.State,
      Environment == Void {

    func lift() -> Behavior<AppAction, AppState, World> {
        lift(
            action:      actionOptics,
            state:       stateOptics,
            environment: ignore
        )
    }
}

public extension NavigationFeature.ViewModel {
    @MainActor
    static func from(store: MainStoreType) -> NavigationFeature.ViewModel {
        NavigationFeature.ViewModel(
            store: store.projection(
                action: actionOptics.review,
                state:  stateOptics.get
            )
        )
    }
}

private let stateOptics = AppState.lens.navigation
private let actionOptics = AppAction.prism.navigation
