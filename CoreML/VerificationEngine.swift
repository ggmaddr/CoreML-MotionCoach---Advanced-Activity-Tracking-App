import Foundation

struct VerificationResult {
    let passed: Bool
    let reasons: [String]
    let usedDistanceType: VerificationMode
}

class VerificationEngine {
    static func verify(goal: Goal, activity: Activity) -> VerificationResult {
        var reasons: [String] = []
        var passed = true
        
        // Check activity type matches
        if !goal.allowedActivities.contains(activity.activityType) {
            passed = false
            reasons.append("Activity type \(activity.activityType.rawValue) not allowed")
        }
        
        // Check confidence threshold
        if activity.confidenceScoreAvg < goal.minConfidenceAvg {
            passed = false
            reasons.append("Confidence score \(String(format: "%.2f", activity.confidenceScoreAvg)) below threshold \(String(format: "%.2f", goal.minConfidenceAvg))")
        }
        
        // Check anomaly count
        if activity.gpsAnomalyCount > 3 {
            passed = false
            reasons.append("Too many GPS anomalies: \(activity.gpsAnomalyCount)")
        }
        
        // Check continuity (if required)
        if goal.mustBeContinuous {
            // Simple check: ensure duration matches expected time for distance
            let expectedDuration = activity.distanceMetersMatched / 3.0 // Assume ~3 m/s average
            let actualDuration = activity.durationSeconds
            if abs(actualDuration - expectedDuration) > expectedDuration * 0.5 {
                passed = false
                reasons.append("Activity appears non-continuous")
            }
        }
        
        // Check minimum duration if specified
        if let minDuration = goal.minDuration, activity.durationSeconds < minDuration {
            passed = false
            reasons.append("Duration \(String(format: "%.0f", activity.durationSeconds))s below minimum \(String(format: "%.0f", minDuration))s")
        }
        
        // Check goal type specific requirements
        let usedDistance = goal.verificationMode == .matchedDistance ? activity.distanceMetersMatched : activity.distanceMetersRaw
        
        switch goal.type {
        case .distance:
            if usedDistance < goal.targetValue {
                passed = false
                reasons.append("Distance \(String(format: "%.2f", usedDistance))m below target \(String(format: "%.2f", goal.targetValue))m")
            }
        case .duration:
            if activity.durationSeconds < goal.targetValue {
                passed = false
                reasons.append("Duration \(String(format: "%.0f", activity.durationSeconds))s below target \(String(format: "%.0f", goal.targetValue))s")
            }
        case .elevationGain:
            if let elevation = activity.elevationGainMeters, elevation < goal.targetValue {
                passed = false
                reasons.append("Elevation gain \(String(format: "%.0f", elevation))m below target \(String(format: "%.0f", goal.targetValue))m")
            } else if activity.elevationGainMeters == nil {
                passed = false
                reasons.append("Elevation data not available")
            }
        case .sessionsCount:
            // For MVP, this would require tracking multiple sessions
            reasons.append("Sessions count verification not implemented in MVP")
        }
        
        if passed {
            reasons.append("All verification checks passed")
        }
        
        return VerificationResult(
            passed: passed,
            reasons: reasons,
            usedDistanceType: goal.verificationMode
        )
    }
}
