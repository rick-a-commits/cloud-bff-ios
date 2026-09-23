import SwiftUI

@main
struct PushThruApp: App {
    @State private var hasSelectedLanguage = UserPreferences.hasSelectedLanguage
    
    var body: some Scene {
        WindowGroup {
            if hasSelectedLanguage {
                ChatView()
                    .preferredColorScheme(.dark)
            } else {
                LanguagePickerView { _ in
                    // Selection is already persisted to UserDefaults inside the view.
                    // Just flip the flag so we swap views.
                    withAnimation {
                        hasSelectedLanguage = true
                    }
                }
                .preferredColorScheme(.dark)
            }
        }
    }
}
