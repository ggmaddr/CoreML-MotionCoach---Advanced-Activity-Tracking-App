//
//  ContentView.swift
//  CoreML
//
//  Created by Grady Ta on 1/26/26.
//

import SwiftUI
import MapKit
import CoreLocation
import UIKit

struct HomeMapView: View {
    @StateObject private var trackingEngine = TrackingEngine()
    @StateObject private var rewardsManager = RewardsManager()
    @StateObject private var goalsManager = GoalsManager()
    
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.334_900, longitude: -122.009_020),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    @State private var showPermissionSheet = false
    @State private var navigateToActivitySummary = false
    @State private var navigateToGoals = false
    @State private var navigateToProfile = false
    @State private var completedActivity: Activity?
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                // Map with route polyline
                ZStack {
                    MapViewWithPolyline(
                        region: $region,
                        showsUserLocation: true,
                        userTrackingMode: trackingEngine.isTracking ? .follow : .none,
                        polylineCoordinates: trackingEngine.route
                    )
                    .edgesIgnoringSafeArea(.all)
                    .accentColor(.green)
                    
                    // Subtle vignette effect
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.3),
                            Color.clear,
                            Color.clear,
                            Color.black.opacity(0.4)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                }
                    .onAppear {
                        checkLocationPermission()
                    }
                
                VStack(spacing: 0) {
                    // Top overlay chips
                    HStack(spacing: 12) {
                        Button {
                            navigateToGoals = true
                        } label: {
                            statusChip(
                                title: "Today",
                                value: "\(rewardsManager.userProgress.currentXP) XP",
                                systemImage: "bolt.fill",
                                color: .yellow
                            )
                        }
                        .buttonStyle(.plain)
                        
                        Button {
                            navigateToProfile = true
                        } label: {
                            statusChip(
                                title: "Streak",
                                value: "\(rewardsManager.userProgress.streakDays) days",
                                systemImage: "flame.fill",
                                color: .orange
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 56)
                    .padding(.horizontal)
                    .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
                    
                    Spacer()
                    
                    // Tracking bottom sheet or goals carousel
                    if trackingEngine.isTracking || trackingEngine.activityState == .summarizing {
                        trackingBottomSheet
                    } else {
                        // Goals carousel (when idle)
                        if !goalsManager.getActiveGoals().isEmpty {
                            goalsCarousel
                                .padding(.bottom, 20)
                        }
                    }
                    
                    // Control buttons
                    if trackingEngine.activityState == .summarizing {
                        HStack(spacing: 16) {
                            // Reset button
                            Button(action: {
                                trackingEngine.reset()
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "arrow.counterclockwise")
                                        .font(.title3)
                                    Text("Reset")
                                        .font(.system(size: 18, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .frame(width: 140, height: 56)
                                .background(
                                    LinearGradient(
                                        colors: [Color.gray.opacity(0.8), Color.gray.opacity(0.6)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .clipShape(Capsule())
                                .shadow(color: Color.gray.opacity(0.4), radius: 12, x: 0, y: 4)
                                .overlay(
                                    Capsule().strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                                )
                            }
                            
                            // Resume button
                            Button(action: {
                                trackingEngine.resumeTracking()
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "play.fill")
                                        .font(.title3)
                                    Text("Resume")
                                        .font(.system(size: 18, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .frame(width: 140, height: 56)
                                .background(
                                    LinearGradient(
                                        colors: [Color.green.opacity(0.8), Color.blue.opacity(0.8)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .clipShape(Capsule())
                                .shadow(color: Color.green.opacity(0.4), radius: 18, x: 0, y: 6)
                                .overlay(
                                    Capsule().strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                                )
                            }
                        }
                        .padding(.bottom, 40)
                    } else {
                        // Start/Stop button
                        Button(action: {
                            if trackingEngine.isTracking {
                                trackingEngine.stopTracking()
                            } else {
                                trackingEngine.startTracking()
                            }
                        }) {
                            Text(trackingEngine.isTracking ? "Stop" : "Start")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .frame(width: 180, height: 56)
                                .background(
                                    LinearGradient(
                                        colors: trackingEngine.isTracking
                                            ? [Color.red.opacity(0.8), Color.orange.opacity(0.8)]
                                            : [Color.green.opacity(0.8), Color.blue.opacity(0.8)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                            .clipShape(Capsule())
                            .shadow(color: (trackingEngine.isTracking ? Color.red : Color.green).opacity(0.6), radius: 24, x: 0, y: 8)
                            .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 4)
                            .overlay(
                                Capsule().strokeBorder(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.4),
                                            Color.white.opacity(0.1)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ),
                                    lineWidth: 2
                                )
                            )
                        }
                        .padding(.bottom, 40)
                    }
                }
                
                // NavigationLinks
                NavigationLink(
                    destination: ActivitySummaryView(activity: completedActivity),
                    isActive: $navigateToActivitySummary
                ) { EmptyView() }
                NavigationLink(destination: GoalsView(), isActive: $navigateToGoals) { EmptyView() }
                NavigationLink(destination: ProfileView(), isActive: $navigateToProfile) { EmptyView() }
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("MotionCoach")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showPermissionSheet) {
                PermissionSheet()
            }
        }
        .environmentObject(trackingEngine)
        .environmentObject(rewardsManager)
        .environmentObject(goalsManager)
    }
    
    private var trackingBottomSheet: some View {
        VStack(spacing: 20) {
            // Status indicator
            if trackingEngine.activityState == .summarizing {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color.orange.opacity(0.2))
                            .frame(width: 24, height: 24)
                        Image(systemName: "pause.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.orange)
                    }
                    Text("Paused")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.orange)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color.orange.opacity(0.15))
                        .overlay(
                            Capsule()
                                .strokeBorder(Color.orange.opacity(0.3), lineWidth: 1)
                        )
                )
            }
            
            // Distance (large)
            VStack(spacing: 4) {
                Text(formatDistance(trackingEngine.totalDistance))
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("Distance")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            HStack(spacing: 24) {
                // Time
                VStack(spacing: 4) {
                    Text(formatTime(trackingEngine.elapsedTime))
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                    Text("Time")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                
                // Pace
                if trackingEngine.totalDistance > 0 {
                    VStack(spacing: 4) {
                        Text(formatPace(trackingEngine.elapsedTime, distance: trackingEngine.totalDistance))
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.white)
                        Text("Pace")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
                
                // Steps
                if trackingEngine.steps > 0 {
                    VStack(spacing: 4) {
                        Text("\(trackingEngine.steps)")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.white)
                        Text("Steps")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
            }
            
            // Confidence ring
            ConfidenceRing(confidence: trackingEngine.confidenceScore)
                .frame(height: 60)
            
            // Goal progress (if active goal selected)
            if let activeGoal = goalsManager.getActiveGoals().first {
                GoalProgressBar(goal: activeGoal, currentDistance: trackingEngine.totalDistance)
            }
        }
        .padding(24)
        .background(
            ZStack {
                // Primary blur
                BlurView(style: .systemUltraThinMaterialDark)
                
                // Gradient overlay
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.05),
                        Color.clear,
                        Color.black.opacity(0.2)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.3),
                            Color.white.opacity(0.05),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        .shadow(color: .black.opacity(0.4), radius: 30, x: 0, y: 15)
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }
    
    private var goalsCarousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(goalsManager.getActiveGoals()) { goal in
                    GoalCard(goal: goal)
                }
            }
            .padding(.horizontal)
        }
    }
    
    @ViewBuilder
    func statusChip(title: String, value: String, systemImage: String, color: Color) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 32, height: 32)
                
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.gray)
                    .textCase(.uppercase)
                    .tracking(0.5)
                Text(value)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            ZStack {
                // Blur background
                BlurView(style: .systemUltraThinMaterialDark)
                
                // Subtle gradient overlay
                LinearGradient(
                    colors: [
                        color.opacity(0.1),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.2),
                            Color.white.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        .shadow(color: color.opacity(0.3), radius: 12, x: 0, y: 4)
    }
    
    private func checkLocationPermission() {
        let manager = CLLocationManager()
        let status = manager.authorizationStatus
        if status == .notDetermined {
            showPermissionSheet = true
        }
    }
    
    private func formatDistance(_ meters: Double) -> String {
        if meters >= 1000 {
            return String(format: "%.2f km", meters / 1000.0)
        } else {
            return String(format: "%.0f m", meters)
        }
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = Int(seconds) / 60 % 60
        let secs = Int(seconds) % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }
    
    private func formatPace(_ seconds: TimeInterval, distance: Double) -> String {
        guard distance > 0 else { return "--:--" }
        let paceSeconds = (seconds / distance) * 1000.0
        let minutes = Int(paceSeconds) / 60
        let secs = Int(paceSeconds) % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}

struct GoalCard: View {
    let goal: Goal
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(goal.title)
                .font(.headline)
                .foregroundColor(.white)
            
            Text(goalDescription)
                .font(.caption)
                .foregroundColor(.gray)
            
            ProgressView(value: progress, total: 1.0)
                .tint(.green)
        }
        .padding()
        .frame(width: 200)
        .background(BlurView(style: .systemUltraThinMaterialDark))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var goalDescription: String {
        switch goal.type {
        case .distance:
            return "\(String(format: "%.1f", goal.targetValue / 1000.0)) km"
        case .duration:
            return "\(String(format: "%.0f", goal.targetValue / 60.0)) min"
        default:
            return goal.type.rawValue
        }
    }
    
    private var progress: Double {
        // For MVP, return 0. This would be calculated from current activity
        return 0.0
    }
}

struct GoalProgressBar: View {
    let goal: Goal
    let currentDistance: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(goal.title)
                    .font(.caption)
                    .foregroundColor(.gray)
                Spacer()
                Text("\(Int(progress * 100))%")
                    .font(.caption)
                    .foregroundColor(.green)
            }
            
            ProgressView(value: progress, total: 1.0)
                .tint(.green)
        }
    }
    
    private var progress: Double {
        guard goal.type == .distance else { return 0 }
        return min(1.0, currentDistance / goal.targetValue)
    }
}

struct ConfidenceRing: View {
    let confidence: Double
    
    var body: some View {
        ZStack {
            // Background ring with subtle glow
            Circle()
                .stroke(Color.gray.opacity(0.15), lineWidth: 8)
                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
            
            // Progress ring with gradient and glow
            Circle()
                .trim(from: 0, to: confidence)
                .stroke(
                    AngularGradient(
                        colors: [
                            Color.red,
                            Color.orange,
                            Color.yellow,
                            Color.green,
                            Color.green
                        ],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: ringColor.opacity(0.6), radius: 8, x: 0, y: 0)
            
            // Inner content with glass effect
            VStack(spacing: 4) {
                Text("\(Int(confidence * 100))%")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                Text("Quality")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.gray)
                    .textCase(.uppercase)
                    .tracking(0.5)
            }
            .padding(12)
            .background(
                Circle()
                    .fill(Color.black.opacity(0.3))
                    .overlay(
                        Circle()
                            .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
        }
    }
    
    private var ringColor: Color {
        if confidence >= 0.8 { return .green }
        else if confidence >= 0.5 { return .yellow }
        else { return .red }
    }
}

struct PermissionSheet: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "location.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            Text("Location Access Required")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text("MotionCoach needs your location to track your activities and verify your goals. Your data stays private and is stored only on your device.")
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: {
                let manager = CLLocationManager()
                manager.requestWhenInUseAuthorization()
                dismiss()
            }) {
                Text("Enable Location")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal)
            
            Button(action: { dismiss() }) {
                Text("Not Now")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color.black.ignoresSafeArea())
    }
}

struct GoalsView: View {
    @EnvironmentObject var goalsManager: GoalsManager
    @State private var showCreateGoal = false
    @State private var showMaxGoalsAlert = false
    @State private var isAddButtonPressed = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Animated gradient background
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.1, blue: 0.2),
                        Color.black,
                        Color(red: 0.1, green: 0.05, blue: 0.15)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                // Floating orbs for depth
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.green.opacity(0.3), Color.clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 200
                        )
                    )
                    .frame(width: 400, height: 400)
                    .offset(x: -100, y: -200)
                    .blur(radius: 60)
                
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.blue.opacity(0.25), Color.clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 150
                        )
                    )
                    .frame(width: 300, height: 300)
                    .offset(x: 150, y: 300)
                    .blur(radius: 50)
                
                if goalsManager.goals.isEmpty {
                    VStack(spacing: 32) {
                        // Icon with animation
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.green.opacity(0.3), Color.blue.opacity(0.3)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 120, height: 120)
                                .blur(radius: 20)
                            
                            Image(systemName: "target")
                                .font(.system(size: 60))
                                .foregroundColor(.white)
                        }
                        
                        VStack(spacing: 12) {
                            Text("No Goals Yet")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Text("Set your first goal and start\nyour fitness journey today! 🚀")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                        }
                        
                        // Amazing Add Goal Button
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                isAddButtonPressed = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                    isAddButtonPressed = false
                                }
                                checkAndAddGoal()
                            }
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                Text("Create Your First Goal")
                                    .font(.headline)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 18)
                            .background(
                                ZStack {
                                    LinearGradient(
                                        colors: [Color.green, Color.blue],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                    .blur(radius: isAddButtonPressed ? 0 : 2)
                                    
                                    // Shimmer effect
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.0),
                                            Color.white.opacity(0.3),
                                            Color.white.opacity(0.0)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                }
                            )
                            .clipShape(Capsule())
                            .shadow(color: .green.opacity(0.5), radius: isAddButtonPressed ? 10 : 20, x: 0, y: isAddButtonPressed ? 4 : 10)
                            .scaleEffect(isAddButtonPressed ? 0.95 : 1.0)
                            .overlay(
                                Capsule()
                                    .strokeBorder(
                                        LinearGradient(
                                            colors: [Color.white.opacity(0.3), Color.white.opacity(0.1)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        ),
                                        lineWidth: 2
                                    )
                            )
                        }
                    }
                } else {
                    VStack(spacing: 0) {
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                ForEach(goalsManager.goals) { goal in
                                    GoalRowView(goal: goal)
                                }
                            }
                            .padding()
                            .padding(.bottom, 80)
                        }
                        
                        // Add Goal Button at bottom
                        VStack {
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                    isAddButtonPressed = true
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                        isAddButtonPressed = false
                                    }
                                    checkAndAddGoal()
                                }
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.title3)
                                    Text("Add Goal")
                                        .font(.system(size: 18, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    LinearGradient(
                                        colors: [Color.green, Color.blue],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .shadow(color: .green.opacity(0.4), radius: isAddButtonPressed ? 8 : 16, x: 0, y: isAddButtonPressed ? 2 : 8)
                                .scaleEffect(isAddButtonPressed ? 0.98 : 1.0)
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 16)
                        }
                        .background(
                            LinearGradient(
                                colors: [Color.black.opacity(0.0), Color.black],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .ignoresSafeArea()
                        )
                    }
                }
            }
            .navigationTitle("Goals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { checkAndAddGoal() }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundColor(.green)
                    }
                }
            }
            .sheet(isPresented: $showCreateGoal) {
                CreateGoalView()
            }
            .alert("Maximum Goals Reached", isPresented: $showMaxGoalsAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("You can only have 10 active goals at a time. Please complete or remove some goals before creating new ones.")
            }
        }
    }
    
    private func checkAndAddGoal() {
        if goalsManager.goals.count >= 10 {
            showMaxGoalsAlert = true
        } else {
            showCreateGoal = true
        }
    }
}

struct GoalRowView: View {
    let goal: Goal
    @EnvironmentObject var goalsManager: GoalsManager
    @State private var animatedProgress: Double = 0
    
    var body: some View {
        HStack(spacing: 0) {
            // Left colored indicator bar
            RoundedRectangle(cornerRadius: 8)
                .fill(goalColor)
                .frame(width: 6)
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    // Icon
                    Image(systemName: goalIcon)
                        .font(.title3)
                        .foregroundColor(goalColor)
                    
                    Text(goal.title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    if goal.status == .active {
                        Text("\(Int(progress * 100))%")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(goalColor)
                    } else {
                        Text(goal.status.rawValue.capitalized)
                            .font(.caption)
                            .foregroundColor(statusColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(statusColor.opacity(0.2))
                            .clipShape(Capsule())
                    }
                }
                
                HStack(spacing: 8) {
                    Image(systemName: timeframeIcon)
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text(goalDescription)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                if goal.status == .active {
                    // Progress bar matching image style
                    ZStack(alignment: .leading) {
                        // Background
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 8)
                        
                        // Progress
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                LinearGradient(
                                    colors: [goalColor, goalColor.opacity(0.7)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(0, CGFloat(animatedProgress) * (UIScreen.main.bounds.width - 100)), height: 8)
                    }
                    .onAppear {
                        withAnimation(.easeInOut(duration: 1.0)) {
                            animatedProgress = progress
                        }
                    }
                }
            }
            .padding()
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(goalColor.opacity(0.2), lineWidth: 1)
        )
    }
    
    private var goalDescription: String {
        var desc = "\(goal.type.rawValue.capitalized): "
        switch goal.type {
        case .distance:
            desc += "\(String(format: "%.2f", goal.targetValue / 1000.0)) km"
        case .duration:
            desc += "\(String(format: "%.0f", goal.targetValue / 60.0)) min"
        case .elevationGain:
            desc += "\(String(format: "%.0f", goal.targetValue)) m"
        case .sessionsCount:
            desc += "\(Int(goal.targetValue)) sessions"
        }
        desc += " • \(goal.timeframe.rawValue.capitalized)"
        return desc
    }
    
    private var statusColor: Color {
        switch goal.status {
        case .active: return .green
        case .completed: return .blue
        case .expired: return .gray
        }
    }
    
    private var goalColor: Color {
        switch goal.type {
        case .distance: return Color.green
        case .duration: return Color.orange
        case .elevationGain: return Color.purple
        case .sessionsCount: return Color.blue
        }
    }
    
    private var goalIcon: String {
        switch goal.type {
        case .distance: return "figure.run"
        case .duration: return "clock.fill"
        case .elevationGain: return "mountain.2.fill"
        case .sessionsCount: return "repeat"
        }
    }
    
    private var timeframeIcon: String {
        switch goal.timeframe {
        case .today: return "calendar"
        case .thisWeek: return "calendar.badge.clock"
        case .customRange: return "calendar.badge.exclamationmark"
        }
    }
    
    private var progress: Double {
        // Mock progress for demo - in real app would calculate from actual activities
        switch goal.status {
        case .active:
            // Return random progress between 0.3 and 0.8 for demo
            let hash = abs(goal.id.hashValue)
            return Double((hash % 50) + 30) / 100.0
        case .completed:
            return 1.0
        case .expired:
            return 0.0
        }
    }
}

struct CreateGoalView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var goalsManager: GoalsManager
    
    @State private var title = ""
    @State private var selectedType: GoalType = .distance
    @State private var targetValue: Double = 2.0
    @State private var selectedTimeframe: Timeframe = .today
    @State private var selectedActivities: Set<ActivityType> = [.run]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Goal Details") {
                    TextField("Goal Title", text: $title)
                    
                    Picker("Type", selection: $selectedType) {
                        ForEach(GoalType.allCases, id: \.self) { type in
                            Text(type.rawValue.capitalized).tag(type)
                        }
                    }
                    
                    HStack {
                        Text("Target")
                        Spacer()
                        TextField("Value", value: $targetValue, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                        Text(unitLabel)
                            .foregroundColor(.gray)
                    }
                }
                
                Section("Timeframe") {
                    Picker("Timeframe", selection: $selectedTimeframe) {
                        ForEach(Timeframe.allCases, id: \.self) { timeframe in
                            Text(timeframe.rawValue.capitalized).tag(timeframe)
                        }
                    }
                }
                
                Section("Allowed Activities") {
                    ForEach(ActivityType.allCases.filter { $0 != .unknown }, id: \.self) { activity in
                        Toggle(activity.rawValue.capitalized, isOn: Binding(
                            get: { selectedActivities.contains(activity) },
                            set: { isOn in
                                if isOn {
                                    selectedActivities.insert(activity)
                                } else {
                                    selectedActivities.remove(activity)
                                }
                            }
                        ))
                    }
                }
            }
            .navigationTitle("New Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createGoal()
                    }
                    .disabled(title.isEmpty || selectedActivities.isEmpty)
                }
            }
            .preferredColorScheme(.dark)
        }
    }
    
    private var unitLabel: String {
        switch selectedType {
        case .distance: return "km"
        case .duration: return "min"
        case .elevationGain: return "m"
        case .sessionsCount: return "sessions"
        }
    }
    
    private func createGoal() {
        let value = selectedType == .distance ? targetValue * 1000.0 : (selectedType == .duration ? targetValue * 60.0 : targetValue)
        goalsManager.createGoal(
            title: title,
            type: selectedType,
            targetValue: value,
            timeframe: selectedTimeframe,
            allowedActivities: Array(selectedActivities)
        )
        dismiss()
    }
}


struct NextMilestoneBar: View {
    // For demo: 75km out of 100km for Ruby
    private let currentProgress: Double = 75.0
    private let targetProgress: Double = 100.0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "flag.fill")
                    .foregroundColor(.orange)
                Text("Next Milestone")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Text("\(Int(currentProgress))km / \(Int(targetProgress))km")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            // Progress bar with runner icon
            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 24)
                
                // Progress fill
                GeometryReader { geometry in
                    let progress = currentProgress / targetProgress
                    let width = geometry.size.width * progress
                    
                    ZStack(alignment: .leading) {
                        // Gradient progress bar
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 1.0, green: 0.84, blue: 0.0), // Gold
                                        Color(red: 0.88, green: 0.07, blue: 0.37) // Ruby
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: width, height: 24)
                        
                        // Runner icon at progress point
                        HStack {
                            Spacer()
                            ZStack {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 36, height: 36)
                                    .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                                
                                Image(systemName: "figure.run")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(Color(red: 0.88, green: 0.07, blue: 0.37))
                            }
                            .offset(x: 6)
                        }
                        .frame(width: max(0, width - 18), height: 24)
                    }
                }
                .frame(height: 24)
                
                // Target milestone icon
                HStack {
                    Spacer()
                    ZStack {
                        Circle()
                            .fill(Color(red: 0.88, green: 0.07, blue: 0.37).opacity(0.2))
                            .frame(width: 40, height: 40)
                        
                        Image(systemName: "star.fill")
                            .font(.system(size: 20))
                            .foregroundColor(Color(red: 0.88, green: 0.07, blue: 0.37))
                    }
                    .offset(x: 8)
                }
            }
            .frame(height: 40)
            
            // Milestone name
            HStack {
                Image(systemName: "star.fill")
                    .font(.caption)
                    .foregroundColor(Color(red: 0.88, green: 0.07, blue: 0.37))
                Text("Ruby Warrior - Run 100km total")
                    .font(.caption)
                    .foregroundColor(.gray)
                Spacer()
                Text("\(Int((currentProgress / targetProgress) * 100))%")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(Color(red: 0.88, green: 0.07, blue: 0.37))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.88, green: 0.07, blue: 0.37).opacity(0.1),
                            Color(red: 0.88, green: 0.07, blue: 0.37).opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color(red: 0.88, green: 0.07, blue: 0.37).opacity(0.4),
                            Color(red: 0.88, green: 0.07, blue: 0.37).opacity(0.2)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
        )
    }
}

struct AchievementRow: View {
    let achievement: Achievement
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: achievement.icon)
                .font(.title2)
                .foregroundColor(achievement.isUnlocked ? achievementColor : .gray)
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(achievement.isUnlocked ? achievementColor.opacity(0.2) : Color.gray.opacity(0.1))
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(achievement.name)
                    .font(.headline)
                    .foregroundColor(achievement.isUnlocked ? .white : .gray)
                
                Text(achievement.description)
                    .font(.caption)
                    .foregroundColor(.gray)
                
                if let daysAgo = achievement.daysAgo {
                    Text("Unlocked \(daysAgo) day\(daysAgo == 1 ? "" : "s") ago")
                        .font(.caption2)
                        .foregroundColor(.green)
                } else {
                    Text("Locked")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                
                Text(achievement.funnyComment)
                    .font(.caption2)
                    .italic()
                    .foregroundColor(.gray.opacity(0.8))
                    .padding(.top, 2)
            }
            
            Spacer()
            
            if achievement.isUnlocked {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
        }
        .padding(.vertical, 8)
    }
    
    private var achievementColor: Color {
        switch achievement.color {
        case "bronze": return Color(red: 0.8, green: 0.5, blue: 0.2)
        case "silver": return Color(red: 0.75, green: 0.75, blue: 0.75)
        case "gold": return Color(red: 1.0, green: 0.84, blue: 0.0)
        case "ruby": return Color(red: 0.88, green: 0.07, blue: 0.37)
        default: return .gray
        }
    }
}

struct ProfileView: View {
    @EnvironmentObject var rewardsManager: RewardsManager
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Epic gradient background
                LinearGradient(
                    colors: [
                        Color(red: 0.15, green: 0.05, blue: 0.2),
                        Color.black,
                        Color(red: 0.2, green: 0.1, blue: 0.05)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                // Floating orbs
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.purple.opacity(0.3), Color.clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 150
                        )
                    )
                    .frame(width: 300, height: 300)
                    .offset(x: -100, y: -200)
                    .blur(radius: 60)
                
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.orange.opacity(0.25), Color.clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 120
                        )
                    )
                    .frame(width: 250, height: 250)
                    .offset(x: 120, y: 300)
                    .blur(radius: 50)
                
                ScrollView {
                    VStack(spacing: 32) {
                        // Hero section with level
                        VStack(spacing: 20) {
                            // Glowing level badge
                            ZStack {
                                Circle()
                                    .fill(
                                        RadialGradient(
                                            colors: [
                                                Color.yellow.opacity(0.3),
                                                Color.orange.opacity(0.2),
                                                Color.clear
                                            ],
                                            center: .center,
                                            startRadius: 0,
                                            endRadius: 80
                                        )
                                    )
                                    .frame(width: 160, height: 160)
                                    .blur(radius: 25)
                                
                                ZStack {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    Color.yellow.opacity(0.3),
                                                    Color.orange.opacity(0.3)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 120, height: 120)
                                    
                                    Circle()
                                        .stroke(
                                            LinearGradient(
                                                colors: [Color.yellow, Color.orange],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 3
                                        )
                                        .frame(width: 120, height: 120)
                                        .shadow(color: .orange.opacity(0.8), radius: 15, x: 0, y: 0)
                                    
                                    VStack(spacing: 2) {
                                        Text("LEVEL")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(.orange.opacity(0.8))
                                            .tracking(2)
                                        Text("\(rewardsManager.userProgress.level)")
                                            .font(.system(size: 44, weight: .heavy))
                                            .foregroundColor(.white)
                                            .shadow(color: .orange.opacity(0.5), radius: 8, x: 0, y: 0)
                                    }
                                }
                            }
                            .padding(.top, 20)
                            
                            Text("Fitness Champion")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.gray)
                                .italic()
                        }
                        
                        // Level & XP
                        VStack(spacing: 16) {
                            Text("\(rewardsManager.userProgress.currentXP) XP")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                        
                            // XP Progress bar with epic styling
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("\(rewardsManager.getXPForNextLevel()) XP")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.yellow)
                                    Text("to Level \(rewardsManager.userProgress.level + 1)")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.gray)
                                    Spacer()
                                    Text("\(Int(rewardsManager.getXPProgress() * 100))%")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(.yellow)
                                }
                                
                                GeometryReader { geometry in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(Color.gray.opacity(0.15))
                                            .frame(height: 12)
                                        
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(
                                                LinearGradient(
                                                    colors: [Color.yellow, Color.orange],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )
                                            .frame(width: geometry.size.width * CGFloat(rewardsManager.getXPProgress()), height: 12)
                                            .shadow(color: .yellow.opacity(0.6), radius: 8, x: 0, y: 0)
                                    }
                                }
                                .frame(height: 12)
                            }
                        }
                        .padding(20)
                        .background(
                            ZStack {
                                BlurView(style: .systemUltraThinMaterialDark)
                                
                                LinearGradient(
                                    colors: [
                                        Color.yellow.opacity(0.08),
                                        Color.clear,
                                        Color.orange.opacity(0.08)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            }
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [
                                            Color.yellow.opacity(0.4),
                                            Color.orange.opacity(0.2)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 2
                                )
                        )
                        .shadow(color: .yellow.opacity(0.2), radius: 20, x: 0, y: 10)
                    
                        // Streak cards with epic styling
                        HStack(spacing: 16) {
                            // Streak card
                            VStack(spacing: 10) {
                                ZStack {
                                    Circle()
                                        .fill(Color.orange.opacity(0.2))
                                        .frame(width: 50, height: 50)
                                    
                                    Image(systemName: "flame.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(.orange)
                                        .shadow(color: .orange.opacity(0.8), radius: 8, x: 0, y: 0)
                                }
                                
                                Text("\(rewardsManager.userProgress.streakDays)")
                                    .font(.system(size: 34, weight: .heavy))
                                    .foregroundColor(.white)
                                
                                Text("Day Streak")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.gray)
                                    .textCase(.uppercase)
                                    .tracking(0.8)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                            .background(
                                ZStack {
                                    BlurView(style: .systemUltraThinMaterialDark)
                                    
                                    LinearGradient(
                                        colors: [
                                            Color.orange.opacity(0.15),
                                            Color.clear
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                }
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .strokeBorder(Color.orange.opacity(0.3), lineWidth: 1.5)
                            )
                            .shadow(color: .orange.opacity(0.3), radius: 15, x: 0, y: 8)
                            
                            // Weekly card
                            VStack(spacing: 10) {
                                ZStack {
                                    Circle()
                                        .fill(Color.green.opacity(0.2))
                                        .frame(width: 50, height: 50)
                                    
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(.green)
                                        .shadow(color: .green.opacity(0.8), radius: 8, x: 0, y: 0)
                                }
                                
                                Text("\(rewardsManager.userProgress.weeklyCompletionsCount)")
                                    .font(.system(size: 34, weight: .heavy))
                                    .foregroundColor(.white)
                                
                                Text("This Week")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.gray)
                                    .textCase(.uppercase)
                                    .tracking(0.8)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                            .background(
                                ZStack {
                                    BlurView(style: .systemUltraThinMaterialDark)
                                    
                                    LinearGradient(
                                        colors: [
                                            Color.green.opacity(0.15),
                                            Color.clear
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                }
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .strokeBorder(Color.green.opacity(0.3), lineWidth: 1.5)
                            )
                            .shadow(color: .green.opacity(0.3), radius: 15, x: 0, y: 8)
                        }
                    
                        // Next Milestone Progress Bar
                        NextMilestoneBar()
                        
                        // Achievements with epic header
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "trophy.fill")
                                    .font(.title3)
                                    .foregroundColor(.yellow)
                                    .shadow(color: .yellow.opacity(0.8), radius: 8, x: 0, y: 0)
                                
                                Text("Achievements")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                Text("\(MockData.achievements.filter { $0.isUnlocked }.count)/\(MockData.achievements.count)")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.yellow)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.yellow.opacity(0.2))
                                    .clipShape(Capsule())
                            }
                            
                            ForEach(MockData.achievements) { achievement in
                                AchievementRow(achievement: achievement)
                            }
                        }
                        .padding(20)
                        .background(
                            ZStack {
                                BlurView(style: .systemUltraThinMaterialDark)
                                
                                LinearGradient(
                                    colors: [
                                        Color.yellow.opacity(0.05),
                                        Color.clear,
                                        Color.purple.opacity(0.05)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            }
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [
                                            Color.yellow.opacity(0.3),
                                            Color.purple.opacity(0.2)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.5
                                )
                        )
                        .shadow(color: .yellow.opacity(0.15), radius: 20, x: 0, y: 10)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct ActivitySummaryView: View {
    let activity: Activity?
    @EnvironmentObject var rewardsManager: RewardsManager
    @EnvironmentObject var goalsManager: GoalsManager
    @Environment(\.dismiss) var dismiss
    
    @State private var showCompletionAnimation = false
    @State private var verifiedGoals: [Goal] = []
    @State private var insights: ActivityInsights?
    private let insightsEngine = LLMInsightsEngine()
    
    var body: some View {
        NavigationStack {
            ScrollView {
                if let activity = activity {
                    VStack(spacing: 24) {
                        // Map with route
                        let routePath = activity.mapMatchedPath.isEmpty ? activity.fusedPath : activity.mapMatchedPath
                        MapViewWithPolyline(
                            region: .constant(regionForActivity(activity)),
                            showsUserLocation: false,
                            userTrackingMode: .none,
                            polylineCoordinates: routePath
                        )
                        .frame(height: 300)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        
                        // Stats cards
                        VStack(spacing: 16) {
                            StatCard(
                                title: "Distance",
                                value: formatDistance(activity.distanceMetersMatched),
                                icon: "figure.walk"
                            )
                            
                            HStack(spacing: 16) {
                                StatCard(
                                    title: "Duration",
                                    value: formatTime(activity.durationSeconds),
                                    icon: "clock"
                                )
                                
                                if let pace = activity.avgPaceSecPerKm {
                                    StatCard(
                                        title: "Pace",
                                        value: formatPace(pace),
                                        icon: "speedometer"
                                    )
                                }
                            }
                            
                            HStack(spacing: 16) {
                                StatCard(
                                    title: "Steps",
                                    value: "\(activity.steps)",
                                    icon: "figure.walk"
                                )
                                
                                StatCard(
                                    title: "Confidence",
                                    value: "\(Int(activity.confidenceScoreAvg * 100))%",
                                    icon: "checkmark.shield"
                                )
                            }
                        }
                        
                        // Verified badge
                        if activity.confidenceScoreAvg >= 0.7 && activity.gpsAnomalyCount <= 3 {
                            HStack {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundColor(.green)
                                Text("Verified Activity")
                                    .font(.headline)
                                    .foregroundColor(.white)
                            }
                            .padding()
                            .background(Color.green.opacity(0.2))
                            .clipShape(Capsule())
                        }
                        
                        // LLM Insights
                        if let insights = insights {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Activity Insights")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                Text(insights.summary)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                
                                if !insights.coachingTips.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Coaching Tips")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.green)
                                        
                                        ForEach(insights.coachingTips, id: \.self) { tip in
                                            HStack(alignment: .top, spacing: 8) {
                                                Image(systemName: "lightbulb.fill")
                                                    .foregroundColor(.green)
                                                    .font(.caption)
                                                Text(tip)
                                                    .font(.caption)
                                                    .foregroundColor(.gray)
                                            }
                                        }
                                    }
                                }
                                
                                Text(insights.motivationalMessage)
                                    .font(.subheadline)
                                    .italic()
                                    .foregroundColor(.white.opacity(0.8))
                                    .padding(.top, 8)
                            }
                            .padding()
                            .background(BlurView(style: .systemUltraThinMaterialDark))
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                        }
                        
                        // Goal completion
                        if !verifiedGoals.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Goals Completed")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                ForEach(verifiedGoals) { goal in
                                    GoalCompletionCard(goal: goal)
                                }
                            }
                            .padding()
                            .background(BlurView(style: .systemUltraThinMaterialDark))
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                        }
                    }
                    .padding()
                } else {
                    Text("No activity data")
                        .foregroundColor(.gray)
                }
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Activity Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                verifyGoals()
                generateInsights()
            }
        }
    }
    
    private func generateInsights() {
        guard let activity = activity else { return }
        insights = insightsEngine.generateActivityInsights(activity: activity)
    }
    
    private func verifyGoals() {
        guard let activity = activity else { return }
        
        for goal in goalsManager.getActiveGoals() {
            let result = VerificationEngine.verify(goal: goal, activity: activity)
            if result.passed {
                verifiedGoals.append(goal)
                rewardsManager.completeGoal(goal, activity: activity)
                
                // Update goal status
                var updatedGoal = goal
                updatedGoal.status = .completed
                goalsManager.updateGoal(updatedGoal)
            }
        }
        
        if !verifiedGoals.isEmpty {
            showCompletionAnimation = true
        }
    }
    
    private func regionForActivity(_ activity: Activity) -> MKCoordinateRegion {
        let path = activity.mapMatchedPath.isEmpty ? activity.fusedPath : activity.mapMatchedPath
        guard !path.isEmpty else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 37.334_900, longitude: -122.009_020),
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        }
        
        let lats = path.map { $0.latitude }
        let lons = path.map { $0.longitude }
        let minLat = lats.min()!
        let maxLat = lats.max()!
        let minLon = lons.min()!
        let maxLon = lons.max()!
        
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max(maxLat - minLat, 0.01) * 1.2,
            longitudeDelta: max(maxLon - minLon, 0.01) * 1.2
        )
        
        return MKCoordinateRegion(center: center, span: span)
    }
    
    private func formatDistance(_ meters: Double) -> String {
        if meters >= 1000 {
            return String(format: "%.2f km", meters / 1000.0)
        } else {
            return String(format: "%.0f m", meters)
        }
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let hours = Int(seconds) / 3600
        let minutes = Int(seconds) / 60 % 60
        let secs = Int(seconds) % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }
    
    private func formatPace(_ secondsPerKm: Double) -> String {
        let minutes = Int(secondsPerKm) / 60
        let secs = Int(secondsPerKm) % 60
        return String(format: "%d:%02d min/km", minutes, secs)
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.green)
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(BlurView(style: .systemUltraThinMaterialDark))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct GoalCompletionCard: View {
    let goal: Goal
    
    var body: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            Text(goal.title)
                .font(.headline)
                .foregroundColor(.white)
            Spacer()
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct ContentView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @StateObject private var rewardsManager = RewardsManager()
    @StateObject private var goalsManager = GoalsManager()
    
    var body: some View {
        if horizontalSizeClass == .regular {
            NavigationSplitView {
                List {
                    NavigationLink("Home", value: Tab.home)
                    NavigationLink("Goals", value: Tab.goals)
                    NavigationLink("Profile", value: Tab.profile)
                }
                .listStyle(SidebarListStyle())
                .navigationTitle("Menu")
            } detail: {
                TabViewContainer()
            }
        } else {
            NavigationStack {
                TabViewContainer()
            }
        }
    }
    
    enum Tab: Hashable {
        case home, goals, profile
    }
    
    @State private var selection: Tab = .home
    
    @ViewBuilder
    private func TabViewContainer() -> some View {
        TabView(selection: $selection) {
            HomeMapView()
                .tabItem {
                    Label("Home", systemImage: "map.fill")
                }
                .tag(Tab.home)
            
            GoalsView()
                .tabItem {
                    Label("Goals", systemImage: "target")
                }
                .tag(Tab.goals)
            
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.crop.circle")
                }
                .tag(Tab.profile)
        }
        .preferredColorScheme(.dark)
        .environmentObject(rewardsManager)
        .environmentObject(goalsManager)
    }
}

// Helper for blur effect (UIKit wrapper)
struct BlurView: UIViewRepresentable {
    let style: UIBlurEffect.Style
    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: style))
    }
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}


#Preview {
    Group {
        ContentView()
            .preferredColorScheme(.dark)
    }
}
