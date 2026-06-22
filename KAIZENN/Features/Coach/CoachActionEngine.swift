import Foundation

/// One concrete suggestion Kai can make. Applying it adds `task` to the schedule.
struct ProposedAction: Identifiable {
    let id: String        // stable key so a dismissal persists for the day
    let title: String
    let detail: String
    let task: KTask
}

/// Rule-based proposal generator. Pure (readiness + sleep debt in → proposals out) so it's
/// unit-testable and the LLM can later become an alternate source feeding the same pipeline.
enum CoachActionEngine {
    static let strainThreshold = 55.0
    static let sleepDebtThreshold = 3.0
    static let maxProposals = 3

    static func proposals(readiness: ReadinessBreakdown, sleepDebtHours: Double) -> [ProposedAction] {
        var out: [ProposedAction] = []
        let lowReadiness = readiness.label == .caution || readiness.label == .recover

        if lowReadiness {
            out.append(ProposedAction(
                id: "recovery-session",
                title: "Add a recovery session",
                detail: "20 min mobility — your readiness is low today",
                task: KTask(title: "Recovery / mobility — 20 min", category: .recovery)))
            out.append(ProposedAction(
                id: "protect-sleep",
                title: "Protect your sleep tonight",
                detail: "Aim for 9h — recovery starts with sleep",
                task: KTask(title: "Lights out for 9h sleep", category: .recovery)))
        }
        if let strain = readiness.strain, strain < strainThreshold {
            out.append(ProposedAction(
                id: "ease-training",
                title: "Ease a hard session this week",
                detail: "Training strain is high — swap one hard day for easy",
                task: KTask(title: "Make one hard session easier this week", category: .fitness)))
        }
        if sleepDebtHours >= sleepDebtThreshold {
            out.append(ProposedAction(
                id: "wind-down",
                title: "Earlier wind-down tonight",
                detail: String(format: "You're ~%.0fh down on sleep this week", sleepDebtHours),
                task: KTask(title: "Start wind-down 30 min earlier tonight", category: .recovery)))
        }
        return Array(out.prefix(maxProposals))
    }
}

/// Persists per-day dismissals so a dismissed card doesn't reappear the same day.
/// Only today's set is kept, so it self-clears when the date rolls over.
final class CoachActionStore {
    private let key = "kaizenn_coach_dismissed_actions"
    private var today: String { DateFormatter.isoDate.string(from: Date()) }

    func dismissed() -> Set<String> {
        let dict = UserDefaults.standard.dictionary(forKey: key) as? [String: [String]] ?? [:]
        return Set(dict[today] ?? [])
    }

    func dismiss(_ id: String) {
        var todays = dismissed()
        todays.insert(id)
        UserDefaults.standard.set([today: Array(todays)], forKey: key)
    }
}
