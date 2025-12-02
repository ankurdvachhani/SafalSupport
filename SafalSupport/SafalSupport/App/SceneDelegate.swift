import UIKit
import SwiftUI

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    
    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }
        
        let window = UIWindow(windowScene: windowScene)
        let contentView = ContentView()
            .environmentObject(AppState())
        window.rootViewController = UIHostingController(rootView: contentView)
        self.window = window
        window.makeKeyAndVisible()
        
        Logger.debug("Scene configured successfully")
    }
    
    func sceneDidDisconnect(_ scene: UIScene) {
        Logger.debug("Scene did disconnect")
    }
    
    func sceneDidBecomeActive(_ scene: UIScene) {
        Logger.debug("Scene did become active")
    }
    
    func sceneWillResignActive(_ scene: UIScene) {
        Logger.debug("Scene will resign active")
    }
    
    func sceneWillEnterForeground(_ scene: UIScene) {
        Logger.debug("Scene will enter foreground")
    }
    
    func sceneDidEnterBackground(_ scene: UIScene) {
        Logger.debug("Scene did enter background")
    }
    func windowScene(_ windowScene: UIWindowScene,
                     performActionFor shortcutItem: UIApplicationShortcutItem,
                     completionHandler: @escaping (Bool) -> Void) {
        print("👉 Shortcut triggered in SceneDelegate: \(shortcutItem.type)")
        completionHandler(true)
    }
}
