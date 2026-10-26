import SwiftUI

struct RootView: View {
    @StateObject private var demo = DemoSessionStore()

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
    }
}

#Preview {
    RootView()
}
