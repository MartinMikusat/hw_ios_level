import SwiftUI

final class AppDelegate: NSObject, UIApplicationDelegate {
    var orientations: UIInterfaceOrientationMask = .portrait

    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        orientations
    }

    func updateOrientation(flat: Bool) {
        orientations = flat ? .portrait : .allButUpsideDown
        for case let scene as UIWindowScene in UIApplication.shared.connectedScenes where scene.activationState == .foregroundActive {
            for window in scene.windows {
                window.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
            }
            if flat {
                scene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait)) { error in
                    NSLog("Unable to return to portrait: %@", error.localizedDescription)
                }
            }
        }
    }
}

@main
struct LevelApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    var body: some Scene {
        WindowGroup { ContentView() }
    }
}
