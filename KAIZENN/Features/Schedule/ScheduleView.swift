import SwiftUI

struct ScheduleView: View {
    @EnvironmentObject var scheduleStore: ScheduleStore
    @State private var selectedDate = Date()
    @State private var showAddTask = false
    @State private var showAddHabit = false
    @State private var selectedSegment: SegmentTab = .tasks

    private let accent = KTheme.Colors.accentTertiary

    enum SegmentTab: String, CaseIterable {
        case tasks = "Tasks", habits = "Habits"
    }

    var body: some View {
        ZStack {
            KTheme.Colors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                VStack(spacing: KTheme.Spacing.md) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("SCHEDULE")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(accent.opacity(0.8))
                                .tracking(2)
                            Text("Schedule")
                                .font(KTheme.Typography.displaySmall)
                                .foregroundColor(KTheme.Colors.textPrimary)
                        }
                        Spacer()
                        Button {
                            if selectedSegment == .tasks { showAddTask = true }
                            else { showAddHabit = true }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(accent)
                                .kGlow(color: accent, radius: 12)
                        }
                    }

                    // Date picker strip
                    WeekStripView(selectedDate: $selectedDate, accent: accent)

                    // Segment control
                    HStack(spacing: 0) {
                        ForEach(SegmentTab.allCases, id: \.self) { tab in
                            Button {
                                withAnimation(KTheme.Animation.smooth) { selectedSegment = tab }
                            } label: {
                                Text(tab.rawValue.uppercased())
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .tracking(1.5)
                                    .foregroundColor(selectedSegment == tab ? .white : KTheme.Colors.textSecondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(selectedSegment == tab ? accent : Color.clear)
                                    .cornerRadius(KTheme.Radius.md)
                            }
                        }
                    }
                    .background(KTheme.Colors.card.cornerRadius(KTheme.Radius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: KTheme.Radius.md)
                            .stroke(accent.opacity(0.2), lineWidth: 0.5)
                    )
                    .padding(.bottom, KTheme.Spacing.xs)
                }
                .padding(.horizontal, KTheme.Spacing.md)
                .padding(.top, KTheme.Spacing.md)
                .background(KTheme.Colors.background)

                // Content
                ScrollView(showsIndicators: false) {
                    VStack(spacing: KTheme.Spacing.md) {
                        if selectedSegment == .tasks {
                            tasksContent
                        } else {
                            habitsContent
                        }
                        Color.clear.frame(height: 100)
                    }
                    .padding(.horizontal, KTheme.Spacing.md)
                    .padding(.top, KTheme.Spacing.md)
                }
            }
        }
        .sheet(isPresented: $showAddTask) { AddTaskView() }
        .sheet(isPresented: $showAddHabit) { AddHabitView() }
    }

    // MARK: Tasks Content
    private var tasksContent: some View {
        VStack(spacing: KTheme.Spacing.md) {
            // Hero moment — task completion count
            taskHeroCard

            // Overdue
            if !scheduleStore.overdueTasks.isEmpty {
                premiumSection(title: "OVERDUE") {
                    VStack(spacing: KTheme.Spacing.sm) {
                        ForEach(scheduleStore.overdueTasks) { task in
                            TaskCard(task: task,
                                     onComplete: { scheduleStore.toggleTaskCompletion(id: task.id) },
                                     onDelete: { scheduleStore.removeTask(id: task.id) })
                        }
                    }
                }
            }

            // Today's tasks
            let todayTasks = scheduleStore.tasks(for: selectedDate)
            let sectionTitle = Calendar.current.isDateInToday(selectedDate)
                ? "TODAY"
                : selectedDate.formatted(date: .abbreviated, time: .omitted).uppercased()

            premiumSection(title: sectionTitle,
                           trailing: AnyView(taskDoneLabel(done: todayTasks.filter(\.isCompleted).count,
                                                           total: todayTasks.count))) {
                if todayTasks.isEmpty {
                    KEmptyState(icon: "checkmark.circle", title: "No tasks", subtitle: "Tap + to add a task for this day")
                } else {
                    VStack(spacing: KTheme.Spacing.sm) {
                        ForEach(todayTasks) { task in
                            TaskCard(task: task,
                                     onComplete: { scheduleStore.toggleTaskCompletion(id: task.id) },
                                     onDelete: { scheduleStore.removeTask(id: task.id) })
                        }
                    }
                }
            }

            // Upcoming (only for today view)
            if Calendar.current.isDateInToday(selectedDate) && !scheduleStore.upcomingTasks.isEmpty {
                premiumSection(title: "UPCOMING") {
                    VStack(spacing: KTheme.Spacing.sm) {
                        ForEach(scheduleStore.upcomingTasks.prefix(5)) { task in
                            TaskCard(task: task,
                                     onComplete: { scheduleStore.toggleTaskCompletion(id: task.id) },
                                     onDelete: { scheduleStore.removeTask(id: task.id) })
                        }
                    }
                }
            }
        }
    }

    // MARK: Hero card — task completion number
    private var taskHeroCard: some View {
        let todayTasks = scheduleStore.tasks(for: selectedDate)
        let done = todayTasks.filter(\.isCompleted).count
        let total = todayTasks.count

        return HStack(spacing: KTheme.Spacing.lg) {
            VStack(alignment: .leading, spacing: 4) {
                Text("COMPLETED")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(accent.opacity(0.8))
                    .tracking(1.5)
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text("\(done)")
                        .font(.system(size: 56, weight: .black, design: .rounded))
                        .foregroundColor(KTheme.Colors.textPrimary)
                    Text("/ \(total)")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundColor(KTheme.Colors.textSecondary)
                }
                Text("tasks today")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(KTheme.Colors.textTertiary)
                    .tracking(1.2)
            }
            Spacer()
            KProgressRing(
                progress: total > 0 ? Double(done) / Double(total) : 0,
                total: 1.0,
                size: 72,
                lineWidth: 7,
                color: accent,
                label: total > 0 ? "\(Int(Double(done) / Double(total) * 100))%" : "0%"
            )
            .kGlow(color: accent, radius: 14)
        }
        .padding(KTheme.Spacing.md)
        .background(KTheme.Colors.cardElevated)
        .cornerRadius(KTheme.Radius.lg)
        .overlay(
            RoundedRectangle(cornerRadius: KTheme.Radius.lg)
                .stroke(accent.opacity(0.3), lineWidth: 0.5)
        )
        .shadow(color: accent.opacity(0.15), radius: 20, x: 0, y: 0)
    }

    // MARK: Habits Content
    private var habitsContent: some View {
        VStack(spacing: KTheme.Spacing.md) {
            // Hero progress card
            habitHeroCard

            // Today's habits
            premiumSection(title: "DAILY HABITS") {
                VStack(spacing: KTheme.Spacing.sm) {
                    ForEach(scheduleStore.habits) { habit in
                        HabitDetailCard(habit: habit, onToggle: {
                            scheduleStore.toggleHabit(id: habit.id)
                        }, onDelete: {
                            withAnimation(KTheme.Animation.smooth) {
                                scheduleStore.removeHabit(id: habit.id)
                            }
                        })
                    }
                }
            }
        }
    }

    // MARK: Habit hero card
    private var habitHeroCard: some View {
        HStack(spacing: KTheme.Spacing.lg) {
            VStack(alignment: .leading, spacing: 4) {
                Text("HABIT PROGRESS")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(accent.opacity(0.8))
                    .tracking(1.5)
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text("\(scheduleStore.completedTodayCount)")
                        .font(.system(size: 56, weight: .black, design: .rounded))
                        .foregroundColor(KTheme.Colors.textPrimary)
                    Text("/ \(scheduleStore.todayHabits.count)")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundColor(KTheme.Colors.textSecondary)
                }
                Text("habits today")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(KTheme.Colors.textTertiary)
                    .tracking(1.2)
                HStack(spacing: KTheme.Spacing.xs) {
                    Text("BEST STREAK")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(KTheme.Colors.textTertiary)
                        .tracking(1.2)
                    KStreakBadge(days: scheduleStore.longestStreak)
                }
                .padding(.top, 2)
            }
            Spacer()
            KProgressRing(
                progress: scheduleStore.todayHabitProgress,
                total: 1.0,
                size: 72,
                lineWidth: 7,
                color: accent,
                label: "\(Int(scheduleStore.todayHabitProgress * 100))%"
            )
            .kGlow(color: accent, radius: 14)
        }
        .padding(KTheme.Spacing.md)
        .background(KTheme.Colors.cardElevated)
        .cornerRadius(KTheme.Radius.lg)
        .overlay(
            RoundedRectangle(cornerRadius: KTheme.Radius.lg)
                .stroke(accent.opacity(0.3), lineWidth: 0.5)
        )
        .shadow(color: accent.opacity(0.15), radius: 20, x: 0, y: 0)
    }

    // MARK: Helpers
    private func taskDoneLabel(done: Int, total: Int) -> some View {
        Text("\(done)/\(total) DONE")
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundColor(accent.opacity(0.8))
            .tracking(1.2)
    }

    @ViewBuilder
    private func premiumSection<Content: View>(title: String, trailing: AnyView? = nil, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: KTheme.Spacing.md) {
            HStack {
                Text(title)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(accent)
                    .tracking(2)
                Spacer()
                trailing
            }
            content()
        }
    }
}

// MARK: — Week Strip
struct WeekStripView: View {
    @Binding var selectedDate: Date
    var accent: Color = KTheme.Colors.accentTertiary
    private let calendar = Calendar.current
    private var weekDates: [Date] {
        let today = Date()
        let weekday = calendar.component(.weekday, from: today) - calendar.firstWeekday
        let start = calendar.date(byAdding: .day, value: -weekday, to: today)!
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    var body: some View {
        HStack(spacing: 6) {
            ForEach(weekDates, id: \.self) { date in
                Button {
                    withAnimation(KTheme.Animation.snappy) { selectedDate = date }
                } label: {
                    let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
                    let isToday = calendar.isDateInToday(date)
                    VStack(spacing: 4) {
                        Text(dayLetter(date))
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(isSelected ? .white : KTheme.Colors.textSecondary)
                            .tracking(1)
                        Text("\(calendar.component(.day, from: date))")
                            .font(KTheme.Typography.headingSmall)
                            .foregroundColor(isSelected ? .white : (isToday ? accent : KTheme.Colors.textPrimary))
                        Circle()
                            .fill(isToday ? accent : Color.clear)
                            .frame(width: 4, height: 4)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(dayBackground(isSelected: isSelected, isToday: isToday))
                    .cornerRadius(KTheme.Radius.md)
                }
            }
        }
    }

    private func dayBackground(isSelected: Bool, isToday: Bool) -> Color {
        if isSelected { return accent.opacity(0.8) }
        return Color.clear
    }

    private func dayLetter(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "EEE"
        return String(f.string(from: date).prefix(1))
    }
}

// MARK: — Task Card
struct TaskCard: View {
    let task: KTask
    let onComplete: () -> Void
    let onDelete: () -> Void

    private var priorityColor: Color { Color(hex: task.priority.color) }

    private var cardBackground: Color {
        task.isCompleted ? KTheme.Colors.card.opacity(0.5) : KTheme.Colors.card
    }

    private var cardBorderColor: Color {
        task.isOverdue ? KTheme.Colors.danger.opacity(0.3) : KTheme.Colors.border.opacity(0.4)
    }

    var body: some View {
        HStack(alignment: .top, spacing: KTheme.Spacing.sm) {
            Button(action: onComplete) {
                ZStack {
                    Circle()
                        .stroke(priorityColor, lineWidth: 2)
                        .frame(width: 24, height: 24)
                    if task.isCompleted {
                        Circle().fill(priorityColor).frame(width: 24, height: 24)
                        Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)).foregroundColor(.white)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(KTheme.Typography.bodyMedium)
                    .foregroundColor(task.isCompleted ? KTheme.Colors.textSecondary : KTheme.Colors.textPrimary)
                    .strikethrough(task.isCompleted, color: KTheme.Colors.textSecondary)

                if let notes = task.notes {
                    Text(notes).font(KTheme.Typography.caption).foregroundColor(KTheme.Colors.textTertiary).lineLimit(1)
                }

                HStack(spacing: KTheme.Spacing.sm) {
                    if let due = task.dueDate {
                        Label(due.formatted(date: .omitted, time: .shortened), systemImage: "clock")
                            .font(KTheme.Typography.caption)
                            .foregroundColor(task.isOverdue ? KTheme.Colors.danger : KTheme.Colors.textSecondary)
                    }
                    KBadge(text: task.priority.displayName, color: priorityColor)
                    Image(systemName: task.category.icon).font(.caption).foregroundColor(KTheme.Colors.textTertiary)
                }

                if !task.subtasks.isEmpty {
                    ProgressView(value: task.completionPercentage)
                        .tint(KTheme.Colors.accentTertiary)
                        .frame(maxWidth: 120)
                }

                if !task.tags.isEmpty {
                    FlowLayout(spacing: 4) {
                        ForEach(task.tags, id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(KTheme.Colors.accentTertiary)
                                .tracking(0.5)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(KTheme.Colors.accentTertiary.opacity(0.1))
                                .cornerRadius(KTheme.Radius.pill)
                        }
                    }
                }
            }

            Spacer()

            Button(action: onDelete) {
                Image(systemName: "trash").font(.caption).foregroundColor(KTheme.Colors.textTertiary).padding(8)
            }
        }
        .padding(KTheme.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: KTheme.Radius.md)
                .fill(cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: KTheme.Radius.md)
                        .stroke(cardBorderColor, lineWidth: 0.5)
                )
        )
    }
}

// MARK: — Habit Detail Card
struct HabitDetailCard: View {
    let habit: Habit
    let onToggle: () -> Void
    var onDelete: (() -> Void)? = nil

    private var habitColor: Color { Color(hex: habit.color) }

    private var cardBackground: Color {
        habit.isCompletedToday ? habitColor.opacity(0.08) : KTheme.Colors.card
    }

    private var cardBorder: Color {
        habit.isCompletedToday ? habitColor.opacity(0.3) : KTheme.Colors.border.opacity(0.4)
    }

    var body: some View {
        HStack(spacing: KTheme.Spacing.md) {
            Button(action: onToggle) {
                ZStack {
                    Circle()
                        .fill(habit.isCompletedToday ? habitColor : habitColor.opacity(0.15))
                        .frame(width: 44, height: 44)
                        .animation(KTheme.Animation.snappy, value: habit.isCompletedToday)
                    Image(systemName: habit.isCompletedToday ? "checkmark" : habit.icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(habit.isCompletedToday ? .white : habitColor)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(habit.title)
                    .font(KTheme.Typography.headingSmall)
                    .foregroundColor(habit.isCompletedToday ? KTheme.Colors.textSecondary : KTheme.Colors.textPrimary)
                    .strikethrough(habit.isCompletedToday, color: KTheme.Colors.textSecondary)
                Text(habit.frequency.displayName.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(KTheme.Colors.textTertiary)
                    .tracking(1.2)
            }

            Spacer()

            if habit.streak > 0 {
                KStreakBadge(days: habit.streak)
            }

            if let onDelete = onDelete {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundColor(KTheme.Colors.textTertiary)
                        .padding(.leading, KTheme.Spacing.xs)
                }
            }
        }
        .padding(KTheme.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: KTheme.Radius.md)
                .fill(cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: KTheme.Radius.md)
                        .stroke(cardBorder, lineWidth: 0.5)
                )
        )
        .animation(KTheme.Animation.snappy, value: habit.isCompletedToday)
    }
}
