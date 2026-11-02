import SwiftUI
import AppKit
#if FITBOSS_FIREBASE_ENABLED
import GoogleSignIn
#endif

@main
struct FitBOSSApp: App {
    @NSApplicationDelegateAdaptor(FitBOSSAppDelegate.self) private var appDelegate
    @Environment(\.openWindow) private var openWindow
    // One history store shared by every FitBOSS window to prevent stale overwrites.
    @StateObject private var workoutHistory = WorkoutHistoryStore()
    var body: some Scene {
        WindowGroup("FitBOSS", id: "main") {
            ContentView(workoutHistory: workoutHistory)
                .onAppear { appDelegate.reopen = { openWindow(id: "main") } }
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

final class FitBOSSAppDelegate: NSObject, NSApplicationDelegate {
    var reopen: (() -> Void)?
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        if !hasVisibleWindows { reopen?() }
        return true
    }
}
