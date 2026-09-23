import Foundation

struct Message: Identifiable, Equatable {
    let id = UUID()
    let role: Role
    let content: String
    let timestamp: Date
    let card: Card?
    
    init(role: Role, content: String, timestamp: Date, card: Card? = nil) {
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.card = card
    }
    
    enum Role {
        case user
        case assistant
    }
}

// MARK: - Card Models

enum Card: Equatable, Decodable {
    case planOverview(PlanOverviewCard)
    case sessionSummary(SessionSummaryCard)
    case unknown
    
    private enum CodingKeys: String, CodingKey {
        case type
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        let single = try decoder.singleValueContainer()
        
        switch type {
        case "plan_overview":
            self = .planOverview(try single.decode(PlanOverviewCard.self))
        case "session_summary":
            self = .sessionSummary(try single.decode(SessionSummaryCard.self))
        default:
            self = .unknown
        }
    }
}

// MARK: - Plan Overview Card

struct PlanOverviewCard: Decodable, Equatable {
    let type: String
    let sessionId: String
    let title: String
    let durationMinutes: Int?
    let exercises: [PlannedExercise]
    let safetyNotes: [String]
    
    enum CodingKeys: String, CodingKey {
        case type
        case sessionId = "session_id"
        case title
        case durationMinutes = "duration_minutes"
        case exercises
        case safetyNotes = "safety_notes"
    }
}

struct PlannedExercise: Decodable, Equatable, Identifiable {
    var id: Int { order }
    let order: Int
    let name: String
    let sets: String
    let load: String?
    let note: String?
}

// MARK: - Session Summary Card

struct SessionSummaryCard: Decodable, Equatable {
    let type: String
    let sessionId: String
    let durationMinutes: Int?
    let totalSets: Int
    let totalVolumeKg: Int
    let exercises: [SummaryExercise]
    
    enum CodingKeys: String, CodingKey {
        case type
        case sessionId = "session_id"
        case durationMinutes = "duration_minutes"
        case totalSets = "total_sets"
        case totalVolumeKg = "total_volume_kg"
        case exercises
    }
}

struct SummaryExercise: Decodable, Equatable, Identifiable {
    var id: String { name }
    let name: String
    let setsCompleted: Int
    let totalReps: Int
    let topWeightKg: Double?
    
    enum CodingKeys: String, CodingKey {
        case name
        case setsCompleted = "sets_completed"
        case totalReps = "total_reps"
        case topWeightKg = "top_weight_kg"
    }
}
