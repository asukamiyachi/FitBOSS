import SwiftUI
#if FITBOSS_FIREBASE_ENABLED
import GoogleSignIn
#endif

@main
struct FitBOSSApp: App {
    var body: some Scene {
        WindowGroup("FitBOSS") {
            ContentView()
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
