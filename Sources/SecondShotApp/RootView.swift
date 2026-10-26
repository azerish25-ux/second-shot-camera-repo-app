import SwiftUI

struct RootView: View {
    @StateObject private var demo = DemoSessionStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack(path: $demo.route) {
            LibraryView()
                .navigationDestination(for: DemoSessionStore.Route.self) { route in
                    switch route {
                    case .reference:
                        DemoReferenceView()
                    case .guidance:
                        DemoGuidanceView()
                    case .review:
                        DemoReviewView()
                    }
                }
        }
        .environmentObject(demo)
        .tint(SSColor.guide)
        .onChange(of: scenePhase) { _, phase in
            // Returning to the foreground is also how the user comes back from
            // Settings, so a refused camera permission is re-queried instead of
            // being assumed permanent. Nothing resumes recording by itself.
            guard phase == .active else { return }
            Task { await demo.applicationBecameActive() }
        }
    }
}

#Preview {
    RootView()
}
