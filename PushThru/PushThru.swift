import SwiftUI

@main
struct PushThruApp: App {
    @State private var hasSelectedLanguage = UserPreferences.hasSelectedLanguage
    @State private var auth = AuthService.shared
    @State private var onboarding = OnboardingService.shared

    /// Pre-filled message passed from the Profile screen's "Add injury
    /// (via chat)" button down to ChatView. Lives at app scope so it
    /// survives the Settings→Profile→dismiss sequence; ChatView consumes
    /// and clears it on next appearance.
    @State private var pendingChatPrefill: String? = nil

    var body: some Scene {
        WindowGroup {
            rootView
                .preferredColorScheme(.dark)
                .onOpenURL { url in
                    AuthService.handleRedirect(url)
                }
                .onChange(of: auth.isSignedIn) { _, isSignedIn in
                    if isSignedIn {
                        Task { await onboarding.checkProfile() }
                    }
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
            switch onboarding.status {
            case .checking:
                ProgressView()
                    .controlSize(.large)
                    .task {
                        await onboarding.checkProfile()
                    }
            case .needsDOB, .underage, .checkFailed:
                DOBGateView()
            case .ready:
                ChatView(pendingPrefill: $pendingChatPrefill)
            }
        }
    }
}

