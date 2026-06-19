import SwiftUI

struct AddTaskView: View {
    @EnvironmentObject var scheduleStore: ScheduleStore
    @Environment(\.dismiss) var dismiss

    @State private var title: String
    @State private var notes = ""
    @State private var priority: KTask.Priority = .medium
    @State private var category: KTask.TaskCategory
    @State private var dueDate = Date()
    @State private var hasDueDate = true
    @State private var hasDueTime = false
    @State private var tags: [String] = []
    @State private var newTag = ""

    private let accent = KTheme.Colors.accentTertiary

    init(initialTitle: String = "", initialCategory: KTask.TaskCategory = .general) {
        _title = State(initialValue: initialTitle)
        _category = State(initialValue: initialCategory)
    }

    var body: some View {
        NavigationView {
            ZStack {
                KTheme.Colors.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: KTheme.Spacing.lg) {

                        // Task name input
                        inputSection(label: "TASK NAME") {
                            KTextField(placeholder: "Task name", text: $title, icon: "pencil")
                        }

                        // Notes input
                        inputSection(label: "NOTES") {
                            KTextField(placeholder: "Notes (optional)", text: $notes, icon: "note.text")
                        }

                        // Priority
                        inputSection(label: "PRIORITY") {
                            HStack(spacing: KTheme.Spacing.sm) {
                                ForEach(KTask.Priority.allCases, id: \.self) { p in
                                    Button {
                                        priority = p
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: p.icon).font(.caption)
                                            Text(p.displayName)
                                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                                .tracking(0.5)
                                        }
                                        .foregroundColor(priority == p ? .white : Color(hex: p.color))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 7)
                                        .background(priorityBg(p: p))
                                        .cornerRadius(KTheme.Radius.sm)
                                    }
                                }
                            }
                        }

                        // Category
                        inputSection(label: "CATEGORY") {
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: KTheme.Spacing.sm) {
                                ForEach(KTask.TaskCategory.allCases, id: \.self) { cat in
                                    Button {
                                        category = cat
                                    } label: {
                                        VStack(spacing: 4) {
                                            Image(systemName: cat.icon)
                                                .font(.system(size: 18))
                                                .foregroundColor(category == cat ? accent : KTheme.Colors.textSecondary)
                                            Text(cat.rawValue.uppercased())
                                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                                .foregroundColor(category == cat ? accent : KTheme.Colors.textTertiary)
                                                .tracking(0.5)
                                                .lineLimit(1)
                                                .minimumScaleFactor(0.7)
                                        }
                                        .padding(KTheme.Spacing.sm)
                                        .frame(maxWidth: .infinity)
                                        .background(categoryBg(cat: cat))
                                        .cornerRadius(KTheme.Radius.sm)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: KTheme.Radius.sm)
                                                .stroke(category == cat ? accent.opacity(0.4) : Color.clear, lineWidth: 0.5)
                                        )
                                    }
                                }
                            }
                        }

                        // Tags
                        inputSection(label: "TAGS") {
                            VStack(alignment: .leading, spacing: KTheme.Spacing.sm) {
                                if !tags.isEmpty {
                                    FlowLayout(spacing: KTheme.Spacing.xs) {
                                        ForEach(tags, id: \.self) { tag in
                                            HStack(spacing: 4) {
                                                Text(tag)
                                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                                    .foregroundColor(accent)
                                                    .tracking(0.5)
                                                Button {
                                                    tags.removeAll { $0 == tag }
                                                } label: {
                                                    Image(systemName: "xmark")
                                                        .font(.system(size: 10, weight: .bold))
                                                        .foregroundColor(accent)
                                                }
                                            }
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(accent.opacity(0.1))
                                            .cornerRadius(KTheme.Radius.pill)
                                        }
                                    }
                                }
                                HStack {
                                    TextField("Add a tag...", text: $newTag)
                                        .foregroundColor(KTheme.Colors.textPrimary)
                                        .font(KTheme.Typography.bodyMedium)
                                        .onSubmit { addTag() }
                                    Button("ADD") {
                                        addTag()
                                    }
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundColor(accent)
                                    .tracking(1)
                                    .disabled(newTag.trimmingCharacters(in: .whitespaces).isEmpty)
                                }
                            }
                        }

                        // Due date
                        inputSection(label: "DUE DATE") {
                            VStack(spacing: KTheme.Spacing.sm) {
                                Toggle(isOn: $hasDueDate) {
                                    Label("Set Due Date", systemImage: "calendar")
                                        .foregroundColor(KTheme.Colors.textPrimary)
                                        .font(KTheme.Typography.headingSmall)
                                }.tint(accent)

                                if hasDueDate {
                                    DatePicker("", selection: $dueDate, displayedComponents: hasDueTime ? [.date, .hourAndMinute] : .date)
                                        .colorScheme(.dark)
                                        .labelsHidden()
                                    Toggle(isOn: $hasDueTime) {
                                        Text("INCLUDE TIME")
                                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                                            .foregroundColor(KTheme.Colors.textSecondary)
                                            .tracking(1)
                                    }.tint(accent)
                                }
                            }
                        }

                        KButton(title: "Create Task") {
                            var task = KTask(title: title, notes: notes.isEmpty ? nil : notes, priority: priority, category: category)
                            if hasDueDate { task.dueDate = dueDate }
                            task.tags = tags
                            scheduleStore.addTask(task)
                            dismiss()
                        }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                        .padding(.bottom, KTheme.Spacing.xxl)
                    }
                    .padding(KTheme.Spacing.md)
                }
            }
            .navigationTitle("New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundColor(KTheme.Colors.textSecondary)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: Helpers

    private func priorityBg(p: KTask.Priority) -> Color {
        priority == p ? Color(hex: p.color) : Color(hex: p.color).opacity(0.1)
    }

    private func categoryBg(cat: KTask.TaskCategory) -> Color {
        category == cat ? accent.opacity(0.12) : KTheme.Colors.border.opacity(0.3)
    }

    @ViewBuilder
    private func inputSection<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: KTheme.Spacing.sm) {
            Text(label)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(accent.opacity(0.8))
                .tracking(1.5)
            KCard {
                content()
            }
        }
    }

    private func addTag() {
        let trimmed = newTag.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !tags.contains(trimmed) else { return }
        tags.append(trimmed)
        newTag = ""
    }
}

struct AddHabitView: View {
    @EnvironmentObject var scheduleStore: ScheduleStore
    @Environment(\.dismiss) var dismiss

    @State private var title = ""
    @State private var icon = "star.fill"
    @State private var color = "7C6FFF"
    @State private var category: Habit.HabitCategory = .fitness
    @State private var frequency: Habit.Frequency = .daily

    private let accent = KTheme.Colors.accentTertiary

    let iconOptions = ["flame.fill", "figure.run", "drop.fill", "leaf.fill", "moon.fill", "brain.head.profile", "heart.fill", "dumbbell.fill", "book.fill", "fork.knife", "scalemass.fill", "figure.flexibility"]
    let colorOptions = ["7C6FFF", "FF6B8A", "4ECDC4", "FFB347", "FF2D55", "34C759", "5AC8FA", "AF52DE"]

    var body: some View {
        NavigationView {
            ZStack {
                KTheme.Colors.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: KTheme.Spacing.lg) {

                        // Preview — glow border card
                        KCard(elevated: true) {
                            HStack {
                                ZStack {
                                    Circle().fill(Color(hex: color)).frame(width: 52, height: 52)
                                    Image(systemName: icon).foregroundColor(.white).font(.system(size: 22))
                                }
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(title.isEmpty ? "Habit Name" : title)
                                        .font(KTheme.Typography.headingMedium)
                                        .foregroundColor(KTheme.Colors.textPrimary)
                                    Text(frequency.displayName.uppercased())
                                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                                        .foregroundColor(KTheme.Colors.textSecondary)
                                        .tracking(1.2)
                                }
                                Spacer()
                            }
                        }

                        KTextField(placeholder: "Habit name", text: $title, icon: "pencil")

                        // Icon picker
                        habitInputSection(label: "ICON") {
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: KTheme.Spacing.sm) {
                                ForEach(iconOptions, id: \.self) { i in
                                    Button { icon = i } label: {
                                        Image(systemName: i)
                                            .font(.system(size: 20))
                                            .foregroundColor(icon == i ? .white : KTheme.Colors.textSecondary)
                                            .frame(width: 40, height: 40)
                                            .background(icon == i ? Color(hex: color) : KTheme.Colors.border.opacity(0.3))
                                            .cornerRadius(KTheme.Radius.sm)
                                    }
                                }
                            }
                        }

                        // Color picker
                        habitInputSection(label: "COLOR") {
                            HStack(spacing: KTheme.Spacing.sm) {
                                ForEach(colorOptions, id: \.self) { c in
                                    Button { color = c } label: {
                                        ZStack {
                                            Circle().fill(Color(hex: c)).frame(width: 32, height: 32)
                                            if color == c {
                                                Circle().stroke(Color.white, lineWidth: 2).frame(width: 36, height: 36)
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Frequency
                        habitInputSection(label: "FREQUENCY") {
                            ForEach(Habit.Frequency.allCases, id: \.self) { f in
                                Button { frequency = f } label: {
                                    HStack {
                                        Text(f.displayName)
                                            .font(KTheme.Typography.bodyMedium)
                                            .foregroundColor(KTheme.Colors.textPrimary)
                                        Spacer()
                                        if frequency == f {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(accent)
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }

                        KButton(title: "Create Habit") {
                            let habit = Habit(title: title, icon: icon, color: color, category: category, frequency: frequency)
                            scheduleStore.addHabit(habit)
                            dismiss()
                        }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                        .padding(.bottom, KTheme.Spacing.xxl)
                    }
                    .padding(KTheme.Spacing.md)
                }
            }
            .navigationTitle("New Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundColor(KTheme.Colors.textSecondary)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func habitInputSection<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: KTheme.Spacing.sm) {
            Text(label)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(accent.opacity(0.8))
                .tracking(1.5)
            KCard {
                content()
            }
        }
    }
}
