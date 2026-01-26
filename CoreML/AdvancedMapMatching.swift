import Foundation
import CoreLocation
import MapKit

/// Advanced map matching using MapKit routing APIs and heuristics
/// Snaps GPS traces to road/trail networks for accurate distance measurement
class AdvancedMapMatching {
    
    /// Match route to road network using MapKit directions
    func matchToRoads(
        coordinates: [CLLocationCoordinate2D],
        transportType: MKDirectionsTransportType = .walking
    ) async -> [CLLocationCoordinate2D] {
        guard coordinates.count >= 2 else { return coordinates }
        
        // For MVP, use simplified approach
        // In production, would use MapKit's MKDirections API or OpenStreetMap graph
        
        // Step 1: Simplify route (remove redundant points)
        let simplified = simplifyRoute(coordinates, tolerance: 10.0) // 10m tolerance
        
        // Step 2: Apply smoothing
        let smoothed = applySmoothing(simplified, windowSize: 5)
        
        // Step 3: Snap to nearest plausible path (heuristic)
        let snapped = await snapToPaths(smoothed, transportType: transportType)
        
        return snapped
    }
    
    /// Use MapKit directions to find route between waypoints
    private func snapToPaths(
        _ coordinates: [CLLocationCoordinate2D],
        transportType: MKDirectionsTransportType
    ) async -> [CLLocationCoordinate2D] {
        guard coordinates.count >= 2 else { return coordinates }
        
        var matchedRoute: [CLLocationCoordinate2D] = []
        
        // Process in segments to avoid too many waypoints
        let segmentSize = 10
        var i = 0
        
        while i < coordinates.count - 1 {
            let endIndex = min(i + segmentSize, coordinates.count - 1)
            let segment = Array(coordinates[i...endIndex])
            
            if segment.count >= 2 {
                // Try to get directions for this segment
                if let route = await getDirectionsRoute(
                    from: segment.first!,
                    to: segment.last!,
                    waypoints: Array(segment[1..<segment.count-1]),
                    transportType: transportType
                ) {
                    matchedRoute.append(contentsOf: route)
                } else {
                    // Fallback to original coordinates
                    matchedRoute.append(contentsOf: segment)
                }
            }
            
            i = endIndex
        }
        
        return matchedRoute.isEmpty ? coordinates : matchedRoute
    }
    
    /// Request directions from MapKit
    private func getDirectionsRoute(
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D,
        waypoints: [CLLocationCoordinate2D],
        transportType: MKDirectionsTransportType
    ) async -> [CLLocationCoordinate2D]? {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: from))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: to))
        request.transportType = transportType
        
        // Add waypoints if supported
        if !waypoints.isEmpty {
            // For simplicity, use first waypoint as intermediate
            // In production, would handle multiple waypoints properly
            request.requestsAlternateRoutes = false
        }
        
        let directions = MKDirections(request: request)
        
        do {
            let response = try await directions.calculate()
            guard let route = response.routes.first else { return nil }
            
            // Extract coordinates from route polyline
            let pointCount = route.polyline.pointCount
            var routeCoordinates = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: pointCount)
            route.polyline.getCoordinates(&routeCoordinates, range: NSRange(location: 0, length: pointCount))
            
            return routeCoordinates.filter { CLLocationCoordinate2DIsValid($0) }
        } catch {
            // Fallback to direct path
            return nil
        }
    }
    
    /// Douglas-Peucker algorithm for route simplification
    private func simplifyRoute(
        _ coordinates: [CLLocationCoordinate2D],
        tolerance: Double
    ) -> [CLLocationCoordinate2D] {
        guard coordinates.count > 2 else { return coordinates }
        
        // Find point with maximum distance from line between first and last
        var maxDistance: Double = 0
        var maxIndex = 0
        
        let first = CLLocation(latitude: coordinates[0].latitude, longitude: coordinates[0].longitude)
        let last = CLLocation(latitude: coordinates.last!.latitude, longitude: coordinates.last!.longitude)
        
        for i in 1..<coordinates.count - 1 {
            let point = CLLocation(latitude: coordinates[i].latitude, longitude: coordinates[i].longitude)
            let distance = perpendicularDistance(point: point, lineStart: first, lineEnd: last)
            
            if distance > maxDistance {
                maxDistance = distance
                maxIndex = i
            }
        }
        
        // If max distance > tolerance, recursively simplify
        if maxDistance > tolerance {
            let left = simplifyRoute(Array(coordinates[0...maxIndex]), tolerance: tolerance)
            let right = simplifyRoute(Array(coordinates[maxIndex..<coordinates.count]), tolerance: tolerance)
            
            // Combine results (remove duplicate at maxIndex)
            return Array(left.dropLast()) + right
        } else {
            // Return endpoints only
            return [coordinates[0], coordinates.last!]
        }
    }
    
    /// Calculate perpendicular distance from point to line segment
    private func perpendicularDistance(
        point: CLLocation,
        lineStart: CLLocation,
        lineEnd: CLLocation
    ) -> Double {
        let A = point.distance(from: lineStart)
        let B = point.distance(from: lineEnd)
        let C = lineStart.distance(from: lineEnd)
        
        // Heron's formula for area
        let s = (A + B + C) / 2
        let area = sqrt(max(0, s * (s - A) * (s - B) * (s - C)))
        
        // Height = 2 * area / base
        return 2 * area / C
    }
    
    /// Apply moving average smoothing
    private func applySmoothing(
        _ coordinates: [CLLocationCoordinate2D],
        windowSize: Int
    ) -> [CLLocationCoordinate2D] {
        guard coordinates.count > windowSize else { return coordinates }
        
        var smoothed: [CLLocationCoordinate2D] = []
        
        for i in 0..<coordinates.count {
            let start = max(0, i - windowSize / 2)
            let end = min(coordinates.count, i + windowSize / 2 + 1)
            let window = Array(coordinates[start..<end])
            
            let avgLat = window.map { $0.latitude }.reduce(0, +) / Double(window.count)
            let avgLon = window.map { $0.longitude }.reduce(0, +) / Double(window.count)
            
            smoothed.append(CLLocationCoordinate2D(latitude: avgLat, longitude: avgLon))
        }
        
        return smoothed
    }
    
    /// Calculate elevation gain from coordinates
    func calculateElevationGain(_ coordinates: [CLLocationCoordinate2D]) -> Double {
        // This would require elevation data (from CLLocation or elevation API)
        // For MVP, return 0
        return 0
    }
}
