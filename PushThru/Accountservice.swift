import Foundation
import Observation

/// Thin service for account-level operations: delete.
/// Separate from AuthService (sign-in state) and ProfileService (editable
/// fields) because deletion is a one-shot, destructive action with its
/// own error-handling surface.
@MainActor
@Observable
final class AccountService {
    static let shared = AccountService()

    #if targetEnvironment(simulator)
    private let baseURL = "http://localhost:3000"
    #else
    private let baseURL = "https://cloud-bff-prod.azurewebsites.net"
    #endif

    private(set) var isDeleting = false
    var errorMessage: String?

    private init() {}

    /// Deletes the signed-in user's account on the server, then signs
    /// them out locally. Returns true if the full flow succeeded; on
    /// failure, state is unchanged — user is still signed in and can
    /// retry or dismiss.
    func deleteAccount() async -> Bool {
        isDeleting = true
        defer { isDeleting = false }

        guard let token = await AuthService.shared.accessToken() else {
            errorMessage = "You need to sign in again before deleting your account."
            return false
        }

        do {
            var request = URLRequest(url: URL(string: "\(baseURL)/account")!)
            request.httpMethod = "DELETE"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                errorMessage = "Couldn't reach PushThru. Try again in a moment."
                return false
            }

            guard http.statusCode == 200 else {
                errorMessage = "Deletion failed (code \(http.statusCode)). Please try again or contact support."
                return false
            }

            // Server-side delete succeeded. Clear local auth state. This
            // flips auth.isSignedIn to false, which bounces the user out
            // of the chat and back to the Welcome screen.
            AuthService.shared.signOut()
            return true
        } catch {
            print("Account deletion failed: \(error)")
            errorMessage = "Couldn't reach PushThru. Check your connection and try again."
            return false
        }
    }
}
