#if os(iOS)
import AppDomain
import ReactiveConcurrency
import UIKit

// The window's traits, from UIKit's trait-change callback, as a publisher of pure values. **Cold**,
// like every factory behind `World`: the registration is made when a subscription starts and dropped
// when it ends.

/// One window's traits: what it has now, then every change UIKit reports, until unsubscribed. The
/// window is the app's one window, handed over by the scene delegate that made it, so nothing here
/// looks for one. UIKit posts no notification for a trait change, so this is the one callback
/// bridge. On the main actor throughout: the window and its registration live there, and waiting is
/// an `await`.
func traits(of window: UIWindow) -> Publisher<DeviceTraits, Never> {
    Publisher { @MainActor continuation in
        continuation.yield(DeviceTraits(window.traitCollection))
        let registration = window.registerForTraitChanges(
            [UITraitUserInterfaceStyle.self, UITraitHorizontalSizeClass.self, UITraitVerticalSizeClass.self]
        ) { (window: UIWindow, _: UITraitCollection) in
            continuation.yield(DeviceTraits(window.traitCollection))
        }
        await continuation.suspendUntilCancelled()
        window.unregisterForTraitChanges(registration)
    }
    .removeDuplicates()
}

private extension DeviceTraits {
    init(_ traits: UITraitCollection) {
        self.init(
            isDark: traits.userInterfaceStyle == .dark,
            isCompactWidth: traits.horizontalSizeClass == .compact,
            isCompactHeight: traits.verticalSizeClass == .compact
        )
    }
}
#endif
