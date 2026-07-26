import SwiftUI
import SwiftData

@main
struct PayTrackerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(AppModelContainer.shared)
    }
}
