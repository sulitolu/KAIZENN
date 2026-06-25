import Foundation
import BackgroundTasks

enum BackgroundSyncScheduler {
    static let taskID = "com.kaizenn.healthsync"

    static func register(handler: @escaping () async -> Void) {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskID, using: nil) { task in
            schedule()   // chain the next run
            let work = Task { await handler(); task.setTaskCompleted(success: true) }
            task.expirationHandler = { work.cancel(); task.setTaskCompleted(success: false) }
        }
    }

    /// Schedule the next run for ~5am local (earliest-begin).
    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: taskID)
        let cal = Calendar.current
        let tomorrow5am = cal.nextDate(after: Date(),
            matching: DateComponents(hour: 5), matchingPolicy: .nextTime)
        request.earliestBeginDate = tomorrow5am
        try? BGTaskScheduler.shared.submit(request)
    }
}
