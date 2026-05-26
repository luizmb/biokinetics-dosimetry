import NavigationFeature
import SwiftUI

// MARK: - AppRootView

/// A NavigationStack whose path is driven by a `NavigationFeature.ViewModel`.
/// Knows nothing about routes or the coordinator — content is provided by the caller.
public struct AppRootView<Content: View>: View {

    let viewModel: NavigationFeature.ViewModel
    @ViewBuilder let content: () -> Content

    public init(
        viewModel: NavigationFeature.ViewModel,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.viewModel = viewModel
        self.content = content
    }

    public var body: some View {
        NavigationStack(
            path: Binding(
                get: { viewModel.path },
                set: { viewModel.dispatch(.setPath($0)) }
            )
        ) {
            content()
        }
    }
}
