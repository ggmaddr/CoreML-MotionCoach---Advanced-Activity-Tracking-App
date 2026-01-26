import Foundation

/// LLM-powered insights engine for activity analysis
/// Generates natural language summaries and coaching insights from sensor data
class LLMInsightsEngine {
    
    /// Generate activity summary using structured data analysis
    /// In production, this would call an LLM API (OpenAI, Anthropic, etc.)
    func generateActivityInsights(activity: Activity) -> ActivityInsights {
        var insights: [String] = []
        var coachingTips: [String] = []
        
        // Analyze pace consistency
        if let pace = activity.avgPaceSecPerKm {
            let paceMin = pace / 60.0
            if paceMin < 5.0 {
                insights.append("Excellent pace! You maintained a strong \(String(format: "%.1f", paceMin)) min/km average.")
                coachingTips.append("Consider maintaining this pace for longer distances to build endurance.")
            } else if paceMin < 7.0 {
                insights.append("Solid steady pace of \(String(format: "%.1f", paceMin)) min/km.")
                coachingTips.append("Try interval training to improve your speed.")
            } else {
                insights.append("Comfortable pace of \(String(format: "%.1f", paceMin)) min/km - great for building base fitness.")
            }
        }
        
        // Analyze distance and duration
        let distanceKm = activity.distanceMetersMatched / 1000.0
        let durationMin = activity.durationSeconds / 60.0
        
        if distanceKm > 0 {
            insights.append("Covered \(String(format: "%.2f", distanceKm)) km in \(String(format: "%.0f", durationMin)) minutes.")
            
            if distanceKm >= 5.0 {
                insights.append("Impressive distance! You're building strong endurance.")
            }
        }
        
        // Analyze confidence and tracking quality
        if activity.confidenceScoreAvg >= 0.8 {
            insights.append("High-quality tracking with \(Int(activity.confidenceScoreAvg * 100))% confidence.")
        } else if activity.confidenceScoreAvg < 0.6 {
            insights.append("Tracking quality was lower than usual. Consider running in areas with better GPS coverage.")
            coachingTips.append("Urban canyons or dense tree cover can affect GPS accuracy.")
        }
        
        // Analyze steps and cadence
        if activity.steps > 0 {
            let stepsPerKm = Double(activity.steps) / distanceKm
            insights.append("\(activity.steps) steps at \(String(format: "%.0f", stepsPerKm)) steps/km.")
            
            if let cadence = activity.cadenceAvg {
                if cadence > 180 {
                    insights.append("Excellent cadence of \(String(format: "%.0f", cadence)) steps/min - you're running efficiently!")
                } else if cadence < 160 {
                    coachingTips.append("Try increasing your cadence to 170-180 steps/min for better running economy.")
                }
            }
        }
        
        // Analyze anomalies
        if activity.gpsAnomalyCount == 0 {
            insights.append("Perfect tracking with no GPS anomalies detected.")
        } else if activity.gpsAnomalyCount <= 2 {
            insights.append("Minor GPS fluctuations detected, but overall tracking was reliable.")
        } else {
            insights.append("Several GPS anomalies detected - consider running in areas with better satellite visibility.")
        }
        
        // Activity type specific insights
        switch activity.activityType {
        case .run:
            if distanceKm >= 10 {
                insights.append("Great long run! You're building serious endurance.")
            }
            coachingTips.append("Remember to hydrate and fuel properly for runs over 60 minutes.")
        case .walk:
            insights.append("Walking is excellent for active recovery and building aerobic base.")
            coachingTips.append("Try adding short bursts of faster walking to increase intensity.")
        case .hike:
            insights.append("Hiking builds strength and endurance while enjoying nature.")
            if let elevation = activity.elevationGainMeters {
                insights.append("Climbed \(String(format: "%.0f", elevation)) meters - great elevation gain!")
            }
        case .unknown:
            break
        }
        
        // Generate motivational message
        let motivationalMessage = generateMotivationalMessage(
            distance: distanceKm,
            duration: durationMin,
            activityType: activity.activityType
        )
        
        return ActivityInsights(
            summary: insights.joined(separator: " "),
            coachingTips: coachingTips,
            motivationalMessage: motivationalMessage,
            keyMetrics: extractKeyMetrics(activity: activity)
        )
    }
    
    /// Generate personalized coaching note
    func generateCoachNote(activity: Activity, goal: Goal?) -> String {
        var note = "Great work on your "
        
        switch activity.activityType {
        case .run:
            note += "run"
        case .walk:
            note += "walk"
        case .hike:
            note += "hike"
        default:
            note += "activity"
        }
        
        note += "! "
        
        if let goal = goal {
            note += "You completed your goal: \(goal.title). "
        }
        
        let distanceKm = activity.distanceMetersMatched / 1000.0
        if distanceKm > 0 {
            note += "You covered \(String(format: "%.2f", distanceKm)) km"
            
            if let pace = activity.avgPaceSecPerKm {
                let paceMin = pace / 60.0
                note += " at \(String(format: "%.1f", paceMin)) min/km pace"
            }
            
            note += ". "
        }
        
        if activity.confidenceScoreAvg >= 0.8 {
            note += "Your tracking quality was excellent. "
        }
        
        note += "Keep building those healthy habits!"
        
        return note
    }
    
    // MARK: - Private Helpers
    
    private func generateMotivationalMessage(
        distance: Double,
        duration: Double,
        activityType: ActivityType
    ) -> String {
        if distance >= 10 {
            return "Outstanding effort! You're pushing your limits and building incredible endurance. Every step counts!"
        } else if distance >= 5 {
            return "Strong performance! You're consistently building your fitness. Keep up the great work!"
        } else if distance >= 2 {
            return "Nice work! You're building healthy habits one run at a time. Consistency is key!"
        } else {
            return "Every journey starts with a single step. You're moving in the right direction!"
        }
    }
    
    private func extractKeyMetrics(activity: Activity) -> [String: String] {
        var metrics: [String: String] = [:]
        
        let distanceKm = activity.distanceMetersMatched / 1000.0
        metrics["Distance"] = String(format: "%.2f km", distanceKm)
        
        let durationMin = activity.durationSeconds / 60.0
        metrics["Duration"] = String(format: "%.0f min", durationMin)
        
        if let pace = activity.avgPaceSecPerKm {
            let paceMin = pace / 60.0
            metrics["Pace"] = String(format: "%.1f min/km", paceMin)
        }
        
        metrics["Steps"] = "\(activity.steps)"
        
        if let cadence = activity.cadenceAvg {
            metrics["Cadence"] = String(format: "%.0f spm", cadence)
        }
        
        metrics["Confidence"] = String(format: "%.0f%%", activity.confidenceScoreAvg * 100)
        
        return metrics
    }
}

struct ActivityInsights {
    let summary: String
    let coachingTips: [String]
    let motivationalMessage: String
    let keyMetrics: [String: String]
}
