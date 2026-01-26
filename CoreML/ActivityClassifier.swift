import Foundation
import CoreMotion
import CoreLocation
import CoreML

/// Core ML-powered activity classifier using sensor fusion
/// Classifies activities (walk, run, hike) from IMU and GPS patterns
class ActivityClassifier {
    
    // Feature extraction window
    private let windowSize: Int = 10 // samples
    private var featureBuffer: [ActivityFeatures] = []
    
    /// Extract features from sensor data for ML classification
    func extractFeatures(
        locations: [CLLocation],
        deviceMotion: CMDeviceMotion?,
        pedometerData: CMPedometerData?
    ) -> ActivityFeatures {
        
        guard !locations.isEmpty else {
            return ActivityFeatures.default
        }
        
        // GPS-based features
        let speeds = locations.compactMap { $0.speed >= 0 ? $0.speed : nil }
        let accuracies = locations.map { $0.horizontalAccuracy }
        let courses = locations.compactMap { $0.course >= 0 ? $0.course : nil }
        
        let avgSpeed = speeds.isEmpty ? 0 : speeds.reduce(0, +) / Double(speeds.count)
        let maxSpeed = speeds.max() ?? 0
        let speedVariance = calculateVariance(speeds)
        
        let avgAccuracy = accuracies.reduce(0, +) / Double(accuracies.count)
        
        // Course change rate (indicates turns/zigzag)
        let courseChanges = calculateCourseChanges(courses)
        
        // IMU-based features
        var accelMagnitude: Double = 0
        var accelVariance: Double = 0
        var stepFrequency: Double = 0
        
        if let motion = deviceMotion {
            let accel = motion.userAcceleration
            accelMagnitude = sqrt(pow(accel.x, 2) + pow(accel.y, 2) + pow(accel.z, 2))
            
            // Extract step frequency from accelerometer (peak detection)
            stepFrequency = estimateStepFrequency(from: motion)
        }
        
        // Pedometer features
        var stepsPerSecond: Double = 0
        if let pedometer = pedometerData, let cadence = pedometer.currentCadence?.doubleValue {
            stepsPerSecond = cadence
        }
        
        // Distance-based features
        var totalDistance: Double = 0
        if locations.count > 1 {
            for i in 1..<locations.count {
                totalDistance += locations[i].distance(from: locations[i-1])
            }
        }
        
        let duration = locations.last!.timestamp.timeIntervalSince(locations.first!.timestamp)
        let avgPace = duration > 0 && totalDistance > 0 ? (duration / totalDistance) * 1000.0 : 0
        
        return ActivityFeatures(
            avgSpeed: avgSpeed,
            maxSpeed: maxSpeed,
            speedVariance: speedVariance,
            avgAccuracy: avgAccuracy,
            courseChangeRate: courseChanges,
            accelMagnitude: accelMagnitude,
            accelVariance: accelVariance,
            stepFrequency: stepFrequency,
            stepsPerSecond: stepsPerSecond,
            totalDistance: totalDistance,
            duration: duration,
            avgPace: avgPace
        )
    }
    
    /// Classify activity using rule-based + ML-inspired approach
    /// In production, this would use a trained Core ML model
    func classify(features: ActivityFeatures) -> ActivityType {
        // Rule-based classification (can be replaced with Core ML model)
        
        // Running: high speed, high step frequency, consistent pace
        if features.avgSpeed > 2.5 && // > 9 km/h
           features.stepFrequency > 2.5 && // > 2.5 Hz
           features.speedVariance < 1.0 { // consistent speed
            return .run
        }
        
        // Walking: moderate speed, moderate step frequency
        if features.avgSpeed > 0.8 && features.avgSpeed < 2.5 && // 2.9-9 km/h
           features.stepFrequency > 1.5 && features.stepFrequency < 2.5 {
            return .walk
        }
        
        // Hiking: slower, more variable, often with elevation changes
        if features.avgSpeed > 0.5 && features.avgSpeed < 1.5 && // 1.8-5.4 km/h
           features.courseChangeRate > 0.3 { // more turns/zigzag
            return .hike
        }
        
        return .unknown
    }
    
    /// Classify using sliding window for real-time detection
    func classifyWithWindow(features: ActivityFeatures) -> ActivityType {
        featureBuffer.append(features)
        if featureBuffer.count > windowSize {
            featureBuffer.removeFirst()
        }
        
        // Use majority vote from window
        let classifications = featureBuffer.map { classify(features: $0) }
        let counts = Dictionary(grouping: classifications, by: { $0 })
        return counts.max(by: { $0.value.count < $1.value.count })?.key ?? .unknown
    }
    
    // MARK: - Helper Methods
    
    private func calculateVariance(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        let squaredDiffs = values.map { pow($0 - mean, 2) }
        return squaredDiffs.reduce(0, +) / Double(values.count)
    }
    
    private func calculateCourseChanges(_ courses: [Double]) -> Double {
        guard courses.count > 1 else { return 0 }
        var changes: [Double] = []
        for i in 1..<courses.count {
            let change = abs(courses[i] - courses[i-1])
            let normalizedChange = min(change, 360 - change) // Handle wrap-around
            changes.append(normalizedChange)
        }
        return changes.reduce(0, +) / Double(changes.count)
    }
    
    private func estimateStepFrequency(from motion: CMDeviceMotion) -> Double {
        // Simplified step frequency estimation from accelerometer
        // In production, would use FFT or peak detection
        let accel = motion.userAcceleration
        let magnitude = sqrt(pow(accel.x, 2) + pow(accel.y, 2) + pow(accel.z, 2))
        
        // Heuristic: higher magnitude = higher step frequency
        // This is simplified - real implementation would use signal processing
        return min(3.0, max(1.0, magnitude * 2.0))
    }
    
    func reset() {
        featureBuffer.removeAll()
    }
}

struct ActivityFeatures {
    let avgSpeed: Double // m/s
    let maxSpeed: Double // m/s
    let speedVariance: Double
    let avgAccuracy: Double // meters
    let courseChangeRate: Double // degrees per sample
    let accelMagnitude: Double // m/s²
    let accelVariance: Double
    let stepFrequency: Double // Hz
    let stepsPerSecond: Double
    let totalDistance: Double // meters
    let duration: Double // seconds
    let avgPace: Double // seconds per km
    
    static let `default` = ActivityFeatures(
        avgSpeed: 0,
        maxSpeed: 0,
        speedVariance: 0,
        avgAccuracy: 100,
        courseChangeRate: 0,
        accelMagnitude: 0,
        accelVariance: 0,
        stepFrequency: 0,
        stepsPerSecond: 0,
        totalDistance: 0,
        duration: 0,
        avgPace: 0
    )
}
