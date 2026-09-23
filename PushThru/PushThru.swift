import SwiftUI

/// Auth state — for now, a simple flag stored in UserDefaults.
/// When we integrate MSAL, this will hold the actual token state.
enum AuthState {
    private static let signedInKey = "pushthru.signedIn"
    
    static var isSignedIn: Bool {
        get { UserDefaults.standard.bool(forKey: signedInKey) }
        set { UserDefaults.standard.set(newValue, forKey: signedInKey) }
    }
}

@main
struct PushThruApp: App {
    @State private var hasSelectedLanguage = UserPreferences.hasSelectedLanguage
    @State private var isSignedIn = AuthState.isSignedIn
    
    var body: some Scene {
        WindowGroup {
            rootView
                .preferredColorScheme(.dark)
        }
    }
    
    @ViewBuilder
    private var rootView: some View {
        if !hasSelectedLanguage {
            LanguagePickerView { _ in
                withAnimation {
                    hasSelectedLanguage = true
                }
            }
        } else if !isSignedIn {
            WelcomeView(
                onSignIn: {
                    // Placeholder: for now, just flip the flag so we can see the chat.
                    // Next session, this triggers the MSAL sign-in flow.
                    AuthState.isSignedIn = true
                    withAnimation {
                        isSignedIn = true
                    }
                },
                onCreateAccount: {
                    // Placeholder: same as sign in for now.
                    // Next session, this triggers the MSAL sign-up flow, then DOB screen.
                    AuthState.isSignedIn = true
                    withAnimation {
                        isSignedIn = true
                    }
                }
            )
        } else {
            ChatView()
        }
    }
}
