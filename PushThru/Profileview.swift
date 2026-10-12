import SwiftUI

/// Full-screen profile viewer and editor.
///
/// Reads from GET /profile on appear, writes field edits through
/// POST /profile/update (both via ProfileService).
///
/// Design decisions:
/// - Scalars edit inline (sheets with pickers) and save individually.
///   Keeps each save small, roundtrips are the natural "did it stick" check.
/// - Injuries are display + remove only. "Add injury" opens chat with a
///   pre-filled message so Cloud can ask for side + cause.
/// - Equipment uses a known checklist — multi-select, saved as one call.
/// - Narratives are read-only (Cloud maintains them conversationally).
struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var profile = ProfileService.shared
    @State private var showingNameEditor = false
    @State private var showingGoalPicker = false
    @State private var showingLevelPicker = false
    @State private var showingFrequencyEditor = false
    @State private var showingDurationEditor = false
    @State private var showingEquipmentEditor = false

    /// When set, triggers navigation to chat with this message pre-filled.
    /// Observed by whatever presents ProfileView.
    @Binding var prefillChatMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if profile.isLoading && profile.profile == nil {
                    ProgressView().controlSize(.large)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let p = profile.profile {
                    List {
                        accountSection(p)
                        goalsSection(p)
                        trainingSection(p)
                        injuriesSection(p)
                        equipmentSection(p)
                        narrativeSection(p)
                    }
                    .listStyle(.insetGrouped)
                } else {
                    retryView
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .task { await profile.load() }
            .alert(
                "Something went wrong",
                isPresented: Binding(
                    get: { profile.errorMessage != nil },
                    set: { if !$0 { profile.errorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(profile.errorMessage ?? "")
            }
            .sheet(isPresented: $showingNameEditor) {
                NameEditor(current: profile.profile?.display_name ?? "")
            }
            .sheet(isPresented: $showingGoalPicker) {
                EnumPicker(
                    title: "Primary goal",
                    options: ProfileCatalog.goals,
                    selected: profile.profile?.primary_goal,
                    onPick: { id in
                        Task { _ = await profile.save(updates: ["primary_goal": id]) }
                    }
                )
            }
            .sheet(isPresented: $showingLevelPicker) {
                EnumPicker(
                    title: "Fitness level",
                    options: ProfileCatalog.levels,
                    selected: profile.profile?.fitness_level,
                    onPick: { id in
                        Task { _ = await profile.save(updates: ["fitness_level": id]) }
                    }
                )
            }
            .sheet(isPresented: $showingFrequencyEditor) {
                IntStepperEditor(
                    title: "Sessions per week",
                    current: profile.profile?.workout_frequency_per_week ?? 3,
                    range: 1...14,
                    unit: "sessions",
                    onSave: { n in
                        Task { _ = await profile.save(updates: ["workout_frequency_per_week": n]) }
                    }
                )
            }
            .sheet(isPresented: $showingDurationEditor) {
                IntStepperEditor(
                    title: "Default session length",
                    current: profile.profile?.default_session_duration_minutes ?? 60,
                    range: 15...240,
                    step: 5,
                    unit: "minutes",
                    onSave: { n in
                        Task { _ = await profile.save(updates: ["default_session_duration_minutes": n]) }
                    }
                )
            }
            .sheet(isPresented: $showingEquipmentEditor) {
                EquipmentEditor(
                    current: profile.profile?.available_equipment ?? [],
                    onSave: { added, removed in
                        var updates: [String: Any] = [:]
                        if !added.isEmpty { updates["available_equipment_add"] = added }
                        if !removed.isEmpty { updates["available_equipment_remove"] = removed }
                        guard !updates.isEmpty else { return }
                        Task { _ = await profile.save(updates: updates) }
                    }
                )
            }
        }
    }

    // MARK: - Sections

    private func accountSection(_ p: UserProfile) -> some View {
        Section("Account") {
            Button(action: { showingNameEditor = true }) {
                row(label: "Name", value: p.display_name ?? "Not set")
            }
        }
    }

    private func goalsSection(_ p: UserProfile) -> some View {
        Section("Goals") {
            Button(action: { showingGoalPicker = true }) {
                row(label: "Primary goal", value: ProfileCatalog.goalLabel(for: p.primary_goal))
            }
            Button(action: { showingLevelPicker = true }) {
                row(label: "Fitness level", value: ProfileCatalog.levelLabel(for: p.fitness_level))
            }
        }
    }

    private func trainingSection(_ p: UserProfile) -> some View {
        Section("Training") {
            Button(action: { showingFrequencyEditor = true }) {
                row(label: "Sessions / week", value: p.workout_frequency_per_week.map(String.init) ?? "Not set")
            }
            Button(action: { showingDurationEditor = true }) {
                row(
                    label: "Session length",
                    value: p.default_session_duration_minutes.map { "\($0) min" } ?? "Not set"
                )
            }
        }
    }

    private func injuriesSection(_ p: UserProfile) -> some View {
        Section {
            if p.injuries.isEmpty {
                Text("No injuries on file")
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                ForEach(p.injuries, id: \.self) { slug in
                    HStack {
                        Text(ProfileCatalog.injuryLabel(for: slug))
                        Spacer()
                        Button(role: .destructive) {
                            Task {
                                _ = await profile.save(updates: ["injuries_remove": [slug]])
                            }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(.red)
                        }
                    }
                }
            }

            Button(action: {
                // Open chat with a pre-filled message so Cloud can ask
                // for side + cause before saving — preserves slug quality.
                prefillChatMessage = "I want to add a new injury — can you ask me what it is?"
                dismiss()
            }) {
                Label("Add injury (via chat)", systemImage: "plus")
                    .foregroundColor(Color(hex: "6C63FF"))
            }
        } header: {
            Text("Injuries & restrictions")
        } footer: {
            Text("New injuries go through Cloud so it can ask the right questions about side and cause.")
                .font(.caption)
        }
    }

    private func equipmentSection(_ p: UserProfile) -> some View {
        Section("Equipment") {
            if p.available_equipment.isEmpty {
                Text("No equipment on file")
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                ForEach(p.available_equipment, id: \.self) { slug in
                    Text(ProfileCatalog.equipmentLabel(for: slug))
                }
            }
            Button(action: { showingEquipmentEditor = true }) {
                Label("Edit equipment", systemImage: "pencil")
                    .foregroundColor(Color(hex: "6C63FF"))
            }
        }
    }

    @ViewBuilder
    private func narrativeSection(_ p: UserProfile) -> some View {
        if (p.goal_narrative?.isEmpty ?? true) && (p.workout_narrative?.isEmpty ?? true) {
            EmptyView()
        } else {
            Section {
                if let goal = p.goal_narrative, !goal.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Goal context").font(.caption).foregroundColor(.secondary)
                        Text(goal).font(.callout)
                    }
                }
                if let workout = p.workout_narrative, !workout.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Training context").font(.caption).foregroundColor(.secondary)
                        Text(workout).font(.callout)
                    }
                }
            } header: {
                Text("What Cloud knows")
            } footer: {
                Text("Cloud writes these as you chat. To update them, just tell Cloud in chat.")
                    .font(.caption)
            }
        }
    }

    private var retryView: some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 36))
                .foregroundColor(.secondary)
            Text("Couldn't load your profile")
                .font(.headline)
            Button("Try again") {
                Task { await profile.load() }
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(hex: "6C63FF"))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func row(label: String, value: String) -> some View {
        HStack {
            Text(label).foregroundColor(.primary)
            Spacer()
            Text(value).foregroundColor(.secondary)
            Image(systemName: "chevron.right")
                .font(.system(size: 13))
                .foregroundColor(.secondary.opacity(0.5))
        }
    }
}

// MARK: - Supporting sheets

private struct NameEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var profile = ProfileService.shared
    @State private var text: String
    let current: String

    init(current: String) {
        self.current = current
        self._text = State(initialValue: current)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Your name", text: $text)
                    .textContentType(.name)
            }
            .navigationTitle("Name")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty, trimmed != current else {
                            dismiss(); return
                        }
                        Task {
                            _ = await profile.save(updates: ["display_name": trimmed])
                            dismiss()
                        }
                    }
                    .disabled(profile.isSaving)
                }
            }
        }
    }
}

private struct EnumPicker: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let options: [(id: String, label: String)]
    let selected: String?
    let onPick: (String) -> Void

    var body: some View {
        NavigationStack {
            List {
                ForEach(options, id: \.id) { option in
                    Button(action: {
                        onPick(option.id)
                        dismiss()
                    }) {
                        HStack {
                            Text(option.label).foregroundColor(.primary)
                            Spacer()
                            if option.id == selected {
                                Image(systemName: "checkmark")
                                    .foregroundColor(Color(hex: "6C63FF"))
                            }
                        }
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

private struct IntStepperEditor: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    @State var current: Int
    let range: ClosedRange<Int>
    var step: Int = 1
    let unit: String
    let onSave: (Int) -> Void

    var body: some View {
        NavigationStack {
            Form {
                HStack {
                    Text("\(current)")
                        .font(.largeTitle)
                        .fontDesign(.rounded)
                        .fontWeight(.semibold)
                    Text(unit).foregroundColor(.secondary)
                    Spacer()
                    Stepper("", value: $current, in: range, step: step)
                        .labelsHidden()
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        onSave(current)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.height(260)])
    }
}

private struct EquipmentEditor: View {
    @Environment(\.dismiss) private var dismiss
    let current: [String]
    let onSave: (_ added: [String], _ removed: [String]) -> Void

    @State private var selected: Set<String> = []

    var body: some View {
        NavigationStack {
            List(ProfileCatalog.equipment, id: \.id) { item in
                Button(action: { toggle(item.id) }) {
                    HStack {
                        Text(item.label).foregroundColor(.primary)
                        Spacer()
                        if selected.contains(item.id) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(Color(hex: "6C63FF"))
                        } else {
                            Image(systemName: "circle")
                                .foregroundColor(.secondary.opacity(0.4))
                        }
                    }
                }
            }
            .navigationTitle("Equipment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        let before = Set(current)
                        let added = Array(selected.subtracting(before))
                        let removed = Array(before.subtracting(selected))
                        onSave(added, removed)
                        dismiss()
                    }
                }
            }
            .onAppear { selected = Set(current) }
        }
    }

    private func toggle(_ id: String) {
        if selected.contains(id) { selected.remove(id) } else { selected.insert(id) }
    }
}
