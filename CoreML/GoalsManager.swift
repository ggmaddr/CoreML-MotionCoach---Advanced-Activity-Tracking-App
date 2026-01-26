import Foundation
import Combine

@MainActor
class GoalsManager: ObservableObject {
    @Published var goals: [Goal] = []
    
    private let persistenceController = PersistenceController.shared
    
    init() {
        loadGoals()
    }
    
    func createGoal(
        title: String,
        type: GoalType,
        targetValue: Double,
        timeframe: Timeframe,
        allowedActivities: [ActivityType],
        verificationMode: VerificationMode = .matchedDistance,
        minConfidenceAvg: Double = 0.5,
        mustBeContinuous: Bool = true,
        minDuration: Double? = nil
    ) -> Goal {
        let goal = Goal(
            id: UUID(),
            title: title,
            type: type,
            targetValue: targetValue,
            timeframe: timeframe,
            allowedActivities: allowedActivities,
            verificationMode: verificationMode,
            minConfidenceAvg: minConfidenceAvg,
            status: .active,
            mustBeContinuous: mustBeContinuous,
            minDuration: minDuration
        )
        
        goals.append(goal)
        saveGoals()
        return goal
    }
    
    func updateGoal(_ goal: Goal) {
        if let index = goals.firstIndex(where: { $0.id == goal.id }) {
            goals[index] = goal
            saveGoals()
        }
    }
    
    func deleteGoal(_ goal: Goal) {
        goals.removeAll { $0.id == goal.id }
        saveGoals()
    }
    
    func getActiveGoals(for date: Date = Date()) -> [Goal] {
        return goals.filter { goal in
            guard goal.status == .active else { return false }
            
            switch goal.timeframe {
            case .today:
                return Calendar.current.isDateInToday(date)
            case .thisWeek:
                return Calendar.current.isDate(date, equalTo: date, toGranularity: .weekOfYear)
            case .customRange:
                return true // For MVP, custom range always active
            }
        }
    }
    
    private func loadGoals() {
        // For MVP, use UserDefaults. Later migrate to CoreData
        if let data = UserDefaults.standard.data(forKey: "goals"),
           let decoded = try? JSONDecoder().decode([Goal].self, from: data) {
            goals = decoded
        }
    }
    
    private func saveGoals() {
        if let encoded = try? JSONEncoder().encode(goals) {
            UserDefaults.standard.set(encoded, forKey: "goals")
        }
    }
}
