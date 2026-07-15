import SwiftUI

@main
struct IdeaForgeWatchApp: App {
    @State private var store = IdeaForgeStore.production()

    var body: some Scene {
        WindowGroup {
            WatchCaptureView(store: store)
                .onAppear {
                    IdeaForgeLog.lifecycle.info("watchOS app appeared")
                }
        }
    }
}
