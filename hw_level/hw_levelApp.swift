import SwiftUI

final class AppDelegate: NSObject, UIApplicationDelegate {
    var orientations: UIInterfaceOrientationMask = .portrait

    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        orientations
    }

    func updateOrientation(mode: LevelMode) {
        switch mode {
        case .flat, .top, .bottom: orientations = .portrait
        case .left: orientations = .landscapeRight
        case .right: orientations = .landscapeLeft
        }
        for case let scene as UIWindowScene in UIApplication.shared.connectedScenes where scene.activationState == .foregroundActive {
            for window in scene.windows {
                window.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
            }
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: orientations)) { error in
                NSLog("Unable to change orientation: %@", error.localizedDescription)
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
