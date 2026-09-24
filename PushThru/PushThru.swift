import SwiftUI

@main
struct PushThruApp: App {
    @State private var hasSelectedLanguage = UserPreferences.hasSelectedLanguage
    @State private var auth = AuthService.shared

    var body: some Scene {
        WindowGroup {
            rootView
                .preferredColorScheme(.dark)
                .onOpenURL { url in
                    AuthService.handleRedirect(url)
                }
                .alert(
                    "Sign-in problem",
                    isPresented: Binding(
                        get: { auth.errorMessage != nil },
                        set: { if !$0 { auth.errorMessage = nil } }
                    )
                ) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(auth.errorMessage ?? "")
                }
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
        } else if !auth.isSignedIn {
            WelcomeView(
                onSignIn: {
                    Task { await auth.signIn() }
                },
                onCreateAccount: {
                    // Opens the hosted page directly on the sign-up view.
                    // DOB / age gate gets inserted after first sign-up (next step).
                    Task { await auth.createAccount() }
                }
            )
            .disabled(auth.isWorking)
            .overlay {
                if auth.isWorking {
                    ProgressView()
                        .controlSize(.large)
                }
            }
        } else {
            ChatView()
        }
    }
}

