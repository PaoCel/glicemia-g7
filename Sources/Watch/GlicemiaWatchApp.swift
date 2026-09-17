import SwiftUI

@main
struct GlicemiaWatchApp: App {
    @WKExtensionDelegateAdaptor(WatchDelegate.self) private var delegate

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environmentObject(WatchModel.shared)
        }
    }
}
