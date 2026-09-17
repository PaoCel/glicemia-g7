import WatchKit

/// Keeps the Watch app fed while it is not on screen.
///
/// watchOS grants background refresh on a budget, and the budget is far larger when the
/// app has a complication on the active watch face. That is why the complication is
/// part of this milestone rather than a decoration for later: it is the mechanism.
final class WatchDelegate: NSObject, WKExtensionDelegate {

    /// Roughly the sensor cadence. The system treats it as a request, not a promise,
    /// and will space runs out further when the budget runs low.
    private static let refreshInterval: TimeInterval = 5 * 60

    func applicationDidFinishLaunching() {
        scheduleNextRefresh()
    }

    func applicationDidBecomeActive() {
        // Raising the wrist is the moment the value has to be right. Ask Dexcom
        // directly, and the iPhone as well in case it already has something newer.
        WatchModel.shared.fetchIfNeeded()
        WatchModel.shared.requestSnapshot()
    }

    func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
        for task in backgroundTasks {
            switch task {
            case let task as WKApplicationRefreshBackgroundTask:
                // Ask the iPhone for a value, then queue the next slot. Completing the
                // task straight away is deliberate: the reply arrives through
                // WatchConnectivity, which brings its own background task with it.
                WatchModel.shared.fetchIfNeeded(force: true)
                WatchModel.shared.requestSnapshot()
                scheduleNextRefresh()
                task.setTaskCompletedWithSnapshot(false)

            case let task as WKWatchConnectivityRefreshBackgroundTask:
                // The payload has already been handed to the session delegate by the
                // time this runs; the task exists only so the app stays awake for it.
                task.setTaskCompletedWithSnapshot(true)

            case let task as WKSnapshotRefreshBackgroundTask:
                task.setTaskCompleted(
                    restoredDefaultState: true,
                    estimatedSnapshotExpiration: Date(timeIntervalSinceNow: Self.refreshInterval),
                    userInfo: nil
                )

            default:
                task.setTaskCompletedWithSnapshot(false)
            }
        }
    }

    private func scheduleNextRefresh() {
        WKExtension.shared().scheduleBackgroundRefresh(
            withPreferredDate: Date(timeIntervalSinceNow: Self.refreshInterval),
            userInfo: nil
        ) { _ in }
    }
}
