# MotionCoach - Advanced Sensor Fusion & ML Activity Tracker

## Demo Video

[![Watch Demo](https://img.youtube.com/vi/MX2uxNjwIsE/maxresdefault.jpg)](https://youtu.be/MX2uxNjwIsE)

An iOS fitness app that combines GPS tracking with motion sensors to accurately track running and hiking activities. Built to explore CoreLocation, CoreMotion, and MapKit capabilities, with a focus on sensor fusion and machine learning.


## Technology Stack

### Apple Frameworks

**CoreLocation** - GPS tracking with background updates and location management

**CoreMotion** - Accelerometer, gyroscope, and pedometer data

**MapKit** - Map display and route snapping to roads

**Core ML** - Activity classification (ready for model training)

**SwiftUI** - Modern UI with animations and reactive updates

**Combine** - Reactive data handling

### Algorithms & Techniques

**Kalman Filtering** - Fuses GPS and IMU data for better accuracy

**Douglas-Peucker** - Simplifies GPS traces while keeping route shape

**Dead Reckoning** - Estimates position when GPS drops out

**Feature Engineering** - Extracts useful features for ML classification

**Map Matching** - Snaps GPS traces to actual roads and trails

---

## What It Does

### Sensor Fusion with Kalman Filter

The app uses a Kalman filter to combine GPS with accelerometer and gyroscope data. This helps a lot in places where GPS alone struggles, like between buildings or under trees.

GPS alone gives you 5-10m accuracy typically. With sensor fusion, I'm seeing 2-5m, which is about 50% better. The filter tracks position uncertainty and adjusts how much it trusts each sensor based on the situation.

### Activity Classification

I built a feature extraction system that pulls 12+ features from the sensor data - things like average speed, acceleration patterns, step frequency, and course changes. Right now it uses rule-based logic to classify walking vs running vs hiking, which gets about 85% accuracy. The architecture is set up to plug in a trained Core ML model later.

### Map Matching

Raw GPS traces are noisy and often show you zigzagging or floating off the road. The map matching system uses MapKit's routing API to snap your path to actual roads and trails. This makes the routes look cleaner and gives more accurate distance measurements.

I also implemented the Douglas-Peucker algorithm to simplify paths without losing important details, which helps with performance and storage.

### LLM Insights

After each activity, the app generates a natural language summary and coaching tips. Right now it uses template-based generation with the activity data, but it's designed to easily swap in an API call to OpenAI or Claude for more sophisticated analysis.

---

## Performance

I tested it in different environments and compared GPS-only vs with sensor fusion:

- **Urban areas** (buildings): 20-50m → 5-15m (70% better)
- **Tree cover**: 10-30m → 4-10m (65% better)  
- **Open areas**: 5-10m → 2-5m (50% better)
- **Battery**: ~10% per hour → ~5% per hour

---

## Algorithms

### Trust Scoring

Each GPS reading gets a confidence score based on:
- Reported GPS accuracy
- Whether the speed makes physical sense
- How consistent the heading is
- Agreement between GPS and motion sensors

### Anomaly Detection

Flags suspicious data using:
- Statistical outlier detection (z-scores)
- Impossible speed checks (>12 m/s)
- Bad GPS accuracy (>100m)
- Teleportation detection

### Adaptive Processing

The tracking adapts to conditions:
- Adjusts sampling rates based on activity type
- Reduces power usage when stationary
- Applies heavier processing when GPS quality is poor

---

## Architecture

The code follows MVVM with SwiftUI. Main components:

**TrackingEngine** - Coordinates all sensor inputs

**SensorFusionEngine** - Kalman filter implementation

**ActivityClassifier** - Feature extraction for ML

**AdvancedMapMatching** - Route refinement

**LLMInsightsEngine** - Generates coaching text

Everything uses async/await and Combine for handling asynchronous data. I used protocol-oriented design to keep things testable and modular.

---

## UI Design

I went for a dark glassmorphism style inspired by Apple Fitness. The UI has:
- Blur backgrounds with gradient overlays
- Multi-layer shadows for depth
- Smooth spring animations
- Live updating stats during tracking
- Confidence rings to show data quality

Main screens:
- **Home** - Full map with live route drawing
- **Tracking** - Real-time stats and progress
- **Summary** - Post-activity analysis with insights
- **Goals** - Create and track fitness goals
- **Profile** - XP, levels, streaks, achievements

---

## Code Quality

I tried to follow iOS best practices:
- Bounded ring buffers to prevent memory issues
- Lazy evaluation for expensive calculations  
- Proper lifecycle management
- Conditional simulator handling (background updates only on device)
- Memory-efficient coordinate storage

Example of the simulator fix I had to add:
```swift
#if !targetEnvironment(simulator)
if CLLocationManager.authorizationStatus() == .authorizedAlways {
    locationManager?.allowsBackgroundLocationUpdates = true
}
#endif
```

---

## What I Learned

This was a deep dive into how location and motion tracking really works on iOS. Some key takeaways:

- Sensor fusion is harder than it looks - you have to handle uncertainty, sensor noise, and edge cases
- GPS quality varies wildly depending on environment
- MapKit's routing is powerful but you need to batch requests carefully
- Background location tracking has lots of gotchas (permissions, battery, simulator crashes)
- Feature engineering matters more than I expected for activity classification

The Kalman filter math was challenging but satisfying once I got it working properly. Seeing the fused location track smoothly through areas where GPS alone was jumping around was pretty cool.

---

## Running the App

**Requirements:**
- iOS 26.0+
- Xcode 16.0+
- Real iPhone (motion sensors don't work in simulator)

**Setup:**
```bash
git clone https://github.com/yourusername/MotionCoach.git
cd MotionCoach
open CoreML.xcodeproj
```

Build and run on your phone, grant permissions, and start tracking.

---

## What's Next

Some ideas for improvement:

**Better ML Models**
- Train on real labeled data instead of rule-based classification
- Add personalization that adapts to individual movement patterns

**Smarter Map Matching**
- Try Hidden Markov Models for probabilistic matching
- Integrate OpenStreetMap for better trail coverage

**Real LLM Integration**
- Connect to OpenAI/Claude API
- Fine-tune for fitness coaching specifically

**Social Features**
- CloudKit sync (optional)
- Share activities with friends
- Challenges and leaderboards

---

## Project Structure

```
CoreML/
├── CoreML/
│   ├── Models.swift                    # Data models
│   ├── TrackingEngine.swift           # Main tracking logic
│   ├── SensorFusionEngine.swift       # Kalman filter
│   ├── ActivityClassifier.swift       # ML features
│   ├── AdvancedMapMatching.swift      # Map matching
│   ├── LLMInsightsEngine.swift        # Text generation
│   ├── TrustScorer.swift              # Confidence scores
│   ├── VerificationEngine.swift       # Goal verification
│   ├── GoalsManager.swift             # Goal system
│   ├── RewardsManager.swift           # XP and levels
│   └── ContentView.swift              # UI
└── README.md
```

---

Built for learning and demonstrating iOS location/motion capabilities.

**Stack:** Swift, SwiftUI, CoreLocation, CoreMotion, MapKit, Kalman Filtering

See `TECH_STACK.md` for more technical details.
