import SwiftUI
import WatchKit

@main
struct KAIZENNWatchApp: App {
    @SceneBuilder var body: some Scene {
        WindowGroup {
            ContentView()
        }

        WKNotificationScene(controller: NotificationController.self, category: "kaizenn")
    }
}
