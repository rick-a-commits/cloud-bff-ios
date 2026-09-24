import Foundation
import Observation

@Observable
class ChatService {
    #if targetEnvironment(simulator)
    private let baseURL = "http://localhost:3000"
    #else
    private let baseURL = "https://cloud-bff-prod.azurewebsites.net"
    #endif

    var messages: [Message] = []
    var isLoading = false

    /// Sentinel the BFF recognizes as "the app just opened, greet the user" —
    /// never shown as a message bubble and never stored as a real user turn.
    private static let greetingTrigger = "__init__"

    func send(_ text: String) async {
        let userMessage = Message(role: .user, content: text, timestamp: Date())

        await MainActor.run {
            messages.append(userMessage)
            isLoading = true
        }

        do {
            let response = try await postChat(text)
            await appendResponse(response)
        } catch ChatError.unauthorized {
            await MainActor.run { isLoading = false }
            await AuthService.shared.signOut()
        } catch {
            let errorMessage = Message(role: .assistant, content: "Connection error. Please try again.", timestamp: Date())
            await MainActor.run {
                messages.append(errorMessage)
                isLoading = false
            }
        }
    }

    /// Fires once when the chat opens with no history, so Cloud greets the
    /// user proactively instead of showing a blank screen until they type.
    /// No user bubble appears for this — only Cloud's reply (and any cards).
    func requestGreeting() async {
        guard messages.isEmpty else { return }

        await MainActor.run { isLoading = true }

        do {
            let response = try await postChat(Self.greetingTrigger)
            await appendResponse(response)
        } catch {
            // Silent failure: worst case the user just sees the empty state
            // and types first, same as before this feature existed.
            await MainActor.run { isLoading = false }
        }
    }

    @MainActor
    private func appendResponse(_ response: ChatResponse) {
        if !response.reply.isEmpty {
            messages.append(Message(role: .assistant, content: response.reply, timestamp: Date()))
        }
        for card in response.cards {
            messages.append(Message(role: .assistant, content: "", timestamp: Date(), card: card))
        }
        isLoading = false
    }

    private func postChat(_ message: String) async throws -> ChatResponse {
        let url = URL(string: "\(baseURL)/chat")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        guard let token = await AuthService.shared.accessToken() else {
            throw ChatError.unauthorized
        }
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        var body: [String: Any] = ["message": message]
        if let language = UserPreferences.preferredLanguage {
            body["language"] = language
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ChatError.serverError
        }
        if httpResponse.statusCode == 401 {
            throw ChatError.unauthorized
        }
        guard httpResponse.statusCode == 200 else {
            throw ChatError.serverError
        }

        return try JSONDecoder().decode(ChatResponse.self, from: data)
    }

    enum ChatError: Error {
        case serverError
        case invalidResponse
        case unauthorized
    }
}

private struct ChatResponse: Decodable {
    let reply: String
    let cards: [Card]

    enum CodingKeys: String, CodingKey {
        case reply
        case cards
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        reply = try container.decode(String.self, forKey: .reply)

        if let cardsArray = try? container.decode([Card].self, forKey: .cards) {
            cards = cardsArray.filter { $0 != .unknown }
        } else {
            cards = []
        }
    }
}
