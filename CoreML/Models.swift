import Foundation
import CoreLocation

enum ActivityType: String, Codable, CaseIterable {
    case walk, run, hike, unknown
}

enum LocationSource: String, Codable {
    case gps, wifi, cell
}

enum MotionActivityType: String, Codable {
    case walking, running, automotive, stationary
}

enum GoalType: String, Codable, CaseIterable {
    case distance, duration, elevationGain, sessionsCount
}

enum Timeframe: String, Codable, CaseIterable {
    case today, thisWeek, customRange
}

enum VerificationMode: String, Codable {
    case matchedDistance, rawDistance
}

enum GoalStatus: String, Codable {
    case active, completed, expired
}

enum RewardType: String, Codable {
    case goalCompleted, streakMilestone, firstRun, weeklyConsistency
}

struct LocationSample: Codable, Identifiable {
    var id = UUID()
    var timestamp: Date
    var lat: Double
    var lon: Double
    var horizontalAccuracy: Double
    var speed: Double
    var course: Double
    var altitude: Double?
    var source: LocationSource
    var trustScore: Double
}

struct MotionSample: Codable, Identifiable {
    var id = UUID()
    var windowStart: Date
    var windowEnd: Date
    var stepsDelta: Int
    var cadence: Double
    var motionActivity: MotionActivityType
    var heading: Double?
}

struct Activity: Codable, Identifiable {
    var id = UUID()
    var startTime: Date
    var endTime: Date?
    var activityType: ActivityType
    var rawLocations: [LocationSample] = []
    var fusedPath: [CLLocationCoordinate2D] = []
    var mapMatchedPath: [CLLocationCoordinate2D] = []
    var distanceMetersRaw: Double = 0
    var distanceMetersMatched: Double = 0
    var durationSeconds: Double = 0
    var elevationGainMeters: Double?
    var avgPaceSecPerKm: Double?
    var confidenceScoreAvg: Double
    var gpsAnomalyCount: Int
    var steps: Int
    var cadenceAvg: Double?
    var metadata: [String: String] = [:]
}

struct Goal: Codable, Identifiable {
    var id = UUID()
    var title: String
    var type: GoalType
    var targetValue: Double
    var timeframe: Timeframe
    var allowedActivities: [ActivityType]
    var verificationMode: VerificationMode
    var minConfidenceAvg: Double
    var status: GoalStatus
    var mustBeContinuous: Bool
    var minDuration: Double?
}

struct RewardEvent: Codable, Identifiable {
    var id = UUID()
    var timestamp: Date
    var type: RewardType
    var xpAwarded: Int
    var badgeId: String?
}

struct UserProgress: Codable {
    var currentXP: Int
    var level: Int
    var streakDays: Int
    var lastCompletionDate: Date?
    var weeklyCompletionsCount: Int
}
