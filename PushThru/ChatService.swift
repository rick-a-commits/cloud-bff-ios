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

    func send(_ text: String) async {
        let userMessage = Message(role: .user, content: text, timestamp: Date())

        await MainActor.run {
            messages.append(userMessage)
            isLoading = true
        }

        do {
            let response = try await postChat(text)

            let assistantMessage = Message(
                role: .assistant,
                content: response.reply,
                timestamp: Date()
            )

            await MainActor.run {
                messages.append(assistantMessage)

                for card in response.cards {
                    let cardMessage = Message(
                        role: .assistant,
                        content: "",
                        timestamp: Date(),
                        card: card
                    )
                    messages.append(cardMessage)
                }

                isLoading = false
            }
        } catch ChatError.unauthorized {
            await MainActor.run {
                isLoading = false
            }
            // Token rejected by the BFF: return to the Welcome screen
            await AuthService.shared.signOut()
        } catch {
            let errorMessage = Message(role: .assistant, content: "Connection error. Please try again.", timestamp: Date())

            await MainActor.run {
                messages.append(errorMessage)
                isLoading = false
            }
        }
    }

    private func postChat(_ message: String) async throws -> ChatResponse {
        let url = URL(string: "\(baseURL)/chat")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Attach the Entra access token. MSAL refreshes it silently when needed.
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

