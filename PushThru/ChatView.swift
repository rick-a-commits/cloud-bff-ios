import SwiftUI
import Combine

struct ChatView: View {
    @State private var chatService = ChatService()
    @State private var inputText = ""
    @State private var showingSettings = false
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            header
            
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(chatService.messages) { message in
                            MessageRow(message: message)
                                .id(message.id)
                        }
                        
                        if chatService.isLoading {
                            HStack {
                                TypingIndicator()
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .id("loading")
                        }
                    }
                    .padding(.vertical, 12)
                }
                .onChange(of: chatService.messages.count) {
                    withAnimation {
                        if let lastMessage = chatService.messages.last {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: chatService.isLoading) {
                    if chatService.isLoading {
                        withAnimation {
                            proxy.scrollTo("loading", anchor: .bottom)
                        }
                    }
                }
            }
            
            inputBar
        }
        .background(Color(.systemBackground))
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
    }
    
    private var header: some View {
        HStack(spacing: 10) {
            Image("PushThruLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 36, height: 36)
            
            VStack(alignment: .leading, spacing: 1) {
                Text("PushThru").font(.headline).foregroundColor(.primary)
                Text("Your training partner").font(.caption2).foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: { showingSettings = true }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 18))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .overlay(Divider(), alignment: .bottom)
    }
    
    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField("Message PushThru...", text: $inputText)
                .textFieldStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(.secondarySystemBackground))
                .clipShape(Capsule())
                .focused($isInputFocused)
                .onSubmit { sendMessage() }
            
            Button(action: sendMessage) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle().fill(inputText.isEmpty ? Color.gray : Color(hex: "6C63FF"))
                    )
            }
            .disabled(inputText.isEmpty || chatService.isLoading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(.systemBackground))
        .overlay(Divider(), alignment: .top)
    }
    
    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""
        Task { await chatService.send(text) }
    }
}

// MARK: - Message Row (routes to text bubble or card view)

struct MessageRow: View {
    let message: Message
    
    var body: some View {
        if let card = message.card {
            HStack {
                CardView(card: card)
                    .padding(.leading, 40)
                    .padding(.trailing, 16)
                Spacer(minLength: 0)
            }
        } else if !message.content.isEmpty {
            MessageBubble(message: message)
        }
    }
}

// MARK: - Text Bubble

struct MessageBubble: View {
    let message: Message
    
    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 60) }
            
            Text(message.content)
                .font(.body)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    message.role == .user
                        ? Color(hex: "6C63FF")
                        : Color(.secondarySystemBackground)
                )
                .foregroundColor(message.role == .user ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            
            if message.role == .assistant { Spacer(minLength: 60) }
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Card View (routes to specific card renderers)

struct CardView: View {
    let card: Card
    
    var body: some View {
        switch card {
        case .planOverview(let plan):
            PlanOverviewCardView(plan: plan)
        case .sessionSummary(let summary):
            SessionSummaryCardView(summary: summary)
        case .unknown:
            EmptyView()
        }
    }
}

// MARK: - Plan Overview Card

struct PlanOverviewCardView: View {
    let plan: PlanOverviewCard
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color(hex: "6C63FF"))
                    .frame(width: 8, height: 8)
                Text(plan.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
                Spacer()
                if let duration = plan.durationMinutes {
                    Text("~\(duration) min")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            
            VStack(spacing: 8) {
                ForEach(plan.exercises) { exercise in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(exercise.order)")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .frame(width: 12, alignment: .trailing)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(exercise.name)
                                .font(.system(size: 13))
                                .foregroundColor(.primary)
                            if let note = exercise.note {
                                Text(note)
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        Text(loadText(for: exercise))
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            if !plan.safetyNotes.isEmpty {
                Divider()
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(Color(hex: "48B4E0"))
                    Text(plan.safetyNotes.joined(separator: " · "))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func loadText(for exercise: PlannedExercise) -> String {
        if let load = exercise.load {
            return "\(exercise.sets) · \(load)"
        }
        return exercise.sets
    }
}

// MARK: - Session Summary Card

struct SessionSummaryCardView: View {
    let summary: SessionSummaryCard
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "66BB6A"))
                Text("Session complete")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(hex: "66BB6A"))
                Spacer()
                if let duration = summary.durationMinutes {
                    Text("\(duration) min")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            
            VStack(spacing: 6) {
                ForEach(summary.exercises) { exercise in
                    HStack {
                        Text(exercise.name)
                            .font(.system(size: 13))
                            .foregroundColor(.primary)
                        Spacer()
                        Text(setsText(for: exercise))
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Divider()
            
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sets").font(.system(size: 10)).foregroundColor(.secondary)
                    Text("\(summary.totalSets)").font(.system(size: 15, weight: .semibold))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Volume").font(.system(size: 10)).foregroundColor(.secondary)
                    Text("\(summary.totalVolumeKg) kg").font(.system(size: 15, weight: .semibold))
                }
                Spacer()
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func setsText(for exercise: SummaryExercise) -> String {
        if let weight = exercise.topWeightKg, weight > 0 {
            return "\(exercise.setsCompleted) sets @ \(formatWeight(weight))"
        }
        return "\(exercise.setsCompleted) sets"
    }
    
    private func formatWeight(_ weight: Double) -> String {
        if weight == weight.rounded() {
            return "\(Int(weight))kg"
        }
        return String(format: "%.1fkg", weight)
    }
}

// MARK: - Typing Indicator

struct TypingIndicator: View {
    @State private var dotCount = 0
    let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.secondary)
                    .frame(width: 7, height: 7)
                    .opacity(dotCount % 3 == index ? 1.0 : 0.3)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .onReceive(timer) { _ in
            dotCount += 1
        }
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
