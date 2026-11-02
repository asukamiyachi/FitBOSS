import SwiftUI

@main
struct FitBOSSApp: App {
    // All windows edit the same in-memory history before atomic persistence.
    @StateObject private var workoutHistory = WorkoutHistoryStore()
    var body: some Scene {
        WindowGroup("FitBOSS") {
            ContentView(workoutHistory: workoutHistory)
                .frame(minWidth: 820, minHeight: 540)
        }
        .defaultSize(width: 1200, height: 760)
    }
}
