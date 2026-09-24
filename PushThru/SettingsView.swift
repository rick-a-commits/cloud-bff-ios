import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var auth = AuthService.shared
    @State private var showingLanguagePicker = false
    @State private var showingDeleteConfirmation = false
    @State private var showingSignOutConfirmation = false
    
    // Display name and email are read from the account. For now, name is
    // editable locally only — persisting it to the backend happens once
    // the update_user_profile tool exists.
    @State private var displayName: String = UserPreferences.displayName ?? ""
    
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
            .sheet(isPresented: $showingLanguagePicker) {
                LanguagePickerView { _ in
                    showingLanguagePicker = false
                }
            }
        }
    }
    
    // MARK: - Account
    
    private var accountSection: some View {
        Section("Account") {
            HStack {
                Text("Name")
                Spacer()
                TextField("Your name", text: $displayName)
                    .multilineTextAlignment(.trailing)
                    .foregroundColor(.secondary)
                    .onSubmit {
                        UserPreferences.displayName = displayName
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
            
            // Appearance (Light/Dark/System) and Units (kg/lb) land here later.
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
            .alert("Delete your account?", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    // Backend deletion endpoint doesn't exist yet.
                    // For now this only signs the user out locally.
                    // TODO: call DELETE /account on the BFF once built, then sign out.
                    auth.signOut()
                }
            } message: {
                Text("This permanently deletes your PushThru account and all your data, including workout history. This can't be undone.")
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
    private static let displayNameKey = "pushthru.displayName"
    private static let accountEmailKey = "pushthru.accountEmail"
    
    static var displayName: String? {
        get { UserDefaults.standard.string(forKey: displayNameKey) }
        set { UserDefaults.standard.set(newValue, forKey: displayNameKey) }
    }
    
    static var accountEmail: String? {
        get { UserDefaults.standard.string(forKey: accountEmailKey) }
        set { UserDefaults.standard.set(newValue, forKey: accountEmailKey) }
    }
}

#Preview {
    SettingsView()
        .preferredColorScheme(.dark)
}
