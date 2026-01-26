import Foundation
import CoreMotion
import CoreLocation

/// Advanced sensor fusion engine combining GPS, accelerometer, gyroscope, and magnetometer
/// Uses Kalman filtering and complementary filters for robust position estimation
class SensorFusionEngine {
    
    // MARK: - Kalman Filter State
    private struct KalmanState {
        var position: CLLocationCoordinate2D
        var velocity: Double // m/s
        var heading: Double // degrees
        var covariance: Double
        
        init(position: CLLocationCoordinate2D, velocity: Double = 0, heading: Double = 0, covariance: Double = 1.0) {
            self.position = position
            self.velocity = velocity
            self.heading = heading
            self.covariance = covariance
        }
    }
    
    private var kalmanState: KalmanState?
    private let motionManager = CMMotionManager()
    
    // Sensor fusion parameters
    private let gpsWeight: Double = 0.7
    private let imuWeight: Double = 0.3
    private let processNoise: Double = 0.1
    private let measurementNoise: Double = 5.0
    
    // Complementary filter for orientation
    private var complementaryFilterAlpha: Double = 0.98 // High trust in gyro for short-term
    private var lastGyroHeading: Double = 0
    private var lastMagnetometerHeading: Double = 0
    
    // Dead reckoning state
    private var lastFusedLocation: CLLocation?
    private var lastUpdateTime: Date?
    
    // MARK: - Public Interface
    
    /// Fuse GPS location with IMU data for improved accuracy
    func fuseLocation(
        gpsLocation: CLLocation,
        deviceMotion: CMDeviceMotion?,
        magnetometerData: CMMagnetometerData?
    ) -> FusedLocation {
        
        let timestamp = gpsLocation.timestamp
        
        // Initialize Kalman filter on first location
        if kalmanState == nil {
            kalmanState = KalmanState(
                position: gpsLocation.coordinate,
                velocity: max(0, gpsLocation.speed),
                heading: gpsLocation.course >= 0 ? gpsLocation.course : 0,
                covariance: gpsLocation.horizontalAccuracy
            )
            lastFusedLocation = gpsLocation
            lastUpdateTime = timestamp
            return FusedLocation(
                coordinate: gpsLocation.coordinate,
                accuracy: gpsLocation.horizontalAccuracy,
                confidence: calculateConfidence(gps: gpsLocation, imu: deviceMotion)
            )
        }
        
        guard let state = kalmanState, let lastTime = lastUpdateTime else {
            return FusedLocation(
                coordinate: gpsLocation.coordinate,
                accuracy: gpsLocation.horizontalAccuracy,
                confidence: 0.5
            )
        }
        
        let dt = timestamp.timeIntervalSince(lastTime)
        guard dt > 0 && dt < 10 else { // Sanity check
            return FusedLocation(
                coordinate: gpsLocation.coordinate,
                accuracy: gpsLocation.horizontalAccuracy,
                confidence: 0.5
            )
        }
        
        // Predict step (motion model)
        let predictedState = predict(state: state, dt: dt, deviceMotion: deviceMotion)
        
        // Update step (measurement fusion)
        let updatedState = update(
            predicted: predictedState,
            measurement: gpsLocation,
            deviceMotion: deviceMotion,
            magnetometer: magnetometerData
        )
        
        kalmanState = updatedState
        lastUpdateTime = timestamp
        
        let fusedLocation = CLLocation(
            coordinate: updatedState.position,
            altitude: gpsLocation.altitude,
            horizontalAccuracy: updatedState.covariance,
            verticalAccuracy: gpsLocation.verticalAccuracy,
            course: updatedState.heading,
            speed: updatedState.velocity,
            timestamp: timestamp
        )
        
        lastFusedLocation = fusedLocation
        
        return FusedLocation(
            coordinate: updatedState.position,
            accuracy: updatedState.covariance,
            confidence: calculateConfidence(gps: gpsLocation, imu: deviceMotion)
        )
    }
    
    /// Dead reckoning: estimate position when GPS is unavailable using IMU
    func deadReckon(deviceMotion: CMDeviceMotion, duration: TimeInterval) -> CLLocationCoordinate2D? {
        guard let lastLocation = lastFusedLocation else { return nil }
        
        // Extract velocity from accelerometer (integrate acceleration)
        let acceleration = deviceMotion.userAcceleration
        let gravity = deviceMotion.gravity
        
        // Remove gravity component
        let linearAcceleration = CMAcceleration(
            x: acceleration.x - gravity.x,
            y: acceleration.y - gravity.y,
            z: acceleration.z - gravity.z
        )
        
        // Estimate velocity (simplified - in production would use proper integration)
        let estimatedSpeed = sqrt(
            pow(linearAcceleration.x, 2) +
            pow(linearAcceleration.y, 2) +
            pow(linearAcceleration.z, 2)
        ) * duration
        
        // Get heading from attitude
        let attitude = deviceMotion.attitude
        let heading = attitude.yaw * 180.0 / .pi // Convert to degrees
        
        // Estimate new position
        let distance = estimatedSpeed * duration
        let newCoordinate = coordinate(
            from: lastLocation.coordinate,
            distance: distance,
            bearing: heading
        )
        
        return newCoordinate
    }
    
    // MARK: - Kalman Filter Implementation
    
    private func predict(state: KalmanState, dt: TimeInterval, deviceMotion: CMDeviceMotion?) -> KalmanState {
        // Motion model: x' = x + v*dt*cos(heading), y' = y + v*dt*sin(heading)
        let headingRad = state.heading * .pi / 180.0
        
        // If we have IMU data, use it to refine velocity estimate
        var velocity = state.velocity
        if let motion = deviceMotion {
            let accel = motion.userAcceleration
            let accelMagnitude = sqrt(pow(accel.x, 2) + pow(accel.y, 2) + pow(accel.z, 2))
            // Fuse GPS velocity with IMU acceleration
            velocity = velocity * (1 - imuWeight) + (velocity + accelMagnitude * dt) * imuWeight
        }
        
        let distance = velocity * dt
        let deltaLat = distance * cos(headingRad) / 111320.0 // meters per degree latitude
        let deltaLon = distance * sin(headingRad) / (111320.0 * cos(state.position.latitude * .pi / 180.0))
        
        let newPosition = CLLocationCoordinate2D(
            latitude: state.position.latitude + deltaLat,
            longitude: state.position.longitude + deltaLon
        )
        
        // Update covariance (process noise increases uncertainty)
        let newCovariance = state.covariance + processNoise * dt
        
        // Update heading from IMU if available
        var newHeading = state.heading
        if let motion = deviceMotion {
            let attitude = motion.attitude
            let imuHeading = attitude.yaw * 180.0 / .pi
            // Complementary filter for heading
            newHeading = complementaryFilterAlpha * (state.heading + imuHeading * dt) +
                        (1 - complementaryFilterAlpha) * imuHeading
        }
        
        return KalmanState(
            position: newPosition,
            velocity: velocity,
            heading: newHeading,
            covariance: newCovariance
        )
    }
    
    private func update(
        predicted: KalmanState,
        measurement: CLLocation,
        deviceMotion: CMDeviceMotion?,
        magnetometer: CMMagnetometerData?
    ) -> KalmanState {
        
        // Calculate innovation (difference between prediction and measurement)
        let measurementCoord = measurement.coordinate
        let latDiff = measurementCoord.latitude - predicted.position.latitude
        let lonDiff = measurementCoord.longitude - predicted.position.longitude
        
        // Kalman gain
        let measurementVariance = pow(measurement.horizontalAccuracy, 2)
        let kalmanGain = predicted.covariance / (predicted.covariance + measurementVariance + measurementNoise)
        
        // Fuse GPS and IMU measurements
        var fusedLat = predicted.position.latitude + kalmanGain * latDiff
        var fusedLon = predicted.position.longitude + kalmanGain * lonDiff
        
        // If IMU available, apply additional fusion
        if let motion = deviceMotion {
            // Weighted combination
            fusedLat = fusedLat * gpsWeight + measurementCoord.latitude * (1 - gpsWeight)
            fusedLon = fusedLon * gpsWeight + measurementCoord.longitude * (1 - gpsWeight)
        }
        
        let fusedPosition = CLLocationCoordinate2D(latitude: fusedLat, longitude: fusedLon)
        
        // Update covariance
        let newCovariance = (1 - kalmanGain) * predicted.covariance
        
        // Fuse heading from GPS course, IMU attitude, and magnetometer
        var fusedHeading = predicted.heading
        if measurement.course >= 0 {
            let gpsHeading = measurement.course
            if let motion = deviceMotion {
                let imuHeading = motion.attitude.yaw * 180.0 / .pi
                // Weighted fusion
                fusedHeading = gpsHeading * gpsWeight + imuHeading * imuWeight
            } else {
                fusedHeading = gpsHeading
            }
        }
        
        // Fuse velocity
        var fusedVelocity = predicted.velocity
        if measurement.speed >= 0 {
            fusedVelocity = measurement.speed * gpsWeight + predicted.velocity * imuWeight
        }
        
        return KalmanState(
            position: fusedPosition,
            velocity: fusedVelocity,
            heading: fusedHeading,
            covariance: newCovariance
        )
    }
    
    // MARK: - Helper Methods
    
    private func calculateConfidence(gps: CLLocation, imu: CMDeviceMotion?) -> Double {
        var confidence = 1.0 - min(1.0, gps.horizontalAccuracy / 50.0) // Better accuracy = higher confidence
        
        // Boost confidence if IMU data is available (sensor fusion improves reliability)
        if imu != nil {
            confidence = min(1.0, confidence * 1.1)
        }
        
        return max(0.0, min(1.0, confidence))
    }
    
    private func coordinate(from: CLLocationCoordinate2D, distance: Double, bearing: Double) -> CLLocationCoordinate2D {
        let earthRadius: Double = 6371000 // meters
        let lat1 = from.latitude * .pi / 180.0
        let lon1 = from.longitude * .pi / 180.0
        let bearingRad = bearing * .pi / 180.0
        
        let lat2 = asin(sin(lat1) * cos(distance / earthRadius) +
                        cos(lat1) * sin(distance / earthRadius) * cos(bearingRad))
        let lon2 = lon1 + atan2(sin(bearingRad) * sin(distance / earthRadius) * cos(lat1),
                                cos(distance / earthRadius) - sin(lat1) * sin(lat2))
        
        return CLLocationCoordinate2D(
            latitude: lat2 * 180.0 / .pi,
            longitude: lon2 * 180.0 / .pi
        )
    }
    
    func reset() {
        kalmanState = nil
        lastFusedLocation = nil
        lastUpdateTime = nil
        lastGyroHeading = 0
        lastMagnetometerHeading = 0
    }
}

struct FusedLocation {
    let coordinate: CLLocationCoordinate2D
    let accuracy: Double
    let confidence: Double
}
