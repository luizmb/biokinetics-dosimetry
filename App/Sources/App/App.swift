import AppCore
import AppDomain
import SwiftRex
import SwiftUI
import UIKit

/// The process: hands every scene to ``SceneDelegate``, which is where the world is made.
@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UIScrollView.appearance().alwaysBounceHorizontal = false
        return true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }
}

/// The app's one scene (multiple scenes are off): it makes the window, then the world around that
/// window, so the screen's traits are the ones of the window the app is drawn in, and the store.
/// It holds both for as long as the scene lives.
final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private var store: MainStoreType?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        let world = World.real(window: window)
        let store = MainStore.app(world: world)
        // The app is an ordinary Feature: it builds its own view, and the World stops there.
        window.rootViewController = UIHostingController(rootView: AppFeature.view(store: store, environment: world))
        window.makeKeyAndVisible()
        self.window = window
        self.store = store
    }
}
