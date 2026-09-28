import Foundation
import Observation

/// Result of checking whether the signed-in user has cleared the age gate.
enum ProfileGateStatus: Equatable {
    case checking
    case needsDOB
    case ready
    case underage
    case checkFailed
}

/// Talks to the plain REST onboarding endpoints (GET /profile,
/// POST /onboarding/dob). Deliberately separate from ChatService — this
/// never touches the LLM, so checking it costs nothing and never leaks
/// coaching-prompt behavior into a compliance decision.
@MainActor
@Observable
final class OnboardingService {
    static let shared = OnboardingService()

    #if targetEnvironment(simulator)
    private let baseURL = "http://localhost:3000"
    #else
    private let baseURL = "https://cloud-bff-prod.azurewebsites.net"
    #endif

    private(set) var status: ProfileGateStatus = .checking
    private(set) var isSubmitting = false

    private init() {}

    /// Call once after sign-in succeeds. Decides whether to show the DOB
    /// screen or let the user straight into chat.
    func checkProfile() async {
        status = .checking

        guard let token = await AuthService.shared.accessToken() else {
            status = .checkFailed
            return
        }

        do {
            var request = URLRequest(url: URL(string: "\(baseURL)/profile")!)
            request.httpMethod = "GET"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                status = .checkFailed
                return
            }

            let decoded = try JSONDecoder().decode(ProfileResponse.self, from: data)
            status = decoded.has_date_of_birth ? .ready : .needsDOB
        } catch {
            print("Profile check failed: \(error)")
            status = .checkFailed
        }
    }

    /// Submits a birthdate. Age is verified server-side — this call can
    /// come back rejecting the date even if the client-side check passed.
    func submitDateOfBirth(_ date: Date) async {
        isSubmitting = true
        defer { isSubmitting = false }

        guard let token = await AuthService.shared.accessToken() else {
            status = .checkFailed
            return
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        let dobString = formatter.string(from: date)

        do {
            var request = URLRequest(url: URL(string: "\(baseURL)/onboarding/dob")!)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.httpBody = try JSONSerialization.data(withJSONObject: ["date_of_birth": dobString])

            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                status = .checkFailed
                return
            }

            switch http.statusCode {
            case 200:
                status = .ready
            case 403:
                status = .underage
            default:
                status = .checkFailed
            }
        } catch {
            print("DOB submit failed: \(error)")
            status = .checkFailed
        }
    }
}

private struct ProfileResponse: Decodable {
    let display_name: String?
    let has_date_of_birth: Bool
}
