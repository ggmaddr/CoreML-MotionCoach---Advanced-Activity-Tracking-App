import Foundation

/// Mock data for development and demo purposes
struct MockData {
    
    static let sampleGoals: [Goal] = [
        Goal(
            id: UUID(),
            title: "Morning Run",
            type: .distance,
            targetValue: 5000, // 5km
            timeframe: .today,
            allowedActivities: [.run],
            verificationMode: .matchedDistance,
            minConfidenceAvg: 0.7,
            status: .active,
            mustBeContinuous: true,
            minDuration: nil
        ),
        Goal(
            id: UUID(),
            title: "Weekly Cardio",
            type: .duration,
            targetValue: 3600, // 1 hour
            timeframe: .thisWeek,
            allowedActivities: [.run, .walk],
            verificationMode: .matchedDistance,
            minConfidenceAvg: 0.5,
            status: .active,
            mustBeContinuous: false,
            minDuration: nil
        ),
        Goal(
            id: UUID(),
            title: "Hill Workout",
            type: .elevationGain,
            targetValue: 200, // 200m elevation
            timeframe: .today,
            allowedActivities: [.hike, .run],
            verificationMode: .matchedDistance,
            minConfidenceAvg: 0.6,
            status: .active,
            mustBeContinuous: true,
            minDuration: 1800
        )
    ]
    
    static let sampleUserProgress = UserProgress(
        currentXP: 450,
        level: 5,
        streakDays: 15,
        lastCompletionDate: Date(),
        weeklyCompletionsCount: 6
    )
    
    static let achievements: [Achievement] = [
        Achievement(
            id: "bronze",
            name: "Bronze Runner",
            description: "Complete 5 activities 🎯",
            icon: "medal.fill",
            color: "bronze",
            unlockedDate: Calendar.current.date(byAdding: .day, value: -7, to: Date()),
            funnyComment: "You're on fire! 🔥 Well, not literally. That would be concerning."
        ),
        Achievement(
            id: "silver",
            name: "Silver Speedster",
            description: "Run 50km total 🏃",
            icon: "bolt.circle.fill",
            color: "silver",
            unlockedDate: Calendar.current.date(byAdding: .day, value: -4, to: Date()),
            funnyComment: "Speedy Gonzales called. He wants tips! 🐭💨"
        ),
        Achievement(
            id: "gold",
            name: "Gold Gladiator",
            description: "Maintain 7-day streak 🔥",
            icon: "crown.fill",
            color: "gold",
            unlockedDate: Calendar.current.date(byAdding: .day, value: -1, to: Date()),
            funnyComment: "You're basically a fitness superhero now! 🦸‍♂️✨"
        ),
        Achievement(
            id: "ruby",
            name: "Ruby Warrior",
            description: "Run 100km total 🎖️",
            icon: "star.fill",
            color: "ruby",
            unlockedDate: nil,
            funnyComment: "Almost there! Your legs might hate you, but we love you! 💪❤️"
        )
    ]
    
    static let sampleActivities: [Activity] = [
        Activity(
            id: UUID(),
            startTime: Calendar.current.date(byAdding: .hour, value: -2, to: Date())!,
            endTime: Date(),
            activityType: .run,
            rawLocations: [],
            fusedPath: [],
            mapMatchedPath: [],
            distanceMetersRaw: 5240,
            distanceMetersMatched: 5180,
            durationSeconds: 1800,
            elevationGainMeters: 45,
            avgPaceSecPerKm: 347,
            confidenceScoreAvg: 0.87,
            gpsAnomalyCount: 2,
            steps: 6420,
            cadenceAvg: 175,
            metadata: ["deviceModel": "iPhone", "iOSVersion": "26.0"]
        ),
        Activity(
            id: UUID(),
            startTime: Calendar.current.date(byAdding: .day, value: -1, to: Date())!,
            endTime: Calendar.current.date(byAdding: .day, value: -1, to: Date())!,
            activityType: .walk,
            rawLocations: [],
            fusedPath: [],
            mapMatchedPath: [],
            distanceMetersRaw: 3200,
            distanceMetersMatched: 3150,
            durationSeconds: 2400,
            elevationGainMeters: 12,
            avgPaceSecPerKm: 762,
            confidenceScoreAvg: 0.92,
            gpsAnomalyCount: 0,
            steps: 4200,
            cadenceAvg: 105,
            metadata: ["deviceModel": "iPhone", "iOSVersion": "26.0"]
        )
    ]
}

struct Achievement: Identifiable, Codable {
    let id: String
    let name: String
    let description: String
    let icon: String
    let color: String
    let unlockedDate: Date?
    let funnyComment: String
    
    var isUnlocked: Bool {
        unlockedDate != nil
    }
    
    var daysAgo: Int? {
        guard let date = unlockedDate else { return nil }
        return Calendar.current.dateComponents([.day], from: date, to: Date()).day
    }
}
