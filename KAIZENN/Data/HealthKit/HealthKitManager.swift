import HealthKit
import Combine

@MainActor
class HealthKitManager: ObservableObject {
    static let shared = HealthKitManager()
    private let store = HKHealthStore()

    @Published var isAuthorized: Bool = false
    @Published var todaySteps: Int = 0
    @Published var todayActiveCalories: Double = 0
    @Published var todayRestingCalories: Double = 0
    @Published var todayExerciseMinutes: Int = 0
    @Published var todayStandHours: Int = 0
    @Published var todayDistance: Double = 0
    @Published var heartRateCurrent: Double? = nil
    @Published var heartRateResting: Double? = nil
    @Published var sleepHoursLast: Double = 0
    @Published var bloodOxygen: Double? = nil
    @Published var hrvLatestMs: Double? = nil      // most recent HRV SDNN (ms)
    @Published var hrvBaselineMs: Double? = nil    // 7-day average HRV SDNN (ms)
    @Published var recentWorkouts: [WorkoutSession] = []

    /// Change in HRV vs the rolling 7-day baseline (positive = better recovery).
    var hrvDeltaMs: Double? {
        guard let latest = hrvLatestMs, let base = hrvBaselineMs else { return nil }
        return latest - base
    }

    // MARK: Read types
    private let readTypes: Set<HKObjectType> = {
        var types = Set<HKObjectType>()
        let ids: [HKQuantityTypeIdentifier] = [
            .stepCount, .activeEnergyBurned, .basalEnergyBurned,
            .distanceWalkingRunning, .heartRate, .restingHeartRate,
            .heartRateVariabilitySDNN, .oxygenSaturation,
            .flightsClimbed, .bodyMass, .bodyFatPercentage,
            .leanBodyMass, .waistCircumference
        ]
        ids.compactMap { HKQuantityType.quantityType(forIdentifier: $0) }.forEach { types.insert($0) }
        types.insert(HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!)
        types.insert(HKObjectType.activitySummaryType())
        types.insert(HKObjectType.workoutType())
        return types
    }()

    // MARK: Write types
    private let writeTypes: Set<HKSampleType> = {
        var types = Set<HKSampleType>()
        [HKQuantityTypeIdentifier.bodyMass, .activeEnergyBurned, .distanceWalkingRunning]
            .compactMap { HKQuantityType.quantityType(forIdentifier: $0) }
            .forEach { types.insert($0) }
        types.insert(HKObjectType.workoutType())
        return types
    }()

    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        do {
            try await store.requestAuthorization(toShare: writeTypes, read: readTypes)
            isAuthorized = true
            await fetchAllTodayData()
            startObservers()
        } catch {
            print("HealthKit auth error: \(error)")
        }
    }

    // MARK: Fetch all today data
    func fetchAllTodayData() async {
        async let steps = fetchTodayQuantity(.stepCount, unit: .count())
        async let active = fetchTodayQuantity(.activeEnergyBurned, unit: .kilocalorie())
        async let resting = fetchTodayQuantity(.basalEnergyBurned, unit: .kilocalorie())
        async let distance = fetchTodayQuantity(.distanceWalkingRunning, unit: .meter())
        async let hr = fetchMostRecentSample(.heartRate, unit: HKUnit.count().unitDivided(by: .minute()))
        async let hrResting = fetchMostRecentSample(.restingHeartRate, unit: HKUnit.count().unitDivided(by: .minute()))
        async let hrv = fetchMostRecentSample(.heartRateVariabilitySDNN, unit: HKUnit.secondUnit(with: .milli))
        async let hrvBase = fetchAverageQuantity(.heartRateVariabilitySDNN, unit: HKUnit.secondUnit(with: .milli), days: 7)
        async let workouts = fetchRecentWorkouts()
        async let sleep = fetchLastNightSleep()

        let (s, a, r, d, h, hrr, hv, hvb, w, sl) = await (steps, active, resting, distance, hr, hrResting, hrv, hrvBase, workouts, sleep)
        todaySteps = Int(s)
        todayActiveCalories = a
        todayRestingCalories = r
        todayDistance = d
        heartRateCurrent = h > 0 ? h : nil
        heartRateResting = hrr > 0 ? hrr : nil
        hrvLatestMs = hv > 0 ? hv : nil
        hrvBaselineMs = hvb > 0 ? hvb : nil
        recentWorkouts = w
        sleepHoursLast = sl
    }

    // MARK: Quantity helpers
    func fetchTodayQuantity(_ id: HKQuantityTypeIdentifier, unit: HKUnit) async -> Double {
        guard let type = HKQuantityType.quantityType(forIdentifier: id) else { return 0 }
        let now = Date()
        let start = Calendar.current.startOfDay(for: now)
        let pred = HKQuery.predicateForSamples(withStart: start, end: now)
        return await withCheckedContinuation { cont in
            let q = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: pred, options: .cumulativeSum) { _, stats, _ in
                cont.resume(returning: stats?.sumQuantity()?.doubleValue(for: unit) ?? 0)
            }
            store.execute(q)
        }
    }

    /// Rolling average of a discrete quantity (e.g. HRV SDNN) over the last `days` days.
    func fetchAverageQuantity(_ id: HKQuantityTypeIdentifier, unit: HKUnit, days: Int) async -> Double {
        guard let type = HKQuantityType.quantityType(forIdentifier: id) else { return 0 }
        let start = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let pred = HKQuery.predicateForSamples(withStart: start, end: Date())
        return await withCheckedContinuation { cont in
            let q = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: pred, options: .discreteAverage) { _, stats, _ in
                cont.resume(returning: stats?.averageQuantity()?.doubleValue(for: unit) ?? 0)
            }
            store.execute(q)
        }
    }

    func fetchMostRecentSample(_ id: HKQuantityTypeIdentifier, unit: HKUnit) async -> Double {
        guard let type = HKQuantityType.quantityType(forIdentifier: id) else { return 0 }
        return await withCheckedContinuation { cont in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let q = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
                let val = (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: unit) ?? 0
                cont.resume(returning: val)
            }
            store.execute(q)
        }
    }

    func fetchWeightHistory(days: Int = 90) async -> [BodyMeasurement] {
        guard let type = HKQuantityType.quantityType(forIdentifier: .bodyMass) else { return [] }
        let start = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        let pred = HKQuery.predicateForSamples(withStart: start, end: Date())
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)
        return await withCheckedContinuation { cont in
            let q = HKSampleQuery(sampleType: type, predicate: pred, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, _ in
                let measurements = (samples as? [HKQuantitySample])?.map { s in
                    BodyMeasurement(date: s.endDate, weightKg: s.quantity.doubleValue(for: .gramUnit(with: .kilo)))
                } ?? []
                cont.resume(returning: measurements)
            }
            store.execute(q)
        }
    }

    func fetchHeartRateHistory(hours: Int = 24) async -> [HeartRateSample] {
        guard let type = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return [] }
        let start = Date().addingTimeInterval(-Double(hours) * 3600)
        let pred = HKQuery.predicateForSamples(withStart: start, end: Date())
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)
        let unit = HKUnit.count().unitDivided(by: .minute())
        return await withCheckedContinuation { cont in
            let q = HKSampleQuery(sampleType: type, predicate: pred, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, _ in
                let samples = (samples as? [HKQuantitySample])?.map { s in
                    HeartRateSample(timestamp: s.endDate, bpm: s.quantity.doubleValue(for: unit))
                } ?? []
                cont.resume(returning: samples)
            }
            store.execute(q)
        }
    }

    func fetchRecentWorkouts(limit: Int = 20) async -> [WorkoutSession] {
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        return await withCheckedContinuation { cont in
            let q = HKSampleQuery(sampleType: .workoutType(), predicate: nil, limit: limit, sortDescriptors: [sort]) { _, samples, _ in
                let sessions = (samples as? [HKWorkout])?.map { w -> WorkoutSession in
                    var session = WorkoutSession(startDate: w.startDate, type: w.workoutActivityType.kaizennType)
                    session.endDate = w.endDate
                    session.caloriesBurned = w.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0
                    session.distanceMeters = w.totalDistance?.doubleValue(for: .meter())
                    session.source = .healthKit
                    return session
                } ?? []
                cont.resume(returning: sessions)
            }
            store.execute(q)
        }
    }

    func fetchLastNightSleep() async -> Double {
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return 0 }
        let yesterday = Calendar.current.date(byAdding: .hour, value: -24, to: Date())!
        let pred = HKQuery.predicateForSamples(withStart: yesterday, end: Date())
        return await withCheckedContinuation { cont in
            let q = HKSampleQuery(sampleType: type, predicate: pred, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
                let asleepSamples = (samples as? [HKCategorySample])?.filter {
                    [HKCategoryValueSleepAnalysis.asleepREM.rawValue,
                     HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                     HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                     HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue].contains($0.value)
                } ?? []
                let totalSeconds = asleepSamples.reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
                cont.resume(returning: totalSeconds / 3600)
            }
            store.execute(q)
        }
    }

    // MARK: Save weight
    func saveWeight(_ kg: Double, date: Date = Date()) async {
        guard let type = HKQuantityType.quantityType(forIdentifier: .bodyMass) else { return }
        let quantity = HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: kg)
        let sample = HKQuantitySample(type: type, quantity: quantity, start: date, end: date)
        try? await store.save(sample)
    }

    // MARK: Save workout
    func saveWorkout(_ workout: WorkoutSession) async {
        let end = workout.endDate ?? workout.startDate.addingTimeInterval(workout.duration)

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = workout.type.hkWorkoutActivityType

        let builder = HKWorkoutBuilder(healthStore: store, configuration: configuration, device: .local())

        do {
            try await builder.beginCollection(at: workout.startDate)

            var samples: [HKSample] = []
            if let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
                let energyQuantity = HKQuantity(unit: .kilocalorie(), doubleValue: workout.caloriesBurned)
                samples.append(HKQuantitySample(type: energyType, quantity: energyQuantity, start: workout.startDate, end: end))
            }
            if let distanceMeters = workout.distanceMeters,
               let distanceIdentifier = workout.type.hkDistanceTypeIdentifier,
               let distanceType = HKQuantityType.quantityType(forIdentifier: distanceIdentifier) {
                let distanceQuantity = HKQuantity(unit: .meter(), doubleValue: distanceMeters)
                samples.append(HKQuantitySample(type: distanceType, quantity: distanceQuantity, start: workout.startDate, end: end))
            }
            if !samples.isEmpty {
                try await builder.addSamples(samples)
            }

            try await builder.endCollection(at: end)
            _ = try await builder.finishWorkout()
        } catch {
            return
        }
    }

    // MARK: Live observers
    private func startObservers() {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return }
        let q = HKObserverQuery(sampleType: stepType, predicate: nil) { [weak self] _, _, _ in
            Task { await self?.fetchAllTodayData() }
        }
        store.execute(q)
        store.enableBackgroundDelivery(for: stepType, frequency: .immediate) { _, _ in }
    }
}

// MARK: — HKWorkoutActivityType → WorkoutType
extension HKWorkoutActivityType {
    var kaizennType: WorkoutType {
        switch self {
        case .running:           return .running
        case .walking:           return .walking
        case .cycling:           return .cycling
        case .swimming:          return .swimming
        case .rowing:            return .rowing
        case .elliptical:        return .elliptical
        case .jumpRope:          return .jumpRope
        case .stairClimbing:     return .stairClimber
        case .traditionalStrengthTraining, .functionalStrengthTraining: return .weightTraining
        case .coreTraining:      return .bodyweight
        case .crossTraining:     return .crossfit
        case .pilates:           return .pilates
        case .basketball:        return .basketball
        case .soccer:            return .soccer
        case .tennis:            return .tennis
        case .volleyball:        return .volleyball
        case .boxing:            return .boxing
        case .martialArts:       return .martialArts
        case .yoga:              return .yoga
        case .flexibility:       return .stretching
        case .mindAndBody:       return .meditation
        case .highIntensityIntervalTraining: return .hiit
        default:                 return .other
        }
    }
}

// MARK: — WorkoutType → HKWorkoutActivityType
extension WorkoutType {
    var hkWorkoutActivityType: HKWorkoutActivityType {
        switch self {
        case .running:        return .running
        case .walking:        return .walking
        case .cycling:        return .cycling
        case .swimming:       return .swimming
        case .rowing:         return .rowing
        case .elliptical:     return .elliptical
        case .jumpRope:       return .jumpRope
        case .stairClimber:   return .stairClimbing
        case .weightTraining: return .traditionalStrengthTraining
        case .bodyweight:     return .coreTraining
        case .crossfit:       return .crossTraining
        case .pilates:        return .pilates
        case .basketball:     return .basketball
        case .soccer:         return .soccer
        case .tennis:         return .tennis
        case .volleyball:     return .volleyball
        case .boxing:         return .boxing
        case .martialArts:    return .martialArts
        case .yoga:           return .yoga
        case .stretching:     return .flexibility
        case .meditation:     return .mindAndBody
        case .hiit:           return .highIntensityIntervalTraining
        case .other:          return .other
        }
    }

    /// The HealthKit distance quantity type that matches this activity, if any.
    var hkDistanceTypeIdentifier: HKQuantityTypeIdentifier? {
        switch self {
        case .running, .walking, .hiit:  return .distanceWalkingRunning
        case .cycling:                   return .distanceCycling
        case .swimming:                  return .distanceSwimming
        default:                         return nil
        }
    }
}
