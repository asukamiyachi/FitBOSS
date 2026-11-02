import SwiftUI
#if FITBOSS_FIREBASE_ENABLED
import GoogleSignIn
#endif

@main
struct FitBOSSApp: App {
    // One history store shared by every FitBOSS window to prevent stale overwrites.
    @StateObject private var workoutHistory = WorkoutHistoryStore()
    var body: some Scene {
        WindowGroup("FitBOSS") {
            ContentView(workoutHistory: workoutHistory)
                .frame(minWidth: 820, minHeight: 540)
                .onOpenURL { url in
                    #if FITBOSS_FIREBASE_ENABLED
                    _ = GIDSignIn.sharedInstance.handle(url)
                    #endif
                }
        }
        .defaultSize(width: 1200, height: 760)
    }
}
