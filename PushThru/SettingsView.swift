import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var auth = AuthService.shared
    @State private var account = AccountService.shared
    @State private var showingLanguagePicker = false
    @State private var showingDeleteConfirmation = false
    @State private var showingDeleteDoubleCheck = false
    @State private var showingSignOutConfirmation = false

    /// Called when the user taps the Profile row. Parent dismisses Settings
    /// and presents the Profile sheet. Keeping navigation at the parent lets
    /// Profile → chat prefill flow stay clean (no sheet-in-sheet-in-sheet).
    let onOpenProfile: () -> Void

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    var body: some View {
        NavigationStack {
            List {
                accountSection
                preferencesSection
                legalSection
                aboutSection
                dataSection
                signOutSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .disabled(account.isDeleting)
            .overlay {
                if account.isDeleting {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    ProgressView("Deleting your account…")
                        .controlSize(.large)
                        .padding(24)
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
            .sheet(isPresented: $showingLanguagePicker) {
                LanguagePickerView { _ in
                    showingLanguagePicker = false
                }
            }
            .alert(
                "Something went wrong",
                isPresented: Binding(
                    get: { account.errorMessage != nil },
                    set: { if !$0 { account.errorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(account.errorMessage ?? "")
            }
        }
    }

    // MARK: - Account

    private var accountSection: some View {
        Section("Account") {
            Button(action: onOpenProfile) {
                HStack {
                    Text("Profile").foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary.opacity(0.5))
                }
            }

            if let email = UserPreferences.accountEmail {
                HStack {
                    Text("Email")
                    Spacer()
                    Text(email)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - Preferences

    private var preferencesSection: some View {
        Section("Preferences") {
            Button(action: { showingLanguagePicker = true }) {
                HStack {
                    Text("Language").foregroundColor(.primary)
                    Spacer()
                    Text(languageDisplayName)
                        .foregroundColor(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary.opacity(0.5))
                }
            }
        }
    }

    private var languageDisplayName: String {
        guard let code = UserPreferences.preferredLanguage else { return "Not set" }
        return Language.all.first(where: { $0.id == code })?.name ?? code
    }

    // MARK: - Legal

    private var legalSection: some View {
        Section("Legal") {
            Link(destination: URL(string: "https://pushthru.app/terms")!) {
                HStack {
                    Text("Terms of Service").foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary.opacity(0.5))
                }
            }

            Link(destination: URL(string: "https://pushthru.app/privacy")!) {
                HStack {
                    Text("Privacy Policy").foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary.opacity(0.5))
                }
            }
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        Section("About") {
            HStack {
                Text("Version")
                Spacer()
                Text(appVersion)
                    .foregroundColor(.secondary)
            }

            Link(destination: URL(string: "mailto:support@pushthru.app")!) {
                HStack {
                    Text("Contact Support").foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary.opacity(0.5))
                }
            }
        }
    }

    // MARK: - Data & Privacy

    private var dataSection: some View {
        Section("Data & Privacy") {
            Button(role: .destructive, action: { showingDeleteConfirmation = true }) {
                Text("Delete Account")
            }
            // First tap: explain what's happening.
            .alert("Delete your account?", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Continue", role: .destructive) {
                    // Chain into the second confirmation — two-tap safety
                    // for an irreversible action.
                    showingDeleteDoubleCheck = true
                }
            } message: {
                Text("This permanently removes your PushThru account, including your profile, workout history, and all conversations with Cloud. Billing records are retained anonymously for accounting. This can't be undone.")
            }
            // Second tap: the real "are you sure".
            .alert("Really delete?", isPresented: $showingDeleteDoubleCheck) {
                Button("Cancel", role: .cancel) {}
                Button("Delete My Account", role: .destructive) {
                    Task {
                        _ = await account.deleteAccount()
                        // On success, AuthService.signOut() has been called,
                        // which will route the user back to Welcome via
                        // PushThruApp. The Settings sheet dismisses itself
                        // because it was presented from ChatView, which
                        // disappears when the auth flag flips.
                    }
                }
            } message: {
                Text("Your account and all its data will be deleted immediately. Last chance to back out.")
            }
        }
    }

    // MARK: - Sign Out

    private var signOutSection: some View {
        Section {
            Button(role: .destructive, action: { showingSignOutConfirmation = true }) {
                HStack {
                    Spacer()
                    Text("Sign Out")
                    Spacer()
                }
            }
            .alert("Sign out?", isPresented: $showingSignOutConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Sign Out", role: .destructive) {
                    auth.signOut()
                    dismiss()
                }
            }
        }
    }
}

// MARK: - Local storage additions for account info

extension UserPreferences {
    private static let accountEmailKey = "pushthru.accountEmail"

    static var accountEmail: String? {
        get { UserDefaults.standard.string(forKey: accountEmailKey) }
        set { UserDefaults.standard.set(newValue, forKey: accountEmailKey) }
    }
}

#Preview {
    SettingsView(onOpenProfile: {})
        .preferredColorScheme(.dark)
}
