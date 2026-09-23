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
            
            // Cloud's text reply
            let assistantMessage = Message(
                role: .assistant,
                content: response.reply,
                timestamp: Date()
            )
            
            await MainActor.run {
                messages.append(assistantMessage)
                
                // Each card becomes its own message from Cloud
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
        
        let body = ["message": message]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ChatError.serverError
        }
        
        let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
        return decoded
    }
    
    enum ChatError: Error {
        case serverError
        case invalidResponse
    }
}

// MARK: - Server Response

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
        
        // Cards are optional; older BFFs may not include the array
        if let cardsArray = try? container.decode([Card].self, forKey: .cards) {
            cards = cardsArray.filter { $0 != .unknown }
        } else {
            cards = []
        }
    }
}
