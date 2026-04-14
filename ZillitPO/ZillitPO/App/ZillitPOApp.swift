import SwiftUI
import Combine

#if canImport(UIKit)
import UIKit

// MARK: - iOS 13 App Entry (SceneDelegate based)

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: "Default", sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
    }
}

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    let appState = POViewModel()
    private var themeCancellable: Any?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let rootView = ContentView(appState: appState).environmentObject(appState)
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = UIHostingController(rootView: rootView)
        window.makeKeyAndVisible()
        self.window = window

        // Sync UIKit window interface style with ThemeManager so sheets,
        // alerts, and safe-area chrome follow the app's dark mode toggle.
        let theme = ThemeManager.shared
        window.overrideUserInterfaceStyle = theme.isDark ? .dark : .light
        themeCancellable = theme.$isDark.sink { [weak window] isDark in
            window?.overrideUserInterfaceStyle = isDark ? .dark : .light
        }
    }
}
#endif
