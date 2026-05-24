import AppDomain
import SwiftUI

public struct ContentView: View {
    let coordinator: AppCoordinator

    public init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        NavigationStack(path: coordinator.homeVM.pathBinding) {
            HomeView(viewModel: coordinator.homeVM)
                .navigationDestination(for: AppRoute.self) { route in
                    coordinator.destination(for: route)
                }
        }
    }
}
