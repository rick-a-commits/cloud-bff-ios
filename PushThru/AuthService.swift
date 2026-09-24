import Foundation
import UIKit
import Observation
import MSAL

/// Handles sign-in with Entra External ID via MSAL.
///
/// - Interactive sign-in / sign-up opens the hosted Entra page (signupsignin1 flow).
/// - Access tokens are cached in the Keychain by MSAL and refreshed silently.
/// - The BFF validates these tokens (audience = client ID).
@MainActor
@Observable
final class AuthService {
    static let shared = AuthService()

    // Entra External ID configuration (public identifiers, not secrets)
    private let clientId = "8b36e1d4-0668-436f-8e11-3c04df373d81"
    private let redirectUri = "msauth.com.pushthru.PushThru://auth"
    private let authorityURL = "https://cloudusers.ciamlogin.com"
    private let scopes = ["api://8b36e1d4-0668-436f-8e11-3c04df373d81/access"]

    private var application: MSALPublicClientApplication?

    private(set) var isSignedIn = false
    private(set) var isWorking = false
    var errorMessage: String?

    private init() {
        do {
            let authority = try MSALCIAMAuthority(url: URL(string: authorityURL)!)
            let config = MSALPublicClientApplicationConfig(
                clientId: clientId,
                redirectUri: redirectUri,
                authority: authority
            )
            application = try MSALPublicClientApplication(configuration: config)
            isSignedIn = currentAccount() != nil
        } catch {
            print("MSAL init failed: \(error)")
            errorMessage = "Sign-in is unavailable right now. Please try again later."
        }
    }

    // MARK: - Public API

    /// Opens the Entra hosted page on the sign-in view.
    func signIn() async {
        await authenticate(extraQueryParameters: nil)
    }

    /// Opens the Entra hosted page directly on the sign-up view, skipping
    /// the "No account? Create one" link. Entra's CIAM user flows honor
    /// prompt=create for this.
    func createAccount() async {
        await authenticate(extraQueryParameters: ["prompt": "create"])
    }

    private func authenticate(extraQueryParameters: [String: String]?) async {
        guard let application else { return }
        guard let presenter = Self.topViewController() else {
            errorMessage = "Couldn't open the sign-in page."
            return
        }

        isWorking = true
        defer { isWorking = false }

        let webParams = MSALWebviewParameters(authPresentationViewController: presenter)
        let params = MSALInteractiveTokenParameters(scopes: scopes, webviewParameters: webParams)
        params.promptType = .selectAccount
        if let extraQueryParameters {
            params.extraQueryParameters = extraQueryParameters
        }

        do {
            _ = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<String, Error>) in
                application.acquireToken(with: params) { result, error in
                    if let token = result?.accessToken {
                        cont.resume(returning: token)
                    } else {
                        cont.resume(throwing: error ?? AuthError.unknown)
                    }
                }
            }
            isSignedIn = true
        } catch {
            let ns = error as NSError
            // User tapped Cancel on the sign-in page: not an error worth showing
            if ns.domain == MSALErrorDomain && ns.code == MSALError.userCanceled.rawValue {
                return
            }
            print("Interactive auth failed: \(error)")
            errorMessage = "Sign-in failed. Please try again."
        }
    }

    /// Returns a valid access token, refreshing silently if needed.
    /// Returns nil (and signs the user out) if the session can't be renewed.
    func accessToken() async -> String? {
        guard let application, let account = currentAccount() else {
            isSignedIn = false
            return nil
        }

        let params = MSALSilentTokenParameters(scopes: scopes, account: account)

        do {
            return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<String, Error>) in
                application.acquireTokenSilent(with: params) { result, error in
                    if let token = result?.accessToken {
                        cont.resume(returning: token)
                    } else {
                        cont.resume(throwing: error ?? AuthError.unknown)
                    }
                }
            }
        } catch {
            let ns = error as NSError
            print("Silent token failed: \(error)")
            if ns.domain == MSALErrorDomain && ns.code == MSALError.interactionRequired.rawValue {
                // Refresh token expired or revoked: send the user back to Welcome
                signOut()
            }
            return nil
        }
    }

    /// Removes the cached account locally. The user will see the Welcome screen.
    func signOut() {
        if let application, let account = currentAccount() {
            try? application.remove(account)
        }
        isSignedIn = false
    }

    /// Passes redirect URLs (e.g. from Microsoft Authenticator) back to MSAL.
    static func handleRedirect(_ url: URL) {
        _ = MSALPublicClientApplication.handleMSALResponse(url, sourceApplication: nil)
    }

    // MARK: - Helpers

    private func currentAccount() -> MSALAccount? {
        guard let application else { return nil }
        return (try? application.allAccounts())?.first
    }

    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        var top = scene?.keyWindow?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }

    enum AuthError: Error {
        case unknown
    }
}

