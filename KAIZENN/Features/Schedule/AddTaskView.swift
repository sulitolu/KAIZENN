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

                        KTextField(placeholder: "Task name", text: $title, icon: "pencil")

                        KTextField(placeholder: "Notes (optional)", text: $notes, icon: "note.text")

                        // Priority
                        KCard {
                            VStack(alignment: .leading, spacing: KTheme.Spacing.sm) {
                                Text("Priority").font(KTheme.Typography.headingSmall).foregroundColor(KTheme.Colors.textPrimary)
                                HStack(spacing: KTheme.Spacing.sm) {
                                    ForEach(KTask.Priority.allCases, id: \.self) { p in
                                        Button {
                                            priority = p
                                        } label: {
                                            HStack(spacing: 4) {
                                                Image(systemName: p.icon).font(.caption)
                                                Text(p.displayName).font(KTheme.Typography.label)
                                            }
                                            .foregroundColor(priority == p ? .white : Color(hex: p.color))
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 7)
                                            .background(priority == p ? Color(hex: p.color) : Color(hex: p.color).opacity(0.1))
                                            .cornerRadius(KTheme.Radius.sm)
                                        }
                                    }
                                }
                            }
                        }

                        // Category
                        KCard {
                            VStack(alignment: .leading, spacing: KTheme.Spacing.sm) {
                                Text("Category").font(KTheme.Typography.headingSmall).foregroundColor(KTheme.Colors.textPrimary)
                                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: KTheme.Spacing.sm) {
                                    ForEach(KTask.TaskCategory.allCases, id: \.self) { cat in
                                        Button {
                                            category = cat
                                        } label: {
                                            VStack(spacing: 4) {
                                                Image(systemName: cat.icon)
                                                    .font(.system(size: 18))
                                                    .foregroundColor(category == cat ? KTheme.Colors.accentPrimary : KTheme.Colors.textSecondary)
                                                Text(cat.rawValue.capitalized)
                                                    .font(KTheme.Typography.caption)
                                                    .foregroundColor(category == cat ? KTheme.Colors.accentPrimary : KTheme.Colors.textTertiary)
                                            }
                                            .padding(KTheme.Spacing.sm)
                                            .frame(maxWidth: .infinity)
                                            .background(category == cat ? KTheme.Colors.accentPrimary.opacity(0.1) : KTheme.Colors.border.opacity(0.3))
                                            .cornerRadius(KTheme.Radius.sm)
                                        }
                                    }
                                }
                            }
                        }

                        // Tags
                        KCard {
                            VStack(alignment: .leading, spacing: KTheme.Spacing.sm) {
                                Text("Tags").font(KTheme.Typography.headingSmall).foregroundColor(KTheme.Colors.textPrimary)
                                if !tags.isEmpty {
                                    FlowLayout(spacing: KTheme.Spacing.xs) {
                                        ForEach(tags, id: \.self) { tag in
                                            HStack(spacing: 4) {
                                                Text(tag).font(KTheme.Typography.label).foregroundColor(KTheme.Colors.accentPrimary)
                                                Button {
                                                    tags.removeAll { $0 == tag }
                                                } label: {
                                                    Image(systemName: "xmark").font(.system(size: 10, weight: .bold)).foregroundColor(KTheme.Colors.accentPrimary)
                                                }
                                            }
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(KTheme.Colors.accentPrimary.opacity(0.1))
                                            .cornerRadius(KTheme.Radius.pill)
                                        }
                                    }
                                }
                                HStack {
                                    TextField("Add a tag...", text: $newTag)
                                        .foregroundColor(KTheme.Colors.textPrimary)
                                        .font(KTheme.Typography.bodyMedium)
                                        .onSubmit { addTag() }
                                    Button("Add") { addTag() }
                                        .foregroundColor(KTheme.Colors.accentPrimary)
                                        .disabled(newTag.trimmingCharacters(in: .whitespaces).isEmpty)
                                }
                            }
                        }

                        // Due date
                        KCard {
                            VStack(spacing: KTheme.Spacing.sm) {
                                Toggle(isOn: $hasDueDate) {
                                    Label("Set Due Date", systemImage: "calendar")
                                        .foregroundColor(KTheme.Colors.textPrimary)
                                        .font(KTheme.Typography.headingSmall)
                                }.tint(KTheme.Colors.accentPrimary)

                                if hasDueDate {
                                    DatePicker("", selection: $dueDate, displayedComponents: hasDueTime ? [.date, .hourAndMinute] : .date)
                                        .colorScheme(.dark)
                                        .labelsHidden()
                                    Toggle(isOn: $hasDueTime) {
                                        Text("Include Time").font(KTheme.Typography.label).foregroundColor(KTheme.Colors.textSecondary)
                                    }.tint(KTheme.Colors.accentPrimary)
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

    let iconOptions = ["flame.fill", "figure.run", "drop.fill", "leaf.fill", "moon.fill", "brain.head.profile", "heart.fill", "dumbbell.fill", "book.fill", "fork.knife", "scalemass.fill", "figure.flexibility"]
    let colorOptions = ["7C6FFF", "FF6B8A", "4ECDC4", "FFB347", "FF2D55", "34C759", "5AC8FA", "AF52DE"]

    var body: some View {
        NavigationView {
            ZStack {
                KTheme.Colors.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: KTheme.Spacing.lg) {

                        // Preview
                        KCard(elevated: true) {
                            HStack {
                                ZStack {
                                    Circle().fill(Color(hex: color)).frame(width: 52, height: 52)
                                    Image(systemName: icon).foregroundColor(.white).font(.system(size: 22))
                                }
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(title.isEmpty ? "Habit Name" : title).font(KTheme.Typography.headingMedium).foregroundColor(KTheme.Colors.textPrimary)
                                    Text(frequency.displayName).font(KTheme.Typography.caption).foregroundColor(KTheme.Colors.textSecondary)
                                }
                                Spacer()
                            }
                        }

                        KTextField(placeholder: "Habit name", text: $title, icon: "pencil")

                        // Icon picker
                        KCard {
                            VStack(alignment: .leading, spacing: KTheme.Spacing.sm) {
                                Text("Icon").font(KTheme.Typography.headingSmall).foregroundColor(KTheme.Colors.textPrimary)
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
                        }

                        // Color picker
                        KCard {
                            VStack(alignment: .leading, spacing: KTheme.Spacing.sm) {
                                Text("Color").font(KTheme.Typography.headingSmall).foregroundColor(KTheme.Colors.textPrimary)
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
                        }

                        // Frequency
                        KCard {
                            VStack(alignment: .leading, spacing: KTheme.Spacing.sm) {
                                Text("Frequency").font(KTheme.Typography.headingSmall).foregroundColor(KTheme.Colors.textPrimary)
                                ForEach(Habit.Frequency.allCases, id: \.self) { f in
                                    Button { frequency = f } label: {
                                        HStack {
                                            Text(f.displayName).font(KTheme.Typography.bodyMedium).foregroundColor(KTheme.Colors.textPrimary)
                                            Spacer()
                                            if frequency == f {
                                                Image(systemName: "checkmark.circle.fill").foregroundColor(KTheme.Colors.accentPrimary)
                                            }
                                        }
                                        .padding(.vertical, 4)
                                    }
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
}
