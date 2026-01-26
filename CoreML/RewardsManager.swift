import Foundation
import Combine

@MainActor
class RewardsManager: ObservableObject {
    @Published var userProgress: UserProgress
    
    private let persistenceController = PersistenceController.shared
    
    init() {
        // Load from UserDefaults for MVP
        if let data = UserDefaults.standard.data(forKey: "userProgress"),
           let decoded = try? JSONDecoder().decode(UserProgress.self, from: data) {
            userProgress = decoded
        } else {
            // Use mock data for demo
            userProgress = MockData.sampleUserProgress
            saveProgress()
        }
    }
    
    func awardXP(_ amount: Int, reason: String) {
        userProgress.currentXP += amount
        
        // Calculate level (100 XP per level)
        let newLevel = (userProgress.currentXP / 100) + 1
        if newLevel > userProgress.level {
            userProgress.level = newLevel
        }
        
        saveProgress()
    }
    
    func updateStreak() {
        let today = Calendar.current.startOfDay(for: Date())
        
        if let lastCompletion = userProgress.lastCompletionDate {
            let lastDay = Calendar.current.startOfDay(for: lastCompletion)
            let daysSince = Calendar.current.dateComponents([.day], from: lastDay, to: today).day ?? 0
            
            if daysSince == 0 {
                // Same day, no change
                return
            } else if daysSince == 1 {
                // Consecutive day
                userProgress.streakDays += 1
            } else {
                // Streak broken
                userProgress.streakDays = 1
            }
        } else {
            // First completion
            userProgress.streakDays = 1
        }
        
        userProgress.lastCompletionDate = Date()
        saveProgress()
    }
    
    func calculateXPForActivity(_ activity: Activity, goal: Goal?) -> Int {
        var baseXP = 50
        
        // Distance bonus (10 XP per km, capped at 100)
        let distanceKm = activity.distanceMetersMatched / 1000.0
        let distanceBonus = min(100, Int(distanceKm * 10))
        baseXP += distanceBonus
        
        // Confidence multiplier (0.8 to 1.2)
        let confidenceMultiplier = 0.8 + (activity.confidenceScoreAvg * 0.4)
        let finalXP = Int(Double(baseXP) * confidenceMultiplier)
        
        return finalXP
    }
    
    func completeGoal(_ goal: Goal, activity: Activity) {
        let xp = calculateXPForActivity(activity, goal: goal)
        awardXP(xp, reason: "Goal completed: \(goal.title)")
        updateStreak()
        
        // Create reward event
        let event = RewardEvent(
            id: UUID(),
            timestamp: Date(),
            type: .goalCompleted,
            xpAwarded: xp,
            badgeId: nil
        )
        
        // Save reward event (for MVP, just log it)
        saveRewardEvent(event)
    }
    
    private func saveProgress() {
        if let encoded = try? JSONEncoder().encode(userProgress) {
            UserDefaults.standard.set(encoded, forKey: "userProgress")
        }
    }
    
    private func saveRewardEvent(_ event: RewardEvent) {
        // For MVP, store in UserDefaults array
        var events: [RewardEvent] = []
        if let data = UserDefaults.standard.data(forKey: "rewardEvents"),
           let decoded = try? JSONDecoder().decode([RewardEvent].self, from: data) {
            events = decoded
        }
        events.append(event)
        if let encoded = try? JSONEncoder().encode(events) {
            UserDefaults.standard.set(encoded, forKey: "rewardEvents")
        }
    }
    
    func getXPForNextLevel() -> Int {
        return (userProgress.level * 100) - userProgress.currentXP
    }
    
    func getXPProgress() -> Double {
        let currentLevelXP = (userProgress.level - 1) * 100
        let progressXP = userProgress.currentXP - currentLevelXP
        return Double(progressXP) / 100.0
    }
}
