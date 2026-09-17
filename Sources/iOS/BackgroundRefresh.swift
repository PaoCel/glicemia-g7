import Foundation
import BackgroundTasks
import UIKit

/// iOS background refresh for the glucose source.
///
/// What this can and cannot do is worth stating plainly: `BGAppRefreshTask` is
/// opportunistic. iOS decides when to run it based on usage patterns, battery and
/// network, and it will not run at all if the user force-quits the app. In practice it
/// lands every 15-30 minutes, against a sensor that publishes every 5. It closes part
/// of the gap; it does not make the app live in the background.
enum BackgroundRefresh {

    static let taskIdentifier = "com.paolocelestini.glicemia.refresh"

    /// Registered once at launch, before the app finishes starting.
    static func register(handler: @escaping (@escaping (Bool) -> Void) -> Void) {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: taskIdentifier,
            using: nil
        ) { task in
            guard let task = task as? BGAppRefreshTask else { return }

            // Always schedule the next one first: if this run is cut short there is
            // still a pending request, otherwise background refresh dies silently.
            schedule()

            task.expirationHandler = {
                task.setTaskCompleted(success: false)
            }

            handler { success in
                task.setTaskCompleted(success: success)
            }
        }
    }

    /// Asks for the next run. The system treats the date as a floor, not a promise.
    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 10 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            // Submitting fails on simulators and when the user has disabled background
            // refresh. Neither is worth interrupting the app for.
        }
    }
}
