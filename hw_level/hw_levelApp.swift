import SwiftUI

final class AppDelegate: NSObject, UIApplicationDelegate {
    private static var orientations: UIInterfaceOrientationMask = .portrait

    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        Self.orientations
    }

    // The adaptor wraps the delegate, so UIApplication.shared.delegate cannot be cast to AppDelegate.
    static func updateOrientation(mode: LevelMode) {
        switch mode {
        case .flat, .top, .bottom: Self.orientations = .portrait
        case .left: Self.orientations = .landscapeLeft
        case .right: Self.orientations = .landscapeRight
        }
        let orientations = Self.orientations
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
