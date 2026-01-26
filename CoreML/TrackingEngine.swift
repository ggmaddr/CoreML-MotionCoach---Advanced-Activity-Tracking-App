import Foundation
import CoreLocation
import CoreMotion
import Combine
import UIKit
import MapKit

@MainActor
class TrackingEngine: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var isTracking = false
    @Published var route: [CLLocationCoordinate2D] = []
    @Published var totalDistance: Double = 0
    @Published var elapsedTime: TimeInterval = 0
    @Published var currentLocation: CLLocationCoordinate2D?
    @Published var activityState: ActivityState = .idle
    @Published var lastError: String?
    @Published var confidenceScore: Double = 0.5
    @Published var steps: Int = 0
    @Published var cadence: Double = 0
    @Published var detectedActivityType: ActivityType = .unknown
    @Published var currentActivity: Activity?
    
    enum ActivityState { case idle, tracking, summarizing }
    
    private var locationManager: CLLocationManager?
    private var motionActivityManager: CMMotionActivityManager?
    private var pedometer: CMPedometer?
    private var motionManager: CMMotionManager?
    private var timer: Timer?
    private var startTime: Date?
    private var lastLocation: CLLocation?
    private var locationSamples: [LocationSample] = []
    private var motionSamples: [MotionSample] = []
    private var trustScores: [Double] = []
    private var anomalyCount = 0
    private var lastSpeed: Double?
    private var lastCourse: Double?
    
    // Advanced sensor fusion components
    private let sensorFusion = SensorFusionEngine()
    private let activityClassifier = ActivityClassifier()
    private let advancedMapMatching = AdvancedMapMatching()
    private var deviceMotionSamples: [CMDeviceMotion] = []
    private var pedometerDataSamples: [CMPedometerData] = []
    
    override init() {
        super.init()
    }
    
    func startTracking() {
        // Reset state
        route.removeAll()
        totalDistance = 0
        elapsedTime = 0
        locationSamples.removeAll()
        motionSamples.removeAll()
        deviceMotionSamples.removeAll()
        pedometerDataSamples.removeAll()
        trustScores.removeAll()
        anomalyCount = 0
        steps = 0
        cadence = 0
        confidenceScore = 0.5
        detectedActivityType = .unknown
        sensorFusion.reset()
        activityClassifier.reset()
        
        // Setup Location Manager
        locationManager = CLLocationManager()
        locationManager?.delegate = self
        locationManager?.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager?.activityType = .fitness
        // Only enable background updates if authorized
        #if !targetEnvironment(simulator)
        if CLLocationManager.authorizationStatus() == .authorizedAlways {
            locationManager?.allowsBackgroundLocationUpdates = true
        }
        #endif
        locationManager?.pausesLocationUpdatesAutomatically = true
        
        let authStatus = locationManager?.authorizationStatus ?? .notDetermined
        if authStatus == .notDetermined {
            locationManager?.requestWhenInUseAuthorization()
        } else if authStatus == .authorizedWhenInUse || authStatus == .authorizedAlways {
            locationManager?.startUpdatingLocation()
        }
        
        // Setup Motion Activity Manager
        motionActivityManager = CMMotionActivityManager()
        if CMMotionActivityManager.isActivityAvailable() {
            motionActivityManager?.startActivityUpdates(to: .main) { [weak self] activity in
                guard let activity = activity else { return }
                self?.updateActivityType(from: activity)
            }
        }
        
        // Setup Device Motion Manager for advanced sensor fusion
        motionManager = CMMotionManager()
        motionManager?.deviceMotionUpdateInterval = 0.1 // 10 Hz
        if let motionManager = motionManager, motionManager.isDeviceMotionAvailable {
            motionManager.startDeviceMotionUpdates(using: .xMagneticNorthZVertical, to: .main) { [weak self] motion, error in
                guard let motion = motion, error == nil else { return }
                self?.deviceMotionSamples.append(motion)
                // Keep only recent samples (last 100)
                if self?.deviceMotionSamples.count ?? 0 > 100 {
                    self?.deviceMotionSamples.removeFirst()
                }
            }
        }
        
        // Setup Pedometer
        pedometer = CMPedometer()
        if CMPedometer.isStepCountingAvailable() {
            startTime = Date()
            pedometer?.startUpdates(from: startTime!) { [weak self] data, error in
                guard let data = data, error == nil else { return }
                self?.steps = data.numberOfSteps.intValue
                if let cadenceValue = data.currentCadence?.doubleValue {
                    self?.cadence = cadenceValue * 60.0 // Convert to steps/min
                }
                self?.pedometerDataSamples.append(data)
                // Keep only recent samples
                if self?.pedometerDataSamples.count ?? 0 > 100 {
                    self?.pedometerDataSamples.removeFirst()
                }
            }
        }
        
        // Create activity draft
        currentActivity = Activity(
            id: UUID(),
            startTime: Date(),
            endTime: nil,
            activityType: .unknown,
            rawLocations: [],
            fusedPath: [],
            mapMatchedPath: [],
            distanceMetersRaw: 0,
            distanceMetersMatched: 0,
            durationSeconds: 0,
            elevationGainMeters: nil,
            avgPaceSecPerKm: nil,
            confidenceScoreAvg: 0.5,
            gpsAnomalyCount: 0,
            steps: 0,
            cadenceAvg: nil,
            metadata: [
                "deviceModel": UIDevice.current.model,
                "iOSVersion": UIDevice.current.systemVersion
            ]
        )
        
        isTracking = true
        activityState = .tracking
        startTime = Date()
        
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }
    
    func stopTracking() {
        locationManager?.stopUpdatingLocation()
        motionActivityManager?.stopActivityUpdates()
        motionManager?.stopDeviceMotionUpdates()
        pedometer?.stopUpdates()
        timer?.invalidate()
        timer = nil
        
        isTracking = false
        activityState = .summarizing
        
        // Don't process yet - wait for resume or reset
    }
    
    func resumeTracking() {
        // Resume tracking from paused state
        isTracking = true
        activityState = .tracking
        
        // Restart location updates
        locationManager?.startUpdatingLocation()
        
        // Restart motion updates
        motionActivityManager?.startActivityUpdates(to: .main) { [weak self] activity in
            guard let activity = activity else { return }
            self?.updateActivityType(from: activity)
        }
        
        // Restart device motion
        if let motionManager = motionManager, motionManager.isDeviceMotionAvailable {
            motionManager.startDeviceMotionUpdates(using: .xMagneticNorthZVertical, to: .main) { [weak self] motion, error in
                guard let motion = motion, error == nil else { return }
                self?.deviceMotionSamples.append(motion)
                if self?.deviceMotionSamples.count ?? 0 > 100 {
                    self?.deviceMotionSamples.removeFirst()
                }
            }
        }
        
        // Restart pedometer
        if CMPedometer.isStepCountingAvailable(), let start = startTime {
            pedometer?.startUpdates(from: start) { [weak self] data, error in
                guard let data = data, error == nil else { return }
                self?.steps = data.numberOfSteps.intValue
                if let cadenceValue = data.currentCadence?.doubleValue {
                    self?.cadence = cadenceValue * 60.0
                }
                self?.pedometerDataSamples.append(data)
                if self?.pedometerDataSamples.count ?? 0 > 100 {
                    self?.pedometerDataSamples.removeFirst()
                }
            }
        }
        
        // Restart timer
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }
    
    func finishActivity() {
        guard let start = startTime else { return }
        let duration = Date().timeIntervalSince(start)
        
        // Process and match route with advanced algorithms
        Task {
            await processActivityAdvanced(duration: duration)
        }
    }
    
    func reset() {
        // Stop everything first
        locationManager?.stopUpdatingLocation()
        motionActivityManager?.stopActivityUpdates()
        motionManager?.stopDeviceMotionUpdates()
        pedometer?.stopUpdates()
        timer?.invalidate()
        timer = nil
        
        // Clear all data
        route.removeAll()
        totalDistance = 0
        elapsedTime = 0
        locationSamples.removeAll()
        motionSamples.removeAll()
        deviceMotionSamples.removeAll()
        pedometerDataSamples.removeAll()
        trustScores.removeAll()
        anomalyCount = 0
        steps = 0
        cadence = 0
        confidenceScore = 0.5
        isTracking = false
        activityState = .idle
        lastError = nil
        currentActivity = nil
        startTime = nil
        lastLocation = nil
        lastSpeed = nil
        lastCourse = nil
        sensorFusion.reset()
        activityClassifier.reset()
    }
    
    private func tick() {
        guard isTracking, let start = startTime else { return }
        elapsedTime = Date().timeIntervalSince(start)
        
        // Update confidence score (average of recent trust scores)
        if !trustScores.isEmpty {
            let recentScores = Array(trustScores.suffix(10))
            confidenceScore = recentScores.reduce(0, +) / Double(recentScores.count)
        }
    }
    
    private func updateActivityType(from cmActivity: CMMotionActivity) {
        if cmActivity.running {
            detectedActivityType = .run
        } else if cmActivity.walking {
            detectedActivityType = .walk
        } else if cmActivity.automotive {
            detectedActivityType = .unknown // Don't count automotive
        } else {
            detectedActivityType = .unknown
        }
    }
    
    private func processActivity(duration: TimeInterval) {
        guard var activity = currentActivity else { return }
        
        // Calculate fused path (smoothed raw locations)
        let rawCoords = locationSamples.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) }
        let fusedCoords = MapMatching.smoothPath(rawCoords)
        
        // Calculate map matched path
        let matchedCoords = MapMatching.matchRoute(fusedCoords)
        
        // Calculate distances
        let rawDistance = MapMatching.calculateDistance(rawCoords)
        let matchedDistance = MapMatching.calculateDistance(matchedCoords)
        
        // Calculate average confidence
        let avgConfidence = trustScores.isEmpty ? 0.5 : trustScores.reduce(0, +) / Double(trustScores.count)
        
        // Calculate pace
        let pace = duration > 0 && matchedDistance > 0 ? (duration / matchedDistance) * 1000.0 : nil
        
        // Calculate average cadence
        let avgCadence = motionSamples.isEmpty ? nil : motionSamples.compactMap { $0.cadence }.reduce(0, +) / Double(motionSamples.count)
        
        // Update activity
        activity.endTime = Date()
        activity.activityType = detectedActivityType
        activity.rawLocations = locationSamples
        activity.fusedPath = fusedCoords
        activity.mapMatchedPath = matchedCoords
        activity.distanceMetersRaw = rawDistance
        activity.distanceMetersMatched = matchedDistance
        activity.durationSeconds = duration
        activity.confidenceScoreAvg = avgConfidence
        activity.gpsAnomalyCount = anomalyCount
        activity.steps = steps
        activity.cadenceAvg = avgCadence
        activity.avgPaceSecPerKm = pace
        
        currentActivity = activity
    }
    
    /// Advanced processing with sensor fusion and ML classification
    private func processActivityAdvanced(duration: TimeInterval) async {
        guard var activity = currentActivity else { return }
        
        // Convert location samples to CLLocation for sensor fusion
        let locations = locationSamples.map { sample in
            CLLocation(
                coordinate: CLLocationCoordinate2D(latitude: sample.lat, longitude: sample.lon),
                altitude: sample.altitude ?? 0,
                horizontalAccuracy: sample.horizontalAccuracy,
                verticalAccuracy: sample.horizontalAccuracy,
                course: sample.course,
                speed: sample.speed,
                timestamp: sample.timestamp
            )
        }
        
        // Apply sensor fusion to improve location accuracy
        var fusedLocations: [CLLocation] = []
        for (index, location) in locations.enumerated() {
            let deviceMotion = index < deviceMotionSamples.count ? deviceMotionSamples[index] : nil
            let magnetometer: CMMagnetometerData? = nil // Would need separate magnetometer setup
            
            let fused = sensorFusion.fuseLocation(
                gpsLocation: location,
                deviceMotion: deviceMotion,
                magnetometerData: magnetometer
            )
            
            let fusedLocation = CLLocation(
                coordinate: fused.coordinate,
                altitude: location.altitude,
                horizontalAccuracy: fused.accuracy,
                verticalAccuracy: location.verticalAccuracy,
                course: location.course,
                speed: location.speed,
                timestamp: location.timestamp
            )
            fusedLocations.append(fusedLocation)
        }
        
        let fusedCoords = fusedLocations.map { $0.coordinate }
        
        // Use advanced map matching with MapKit routing
        let matchedCoords = await advancedMapMatching.matchToRoads(
            coordinates: fusedCoords,
            transportType: detectedActivityType == .run ? .walking : .walking
        )
        
        // ML-based activity classification
        let latestPedometer = pedometerDataSamples.last
        let features = activityClassifier.extractFeatures(
            locations: locations,
            deviceMotion: deviceMotionSamples.last,
            pedometerData: latestPedometer
        )
        let mlClassifiedType = activityClassifier.classify(features: features)
        
        // Use ML classification if more confident than basic detection
        let finalActivityType = mlClassifiedType != .unknown ? mlClassifiedType : detectedActivityType
        
        // Calculate distances
        let rawDistance = MapMatching.calculateDistance(locations.map { $0.coordinate })
        let matchedDistance = MapMatching.calculateDistance(matchedCoords)
        
        // Calculate average confidence (now includes sensor fusion confidence)
        let avgConfidence = trustScores.isEmpty ? 0.5 : trustScores.reduce(0, +) / Double(trustScores.count)
        
        // Calculate pace
        let pace = duration > 0 && matchedDistance > 0 ? (duration / matchedDistance) * 1000.0 : nil
        
        // Calculate average cadence
        let avgCadence = motionSamples.isEmpty ? nil : motionSamples.compactMap { $0.cadence }.reduce(0, +) / Double(motionSamples.count)
        
        // Update activity with advanced processing
        activity.endTime = Date()
        activity.activityType = finalActivityType
        activity.rawLocations = locationSamples
        activity.fusedPath = fusedCoords
        activity.mapMatchedPath = matchedCoords
        activity.distanceMetersRaw = rawDistance
        activity.distanceMetersMatched = matchedDistance
        activity.durationSeconds = duration
        activity.confidenceScoreAvg = avgConfidence
        activity.gpsAnomalyCount = anomalyCount
        activity.steps = steps
        activity.cadenceAvg = avgCadence
        activity.avgPaceSecPerKm = pace
        
        await MainActor.run {
            currentActivity = activity
        }
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        for location in locations {
            // Only process locations with reasonable accuracy
            guard location.horizontalAccuracy >= 0 && location.horizontalAccuracy < 100 else { continue }
            
            // Detect anomalies
            if let prev = lastLocation, TrustScorer.detectAnomaly(current: location, previous: prev) {
                anomalyCount += 1
                continue
            }
            
            // Calculate trust score
            let trust = TrustScorer.calculateTrustScore(
                accuracy: location.horizontalAccuracy,
                speed: location.speed >= 0 ? location.speed : 0,
                previousSpeed: lastSpeed,
                course: location.course >= 0 ? location.course : 0,
                previousCourse: lastCourse
            )
            trustScores.append(trust)
            
            // Create location sample
            let source: LocationSource = location.horizontalAccuracy < 10 ? .gps : (location.horizontalAccuracy < 50 ? .wifi : .cell)
            let sample = LocationSample(
                id: UUID(),
                timestamp: location.timestamp,
                lat: location.coordinate.latitude,
                lon: location.coordinate.longitude,
                horizontalAccuracy: location.horizontalAccuracy,
                speed: location.speed >= 0 ? location.speed : 0,
                course: location.course >= 0 ? location.course : 0,
                altitude: location.altitude > 0 ? location.altitude : nil,
                source: source,
                trustScore: trust
            )
            
            locationSamples.append(sample)
            
            // Update route for UI
            let coord = location.coordinate
            if let last = lastLocation {
                let dist = location.distance(from: last)
                if dist > 0.5 { // Only add if moved at least 0.5m
                    totalDistance += dist
                    route.append(coord)
                }
            } else {
                route.append(coord)
            }
            
            lastLocation = location
            currentLocation = coord
            lastSpeed = location.speed >= 0 ? location.speed : 0
            lastCourse = location.course >= 0 ? location.course : 0
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        lastError = error.localizedDescription
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            if isTracking {
                manager.startUpdatingLocation()
            }
        } else if status == .denied || status == .restricted {
            lastError = "Location permission denied"
            isTracking = false
        }
    }
}
