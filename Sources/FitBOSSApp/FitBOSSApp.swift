import SwiftUI
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

@main
struct FitBOSSApp: App {
    var body: some Scene {
        WindowGroup("FitBOSS") {
            ContentView()
                .frame(minWidth: 820, minHeight: 540)
                .onOpenURL { url in
                    #if canImport(GoogleSignIn)
                    _ = GIDSignIn.sharedInstance.handle(url)
                    #endif
                }
        }
        .defaultSize(width: 1200, height: 760)
    }
}
