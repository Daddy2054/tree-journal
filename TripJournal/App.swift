import SwiftUI

@main
struct TripJournalApp: App {
    var body: some Scene {
        WindowGroup {

//            RootView(service: MockJournalService(delay: 0.25))
            RootView(service: UnimplementedJournalService())
        }
    }
}
