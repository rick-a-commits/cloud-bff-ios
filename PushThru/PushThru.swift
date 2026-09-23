import SwiftUI

@main
struct PushThruApp: App {
    var body: some Scene {
        WindowGroup {
            ChatView()
                .preferredColorScheme(.dark)
        }
    }
}
