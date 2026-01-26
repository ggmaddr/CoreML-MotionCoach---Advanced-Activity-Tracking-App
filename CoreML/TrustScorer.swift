import Foundation
import CoreLocation

class TrustScorer {
    /// Calculate trust score based on GPS accuracy and movement patterns
    static func calculateTrustScore(
        accuracy: Double,
        speed: Double,
        previousSpeed: Double?,
        course: Double,
        previousCourse: Double?
    ) -> Double {
        // Base score from accuracy (better accuracy = higher score)
        var score = max(0, 1.0 - (accuracy / 50.0)) // 50m accuracy = 0, perfect = 1
        
        // Speed sanity check
        let maxReasonableSpeed: Double = 12.0 // m/s for running/hiking
        if speed > maxReasonableSpeed {
            score *= 0.5 // Penalize unrealistic speeds
        }
        
        // Speed consistency
        if let prevSpeed = previousSpeed {
            let speedChange = abs(speed - prevSpeed)
            if speedChange > 5.0 { // Sudden speed change
                score *= 0.8
            }
        }
        
        // Course consistency (heading changes)
        if let prevCourse = previousCourse {
            let courseChange = abs(course - prevCourse)
            if courseChange > 90 && courseChange < 270 { // Sharp turn
                score *= 0.9
            }
        }
        
        return min(1.0, max(0.0, score))
    }
    
    /// Detect anomalies in location samples
    static func detectAnomaly(
        current: CLLocation,
        previous: CLLocation?,
        maxSpeed: Double = 12.0
    ) -> Bool {
        guard let prev = previous else { return false }
        
        let distance = current.distance(from: prev)
        let timeInterval = current.timestamp.timeIntervalSince(prev.timestamp)
        
        guard timeInterval > 0 else { return false }
        
        let speed = distance / timeInterval
        
        // Anomaly if speed exceeds max reasonable speed
        if speed > maxSpeed {
            return true
        }
        
        // Anomaly if accuracy is very poor
        if current.horizontalAccuracy > 100 {
            return true
        }
        
        return false
    }
}
