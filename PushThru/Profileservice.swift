import Foundation
import Observation

/// Shape of the profile returned by GET /profile.
/// Mirrors the fields exposed by the BFF — a strict subset of what's on
/// user_profiles, filtered to what the UI actually shows and edits.
struct UserProfile: Decodable {
    var display_name: String?
    var primary_goal: String?
    var fitness_level: String?
    var injuries: [String]
    var available_equipment: [String]
    var workout_frequency_per_week: Int?
    var default_session_duration_minutes: Int?
    var goal_narrative: String?
    var workout_narrative: String?

    enum CodingKeys: String, CodingKey {
        case display_name, primary_goal, fitness_level, injuries,
             available_equipment, workout_frequency_per_week,
             default_session_duration_minutes,
             goal_narrative, workout_narrative
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        display_name = try c.decodeIfPresent(String.self, forKey: .display_name)
        primary_goal = try c.decodeIfPresent(String.self, forKey: .primary_goal)
        fitness_level = try c.decodeIfPresent(String.self, forKey: .fitness_level)
        injuries = (try? c.decode([String].self, forKey: .injuries)) ?? []
        available_equipment = (try? c.decode([String].self, forKey: .available_equipment)) ?? []
        workout_frequency_per_week = try c.decodeIfPresent(Int.self, forKey: .workout_frequency_per_week)
        default_session_duration_minutes = try c.decodeIfPresent(Int.self, forKey: .default_session_duration_minutes)
        goal_narrative = try c.decodeIfPresent(String.self, forKey: .goal_narrative)
        workout_narrative = try c.decodeIfPresent(String.self, forKey: .workout_narrative)
    }
}

/// Loads and saves the signed-in user's profile via the BFF REST endpoints.
/// Deliberately separate from OnboardingService (which only handles the DOB
/// gate check) because this is ongoing editing, not a one-time setup step.
@MainActor
@Observable
final class ProfileService {
    static let shared = ProfileService()

    #if targetEnvironment(simulator)
    private let baseURL = "http://localhost:3000"
    #else
    private let baseURL = "https://cloud-bff-prod.azurewebsites.net"
    #endif

    private(set) var profile: UserProfile?
    private(set) var isLoading = false
    private(set) var isSaving = false
    var errorMessage: String?

    private init() {}

    /// Fetches the current profile. Call on screen appear.
    func load() async {
        isLoading = true
        defer { isLoading = false }

        guard let token = await AuthService.shared.accessToken() else {
            errorMessage = "You need to sign in again."
            return
        }

        do {
            var request = URLRequest(url: URL(string: "\(baseURL)/profile")!)
            request.httpMethod = "GET"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                errorMessage = "Couldn't load your profile."
                return
            }

            profile = try JSONDecoder().decode(UserProfile.self, from: data)
        } catch {
            print("Profile load failed: \(error)")
            errorMessage = "Couldn't load your profile."
        }
    }

    /// Saves changes. Takes the same shape as the update_user_profile tool
    /// — add/remove arrays for injuries and equipment, scalars for the rest.
    /// Returns true on success so the caller can decide what to do next.
    func save(updates: [String: Any]) async -> Bool {
        isSaving = true
        defer { isSaving = false }

        guard let token = await AuthService.shared.accessToken() else {
            errorMessage = "You need to sign in again."
            return false
        }

        do {
            var request = URLRequest(url: URL(string: "\(baseURL)/profile/update")!)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.httpBody = try JSONSerialization.data(withJSONObject: updates)

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                errorMessage = "Couldn't save your changes."
                return false
            }

            if http.statusCode == 200 {
                // Refresh in-memory profile so the UI reflects what's on the server.
                await load()
                return true
            }

            // Parse the structured error the handler returns for e.g.
            // invalid enum values or injury-slug problems.
            if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errCode = obj["error"] as? String {
                errorMessage = humanize(errorCode: errCode)
            } else {
                errorMessage = "Couldn't save your changes."
            }
            return false
        } catch {
            print("Profile save failed: \(error)")
            errorMessage = "Couldn't save your changes."
            return false
        }
    }

    private func humanize(errorCode: String) -> String {
        switch errorCode {
        case "invalid_primary_goal": return "That goal isn't recognized."
        case "invalid_fitness_level": return "That fitness level isn't recognized."
        case "invalid_frequency": return "Frequency must be between 1 and 14 sessions per week."
        case "invalid_session_duration": return "Session length must be between 15 and 240 minutes."
        case "injury_not_found": return "That injury isn't on your profile."
        case "equipment_not_found": return "That equipment isn't on your profile."
        case "invalid_injury_slug": return "That injury needs more detail — please add it through chat with Cloud."
        default: return "Couldn't save your changes."
        }
    }
}

// MARK: - Static catalogs for the UI
//
// These mirror what update_user_profile accepts. Kept in iOS as display
// labels so the UI doesn't need another round-trip to render dropdowns.

enum ProfileCatalog {
    static let goals: [(id: String, label: String)] = [
        ("build_muscle", "Build muscle"),
        ("lose_fat", "Lose fat"),
        ("gain_strength", "Gain strength"),
        ("general_fitness", "General fitness"),
        ("improve_endurance", "Improve endurance"),
        ("sport_specific", "Sport-specific"),
        ("rehab", "Rehab"),
        ("maintain", "Maintain"),
    ]

    static let levels: [(id: String, label: String)] = [
        ("beginner", "Beginner"),
        ("novice", "Novice"),
        ("intermediate", "Intermediate"),
        ("advanced", "Advanced"),
        ("expert", "Expert"),
    ]

    static let equipment: [(id: String, label: String)] = [
        ("barbell", "Barbell"),
        ("dumbbells", "Dumbbells"),
        ("cable", "Cable machine"),
        ("smith_machine", "Smith machine"),
        ("leg_press", "Leg press"),
        ("pull_up_bar", "Pull-up bar"),
        ("bench", "Bench"),
        ("kettlebell", "Kettlebell"),
        ("resistance_bands", "Resistance bands"),
    ]

    static func goalLabel(for id: String?) -> String {
        guard let id else { return "Not set" }
        return goals.first(where: { $0.id == id })?.label ?? id
    }

    static func levelLabel(for id: String?) -> String {
        guard let id else { return "Not set" }
        return levels.first(where: { $0.id == id })?.label ?? id
    }

    static func equipmentLabel(for id: String) -> String {
        equipment.first(where: { $0.id == id })?.label ?? id
    }

    /// Turns an injury slug like "right_knee_sprain" into "Right knee — sprain"
    /// for display. Keeps the raw slug underneath for removal operations.
    static func injuryLabel(for slug: String) -> String {
        let parts = slug.split(separator: "_").map(String.init)
        guard parts.count >= 2 else { return slug.replacingOccurrences(of: "_", with: " ").capitalized }

        let firstIsSide = parts[0] == "left" || parts[0] == "right" || parts[0] == "both"
        if firstIsSide, parts.count >= 3 {
            let side = parts[0].capitalized
            let body = parts[1].capitalized
            let type = parts[2...].joined(separator: " ")
            return "\(side) \(body) — \(type)"
        }

        let body = parts[0].capitalized
        let type = parts[1...].joined(separator: " ")
        return "\(body) — \(type)"
    }
}
