import SwiftUI
import HealthKit
import WatchKit

struct ContentView: View {
    @StateObject private var vm = WatchViewModel()
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            // Dashboard Tab
            WatchDashboardView(vm: vm).tag(0)

            // Activity Rings Tab
            WatchActivityView(vm: vm).tag(1)

            // Quick Log Tab
            WatchQuickLogView(vm: vm).tag(2)

            // Workout Tab
            WatchWorkoutView(vm: vm).tag(3)
        }
        .tabViewStyle(.carousel)
        .onAppear { vm.requestAuthorization() }
    }
}

// MARK: — Dashboard
struct WatchDashboardView: View {
    @ObservedObject var vm: WatchViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                // Header
                HStack {
                    Text("KAIZENN").font(.system(size: 14, weight: .bold)).foregroundColor(.purple)
                    Spacer()
                    Text(Date(), style: .time).font(.caption2).foregroundColor(.secondary)
                }

                // Activity rings mini
                HStack(spacing: 6) {
                    WatchRing(value: vm.stepsProgress, color: .red, label: "Move")
                    WatchRing(value: vm.exerciseProgress, color: .green, label: "Exercise")
                    WatchRing(value: vm.standProgress, color: .cyan, label: "Stand")
                }

                // Heart rate
                HStack {
                    Image(systemName: "heart.fill").foregroundColor(.red).font(.caption2)
                    Text("\(Int(vm.heartRate)) BPM").font(.system(size: 16, weight: .semibold)).foregroundColor(.primary)
                }

                // Steps
                HStack {
                    Image(systemName: "figure.walk").foregroundColor(.green).font(.caption2)
                    Text("\(vm.steps) steps").font(.system(size: 13)).foregroundColor(.secondary)
                }

                // Calories
                HStack {
                    Image(systemName: "flame.fill").foregroundColor(.orange).font(.caption2)
                    Text("\(Int(vm.activeCalories)) active cal").font(.system(size: 13)).foregroundColor(.secondary)
                }

                // Coach tip
                if !vm.coachTip.isEmpty {
                    Text(vm.coachTip)
                        .font(.caption2)
                        .foregroundColor(.purple)
                        .padding(6)
                        .background(Color.purple.opacity(0.1))
                        .cornerRadius(8)
                }
            }
            .padding()
        }
        .onAppear { vm.fetchTodayData() }
    }
}

// MARK: — Activity Rings
struct WatchActivityView: View {
    @ObservedObject var vm: WatchViewModel

    var body: some View {
        VStack(spacing: 6) {
            Text("Activity").font(.system(size: 14, weight: .bold)).foregroundColor(.white)

            ZStack {
                WatchFullRing(progress: vm.stepsProgress, radius: 46, lineWidth: 8, color: .red)
                WatchFullRing(progress: vm.exerciseProgress, radius: 34, lineWidth: 8, color: .green)
                WatchFullRing(progress: vm.standProgress, radius: 22, lineWidth: 8, color: .cyan)
            }
            .frame(width: 100, height: 100)

            VStack(spacing: 4) {
                HStack { Circle().fill(.red).frame(width: 6, height: 6); Text("\(vm.steps) / 10,000 steps").font(.caption2).foregroundColor(.secondary) }
                HStack { Circle().fill(.green).frame(width: 6, height: 6); Text("\(Int(vm.exerciseMinutes)) / 30 min exercise").font(.caption2).foregroundColor(.secondary) }
                HStack { Circle().fill(.cyan).frame(width: 6, height: 6); Text("\(vm.standHours) / 12 stand hours").font(.caption2).foregroundColor(.secondary) }
            }
        }
        .padding()
    }
}

// MARK: — Quick Log
struct WatchQuickLogView: View {
    @ObservedObject var vm: WatchViewModel
    @State private var waterAdded = false

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                Text("Quick Log").font(.system(size: 14, weight: .bold)).foregroundColor(.white)

                // Water +250ml
                Button {
                    vm.logWater(ml: 250)
                    waterAdded = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { waterAdded = false }
                } label: {
                    HStack {
                        Image(systemName: "drop.fill").foregroundColor(.blue)
                        Text(waterAdded ? "+250ml ✓" : "+250ml Water").font(.system(size: 13))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(8)
                    .background(Color.blue.opacity(waterAdded ? 0.3 : 0.15))
                    .cornerRadius(10)
                }
                .buttonStyle(WatchScaleButtonStyle())

                // Start workout
                Button {
                    vm.startWorkout()
                } label: {
                    HStack {
                        Image(systemName: "play.fill").foregroundColor(.green)
                        Text("Start Workout").font(.system(size: 13))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(8)
                    .background(Color.green.opacity(0.15))
                    .cornerRadius(10)
                }
                .buttonStyle(WatchScaleButtonStyle())

                // Log mood
                Button {
                    WKInterfaceDevice.current().play(.success)
                } label: {
                    HStack {
                        Image(systemName: "face.smiling.fill").foregroundColor(.yellow)
                        Text("Log Mood").font(.system(size: 13))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(8)
                    .background(Color.yellow.opacity(0.15))
                    .cornerRadius(10)
                }
                .buttonStyle(WatchScaleButtonStyle())
            }
            .padding()
        }
    }
}

// MARK: — Workout
struct WatchWorkoutView: View {
    @ObservedObject var vm: WatchViewModel

    var body: some View {
        VStack(spacing: 8) {
            if vm.isWorkingOut {
                // Active workout display
                VStack(spacing: 6) {
                    Text(vm.selectedWorkoutType.displayName.uppercased())
                        .font(.system(size: 12, weight: .bold)).foregroundColor(.green)
                    Text(vm.workoutDurationString)
                        .font(.system(size: 28, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    HStack(spacing: 16) {
                        VStack(spacing: 0) {
                            Text("\(Int(vm.workoutCalories))")
                                .font(.system(size: 16, weight: .semibold)).foregroundColor(.orange)
                            Text("CAL").font(.system(size: 8)).foregroundColor(.secondary)
                        }
                        VStack(spacing: 0) {
                            Text("\(Int(vm.workoutHeartRate))")
                                .font(.system(size: 16, weight: .semibold)).foregroundColor(.red)
                            Text("BPM").font(.system(size: 8)).foregroundColor(.secondary)
                        }
                    }

                    Button("End Workout") {
                        vm.endWorkout()
                    }
                    .foregroundColor(.red)
                    .font(.system(size: 13, weight: .semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.2))
                    .cornerRadius(20)
                    .buttonStyle(WatchScaleButtonStyle())
                }
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        Text("Start Workout").font(.system(size: 14, weight: .bold)).foregroundColor(.white)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            ForEach(WatchWorkoutType.allCases) { type in
                                Button {
                                    vm.selectedWorkoutType = type
                                    WKInterfaceDevice.current().play(.click)
                                } label: {
                                    VStack(spacing: 4) {
                                        Image(systemName: type.icon).font(.system(size: 18))
                                        Text(type.displayName).font(.system(size: 10))
                                    }
                                    .foregroundColor(vm.selectedWorkoutType == type ? .white : .secondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(vm.selectedWorkoutType == type ? Color.purple : Color.gray.opacity(0.2))
                                    .cornerRadius(10)
                                }
                                .buttonStyle(WatchScaleButtonStyle())
                            }
                        }

                        Button("Start") { vm.startWorkout() }
                            .foregroundColor(.white)
                            .font(.system(size: 15, weight: .bold))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.purple)
                            .cornerRadius(20)
                            .buttonStyle(WatchScaleButtonStyle())
                    }
                    .padding(.bottom, 8)
                }
            }
        }
        .padding()
    }
}

// MARK: — Watch Workout Types
enum WatchWorkoutType: String, CaseIterable, Identifiable {
    case running, walking, cycling, hiit, strength, yoga

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .running:  return "Run"
        case .walking:  return "Walk"
        case .cycling:  return "Bike"
        case .hiit:     return "HIIT"
        case .strength: return "Strength"
        case .yoga:     return "Yoga"
        }
    }

    var icon: String {
        switch self {
        case .running:  return "figure.run"
        case .walking:  return "figure.walk"
        case .cycling:  return "figure.outdoor.cycle"
        case .hiit:     return "bolt.fill"
        case .strength: return "dumbbell.fill"
        case .yoga:     return "figure.mind.and.body"
        }
    }

    var hkActivityType: HKWorkoutActivityType {
        switch self {
        case .running:  return .running
        case .walking:  return .walking
        case .cycling:  return .cycling
        case .hiit:     return .highIntensityIntervalTraining
        case .strength: return .traditionalStrengthTraining
        case .yoga:     return .yoga
        }
    }
}

// MARK: — Watch Components
struct WatchScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct WatchRing: View {
    let value: Double
    let color: Color
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                Circle().stroke(color.opacity(0.2), lineWidth: 4).frame(width: 28, height: 28)
                Circle().trim(from: 0, to: min(value, 1)).stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 28, height: 28).rotationEffect(.degrees(-90))
            }
            Text(label).font(.system(size: 8)).foregroundColor(.secondary)
        }
    }
}

struct WatchFullRing: View {
    let progress: Double
    let radius: CGFloat
    let lineWidth: CGFloat
    let color: Color

    var body: some View {
        ZStack {
            Circle().stroke(color.opacity(0.2), lineWidth: lineWidth).frame(width: radius * 2, height: radius * 2)
            Circle().trim(from: 0, to: min(progress, 1))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .frame(width: radius * 2, height: radius * 2)
                .rotationEffect(.degrees(-90))
        }
    }
}

// MARK: — ViewModel
@MainActor
class WatchViewModel: NSObject, ObservableObject {
    @Published var steps = 0
    @Published var heartRate: Double = 72
    @Published var activeCalories: Double = 0
    @Published var exerciseMinutes: Double = 0
    @Published var standHours = 0
    @Published var isWorkingOut = false
    @Published var workoutDuration: TimeInterval = 0
    @Published var workoutCalories: Double = 0
    @Published var workoutHeartRate: Double = 0
    @Published var selectedWorkoutType: WatchWorkoutType = .running
    @Published var coachTip = ""

    private var workoutTimer: Timer?
    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?

    var stepsProgress: Double { Double(steps) / 10000.0 }
    var exerciseProgress: Double { exerciseMinutes / 30.0 }
    var standProgress: Double { Double(standHours) / 12.0 }
    var workoutDurationString: String {
        let m = Int(workoutDuration) / 60
        let s = Int(workoutDuration) % 60
        return String(format: "%02d:%02d", m, s)
    }

    func requestAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let read: Set<HKObjectType> = [
            HKQuantityType(.stepCount),
            HKQuantityType(.heartRate),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.appleExerciseTime),
            HKQuantityType(.distanceWalkingRunning),
            HKCategoryType(.appleStandHour)
        ]
        let share: Set<HKSampleType> = [
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.heartRate),
            HKQuantityType(.distanceWalkingRunning),
            HKObjectType.workoutType()
        ]
        healthStore.requestAuthorization(toShare: share, read: read) { _, _ in
            Task { @MainActor in self.fetchTodayData() }
        }
    }

    func fetchTodayData() {
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now)

        // Steps
        let stepsQuery = HKStatisticsQuery(quantityType: HKQuantityType(.stepCount), quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
            if let sum = result?.sumQuantity() {
                Task { @MainActor in
                    self.steps = Int(sum.doubleValue(for: .count()))
                    self.updateCoachTip()
                }
            }
        }

        // Heart rate
        let hrQuery = HKStatisticsQuery(quantityType: HKQuantityType(.heartRate), quantitySamplePredicate: predicate, options: .discreteAverage) { _, result, _ in
            if let avg = result?.averageQuantity() {
                Task { @MainActor in
                    self.heartRate = avg.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                    self.updateCoachTip()
                }
            }
        }

        // Active calories
        let calQuery = HKStatisticsQuery(quantityType: HKQuantityType(.activeEnergyBurned), quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
            if let sum = result?.sumQuantity() {
                Task { @MainActor in self.activeCalories = sum.doubleValue(for: .kilocalorie()) }
            }
        }

        // Exercise minutes
        let exerciseQuery = HKStatisticsQuery(quantityType: HKQuantityType(.appleExerciseTime), quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
            if let sum = result?.sumQuantity() {
                Task { @MainActor in
                    self.exerciseMinutes = sum.doubleValue(for: .minute())
                    self.updateCoachTip()
                }
            }
        }

        // Stand hours
        let standQuery = HKSampleQuery(sampleType: HKCategoryType(.appleStandHour), predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
            let stoodHours = (samples as? [HKCategorySample])?.filter { $0.value == HKCategoryValueAppleStandHour.stood.rawValue }.count ?? 0
            Task { @MainActor in self.standHours = stoodHours }
        }

        healthStore.execute(stepsQuery)
        healthStore.execute(hrQuery)
        healthStore.execute(calQuery)
        healthStore.execute(exerciseQuery)
        healthStore.execute(standQuery)

        updateCoachTip()
    }

    func logWater(ml: Int) {
        WKInterfaceDevice.current().play(.click)
        // Send to phone via WatchConnectivity in full implementation
    }

    // MARK: Workout Session
    func startWorkout() {
        guard HKHealthStore.isHealthDataAvailable(), !isWorkingOut else { return }

        let config = HKWorkoutConfiguration()
        config.activityType = selectedWorkoutType.hkActivityType
        config.locationType = .unknown

        do {
            let session = try HKWorkoutSession(healthStore: healthStore, configuration: config)
            let builder = session.associatedWorkoutBuilder()
            builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: config)
            session.delegate = self
            builder.delegate = self
            self.session = session
            self.builder = builder

            let start = Date()
            session.startActivity(with: start)
            builder.beginCollection(withStart: start) { _, _ in }
        } catch {
            return
        }

        isWorkingOut = true
        workoutDuration = 0
        workoutCalories = 0
        workoutHeartRate = 0
        WKInterfaceDevice.current().play(.start)
        workoutTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in self.workoutDuration += 1 }
        }
    }

    func endWorkout() {
        workoutTimer?.invalidate()
        workoutTimer = nil
        isWorkingOut = false
        WKInterfaceDevice.current().play(.stop)

        let endDate = Date()
        session?.end()
        builder?.endCollection(withEnd: endDate) { [weak self] _, _ in
            self?.builder?.finishWorkout { _, _ in
                Task { @MainActor in
                    self?.session = nil
                    self?.builder = nil
                }
            }
        }
    }

    private func updateCoachTip() {
        if steps < 3000 {
            coachTip = "Let's get moving — a short walk goes a long way 🚶"
        } else if exerciseMinutes < 15 {
            coachTip = "Aim for 30 min of exercise today 🔥"
        } else if steps >= 10000 {
            coachTip = "10,000 steps — crushing it today! 🎉"
        } else if heartRate > 100 {
            coachTip = "Heart rate's up — great intensity 💪"
        } else {
            coachTip = "Stay hydrated — aim for 2.5L today 💧"
        }
    }
}

// MARK: — Workout Session Delegates
extension WatchViewModel: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {}

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {}
}

extension WatchViewModel: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType,
                  let statistics = workoutBuilder.statistics(for: quantityType) else { continue }

            switch quantityType.identifier {
            case HKQuantityTypeIdentifier.heartRate.rawValue:
                let bpm = statistics.mostRecentQuantity()?.doubleValue(for: HKUnit.count().unitDivided(by: .minute())) ?? 0
                Task { @MainActor [weak self] in self?.workoutHeartRate = bpm }
            case HKQuantityTypeIdentifier.activeEnergyBurned.rawValue:
                let cal = statistics.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
                Task { @MainActor [weak self] in self?.workoutCalories = cal }
            default:
                break
            }
        }
    }

    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}
}

// MARK: — Notification Controller
class NotificationController: WKUserNotificationHostingController<NotificationView> {
    override var body: NotificationView {
        return NotificationView()
    }
}

struct NotificationView: View {
    var body: some View {
        Text("KAIZENN Reminder").font(.headline)
    }
}
