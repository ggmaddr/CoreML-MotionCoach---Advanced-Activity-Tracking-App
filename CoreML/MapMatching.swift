import Foundation
import CoreLocation
import MapKit

class MapMatching {
    /// Simple heuristic map matching - removes outliers and smooths route
    static func matchRoute(_ rawPath: [CLLocationCoordinate2D], minDistance: Double = 5.0) -> [CLLocationCoordinate2D] {
        guard rawPath.count > 2 else { return rawPath }
        
        // Step 1: Remove outliers (points that imply impossible speeds)
        let filtered = removeOutliers(rawPath, maxSpeed: 12.0) // 12 m/s = ~43 km/h max for run/hike
        
        // Step 2: Simplify using Douglas-Peucker-like approach
        let simplified = simplifyPath(filtered, tolerance: minDistance)
        
        return simplified
    }
    
    /// Remove points that imply impossible movement speeds
    private static func removeOutliers(_ path: [CLLocationCoordinate2D], maxSpeed: Double) -> [CLLocationCoordinate2D] {
        guard path.count > 1 else { return path }
        
        var filtered: [CLLocationCoordinate2D] = [path[0]]
        
        for i in 1..<path.count {
            let prev = CLLocation(latitude: filtered.last!.latitude, longitude: filtered.last!.longitude)
            let curr = CLLocation(latitude: path[i].latitude, longitude: path[i].longitude)
            
            let distance = prev.distance(from: curr)
            let timeInterval = 1.0 // Assume ~1 second between points
            let speed = distance / timeInterval
            
            if speed <= maxSpeed {
                filtered.append(path[i])
            }
        }
        
        return filtered
    }
    
    /// Simplify path using distance-based filtering
    private static func simplifyPath(_ path: [CLLocationCoordinate2D], tolerance: Double) -> [CLLocationCoordinate2D] {
        guard path.count > 2 else { return path }
        
        var simplified: [CLLocationCoordinate2D] = [path[0]]
        
        for i in 1..<path.count - 1 {
            let prev = CLLocation(latitude: simplified.last!.latitude, longitude: simplified.last!.longitude)
            let curr = CLLocation(latitude: path[i].latitude, longitude: path[i].longitude)
            let next = CLLocation(latitude: path[i + 1].latitude, longitude: path[i + 1].longitude)
            
            let distToPrev = prev.distance(from: curr)
            let distToNext = curr.distance(from: next)
            
            // Keep point if it's far enough from previous or creates significant change
            if distToPrev >= tolerance || distToNext >= tolerance {
                simplified.append(path[i])
            }
        }
        
        // Always include last point
        simplified.append(path.last!)
        
        return simplified
    }
    
    /// Calculate distance along a path
    static func calculateDistance(_ path: [CLLocationCoordinate2D]) -> Double {
        guard path.count > 1 else { return 0 }
        
        var totalDistance: Double = 0
        for i in 1..<path.count {
            let prev = CLLocation(latitude: path[i-1].latitude, longitude: path[i-1].longitude)
            let curr = CLLocation(latitude: path[i].latitude, longitude: path[i].longitude)
            totalDistance += prev.distance(from: curr)
        }
        
        return totalDistance
    }
    
    /// Smooth path using moving average
    static func smoothPath(_ path: [CLLocationCoordinate2D], windowSize: Int = 3) -> [CLLocationCoordinate2D] {
        guard path.count > windowSize else { return path }
        
        var smoothed: [CLLocationCoordinate2D] = []
        
        for i in 0..<path.count {
            let start = max(0, i - windowSize / 2)
            let end = min(path.count, i + windowSize / 2 + 1)
            let window = Array(path[start..<end])
            
            let avgLat = window.map { $0.latitude }.reduce(0, +) / Double(window.count)
            let avgLon = window.map { $0.longitude }.reduce(0, +) / Double(window.count)
            
            smoothed.append(CLLocationCoordinate2D(latitude: avgLat, longitude: avgLon))
        }
        
        return smoothed
    }
}
