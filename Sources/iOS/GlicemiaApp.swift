import SwiftUI

@main
struct GlicemiaApp: App {
    @StateObject private var model = PhoneModel()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Registration has to happen before the app finishes launching, so it lives
        // here rather than in a lifecycle callback.
        BackgroundRefresh.register { completion in
            Task { @MainActor in
                let success = await Self.sharedModel?.performBackgroundRefresh() ?? false
                completion(success)
            }
        }
    }

    /// The background handler is registered before `body` ever runs, so it needs a way
    /// to reach the model that does not depend on the view hierarchy existing.
    private static var sharedModel: PhoneModel?

    var body: some Scene {
        WindowGroup {
            PhoneRootView()
                .environmentObject(model)
                .preferredColorScheme(.dark)
                .onAppear { Self.sharedModel = model }
        }
        .onChange(of: scenePhase) { phase in
            switch phase {
            case .active:
                // Coming back to the app is the moment the value matters most, and the
                // one moment iOS always gives us.
                model.refreshNow()
            case .background:
                BackgroundRefresh.schedule()
            default:
                break
            }
        }
    }
}
