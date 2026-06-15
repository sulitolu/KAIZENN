import SwiftUI

struct ScheduleView: View {
    @EnvironmentObject var scheduleStore: ScheduleStore
    @State private var selectedDate = Date()
    @State private var showAddTask = false
    @State private var showAddHabit = false
    @State private var selectedSegment: SegmentTab = .tasks

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
                        Text("Schedule")
                            .font(KTheme.Typography.displaySmall)
                            .foregroundColor(KTheme.Colors.textPrimary)
                        Spacer()
                        Button {
                            if selectedSegment == .tasks { showAddTask = true }
                            else { showAddHabit = true }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(KTheme.Colors.accentPrimary)
                        }
                    }

                    // Date picker strip
                    WeekStripView(selectedDate: $selectedDate)

                    // Segment control
                    HStack(spacing: 0) {
                        ForEach(SegmentTab.allCases, id: \.self) { tab in
                            Button {
                                withAnimation(KTheme.Animation.smooth) { selectedSegment = tab }
                            } label: {
                                Text(tab.rawValue)
                                    .font(KTheme.Typography.headingSmall)
                                    .foregroundColor(selectedSegment == tab ? .white : KTheme.Colors.textSecondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(selectedSegment == tab ? KTheme.Colors.accentPrimary : Color.clear)
                                    .cornerRadius(KTheme.Radius.md)
                            }
                        }
                    }
                    .background(KTheme.Colors.card.cornerRadius(KTheme.Radius.md))
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
            // Overdue
            if !scheduleStore.overdueTasks.isEmpty {
                KSection(title: "⚠️ Overdue") {
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
            KSection(title: Calendar.current.isDateInToday(selectedDate) ? "Today" : selectedDate.formatted(date: .abbreviated, time: .omitted),
                     trailing: AnyView(Text("\(todayTasks.filter(\.isCompleted).count)/\(todayTasks.count) done").font(KTheme.Typography.caption).foregroundColor(KTheme.Colors.textSecondary))) {
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
                KSection(title: "Upcoming") {
                    VStack(spacing: KTheme.Spacing.sm) {
                        ForEach(scheduleStore.upcomingTasks.prefix(5)) { task in
                            TaskCard(task: task, onComplete: { scheduleStore.toggleTaskCompletion(id: task.id) }, onDelete: { scheduleStore.removeTask(id: task.id) })
                        }
                    }
                }
            }
        }
    }

    // MARK: Habits Content
    private var habitsContent: some View {
        VStack(spacing: KTheme.Spacing.md) {
            // Progress card
            KCard(elevated: true) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Today's Progress").font(KTheme.Typography.headingSmall).foregroundColor(KTheme.Colors.textPrimary)
                        Text("\(scheduleStore.completedTodayCount) of \(scheduleStore.todayHabits.count) habits").font(KTheme.Typography.bodyMedium).foregroundColor(KTheme.Colors.textSecondary)
                        HStack(spacing: KTheme.Spacing.xs) {
                            Text("Best streak").font(KTheme.Typography.caption).foregroundColor(KTheme.Colors.textTertiary)
                            KStreakBadge(days: scheduleStore.longestStreak)
                        }
                    }
                    Spacer()
                    KProgressRing(progress: scheduleStore.todayHabitProgress, total: 1.0, size: 72, lineWidth: 7, color: KTheme.Colors.accentPrimary,
                                  label: "\(Int(scheduleStore.todayHabitProgress * 100))%")
                }
            }

            // Today's habits
            KSection(title: "Daily Habits") {
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
}

// MARK: — Week Strip
struct WeekStripView: View {
    @Binding var selectedDate: Date
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
                            .font(KTheme.Typography.caption)
                            .foregroundColor(isSelected ? .white : KTheme.Colors.textSecondary)
                        Text("\(calendar.component(.day, from: date))")
                            .font(KTheme.Typography.headingSmall)
                            .foregroundColor(isSelected ? .white : (isToday ? KTheme.Colors.accentPrimary : KTheme.Colors.textPrimary))
                        Circle()
                            .fill(isToday ? KTheme.Colors.accentPrimary : Color.clear)
                            .frame(width: 4, height: 4)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(isSelected ? KTheme.Colors.accentPrimary.opacity(0.8) : Color.clear)
                    .cornerRadius(KTheme.Radius.md)
                }
            }
        }
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

    var body: some View {
        HStack(alignment: .top, spacing: KTheme.Spacing.sm) {
            Button(action: onComplete) {
                ZStack {
                    Circle()
                        .stroke(Color(hex: task.priority.color), lineWidth: 2)
                        .frame(width: 24, height: 24)
                    if task.isCompleted {
                        Circle().fill(Color(hex: task.priority.color)).frame(width: 24, height: 24)
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
                    KBadge(text: task.priority.displayName, color: Color(hex: task.priority.color))
                    Image(systemName: task.category.icon).font(.caption).foregroundColor(KTheme.Colors.textTertiary)
                }

                if !task.subtasks.isEmpty {
                    ProgressView(value: task.completionPercentage)
                        .tint(KTheme.Colors.accentPrimary)
                        .frame(maxWidth: 120)
                }

                if !task.tags.isEmpty {
                    FlowLayout(spacing: 4) {
                        ForEach(task.tags, id: \.self) { tag in
                            Text("#\(tag)")
                                .font(KTheme.Typography.caption)
                                .foregroundColor(KTheme.Colors.accentPrimary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(KTheme.Colors.accentPrimary.opacity(0.1))
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
                .fill(task.isCompleted ? KTheme.Colors.card.opacity(0.5) : KTheme.Colors.card)
                .overlay(
                    RoundedRectangle(cornerRadius: KTheme.Radius.md)
                        .stroke(task.isOverdue ? KTheme.Colors.danger.opacity(0.3) : KTheme.Colors.border.opacity(0.4), lineWidth: 0.5)
                )
        )
    }
}

// MARK: — Habit Detail Card
struct HabitDetailCard: View {
    let habit: Habit
    let onToggle: () -> Void
    var onDelete: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: KTheme.Spacing.md) {
            Button(action: onToggle) {
                ZStack {
                    Circle()
                        .fill(habit.isCompletedToday ? Color(hex: habit.color) : Color(hex: habit.color).opacity(0.15))
                        .frame(width: 44, height: 44)
                        .animation(KTheme.Animation.snappy, value: habit.isCompletedToday)
                    Image(systemName: habit.isCompletedToday ? "checkmark" : habit.icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(habit.isCompletedToday ? .white : Color(hex: habit.color))
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(habit.title)
                    .font(KTheme.Typography.headingSmall)
                    .foregroundColor(habit.isCompletedToday ? KTheme.Colors.textSecondary : KTheme.Colors.textPrimary)
                    .strikethrough(habit.isCompletedToday, color: KTheme.Colors.textSecondary)
                Text(habit.frequency.displayName).font(KTheme.Typography.caption).foregroundColor(KTheme.Colors.textTertiary)
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
                .fill(habit.isCompletedToday ? Color(hex: habit.color).opacity(0.08) : KTheme.Colors.card)
                .overlay(
                    RoundedRectangle(cornerRadius: KTheme.Radius.md)
                        .stroke(habit.isCompletedToday ? Color(hex: habit.color).opacity(0.3) : KTheme.Colors.border.opacity(0.4), lineWidth: 0.5)
                )
        )
        .animation(KTheme.Animation.snappy, value: habit.isCompletedToday)
    }
}
