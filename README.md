# Pixart

**Pixart** is a modern, responsive iOS gallery organizer and storage optimizer built with **SwiftUI**, **PhotoKit**, **Vision**, and **SwiftData**. It categorizes device media into actionable insights to help users identify clutter, reclaim storage, and inspect duplicates with zero UI hitches.

---

## Features

Pixart organizes your device media into six focused categories:

* **📸 Screenshots**: Rapidly surfaces all screen captures for fast cleanup.
* **🎬 Videos**: Browses the complete video collection with duration and metadata indicators.
* **👯 Duplicate Photos**: Identifies exact copies of photos using file size and timestamp matching.
* **🔍 Similar Photos**: Detects visually similar shots (bursts, alternate angles) using Apple's **Vision framework** feature print vectors, clustered efficiently via disjoint-set algorithms.
* **🔁 Duplicate Videos**: Uncovers identical video files taking up redundant storage.
* **📦 Large Videos**: Ranks videos by storage footprint (largest first). Includes a customizable size threshold slider in **Settings** (50 MB – 1 GB, defaulting to 200 MB).

---

## Technical Highlights

* **Modern SwiftUI & Observation**: Fully migrated to the iOS 17+ `@Observable` macro and `@Environment` dependency injection, eliminating legacy `ObservableObject` overhead.
* **Smooth, Non-Blocking Architecture**:
  * Asynchronous, cooperative background scanning (`Task.detached`, concurrency throttling via `TaskLimiter`).
  * On-demand prefetching and opportunistic thumbnail caching with `PHCachingImageManager`.
  * The main thread never blocks, maintaining 60/120 fps scrolling even across thousands of assets.
* **SwiftData Feature-Print Cache**:
  * Vision observation vectors are persisted via SwiftData (`@ModelActor` + `@Model`).
  * Subsequent launches cluster similar photos near-instantaneously without re-analyzing images.
* **HIG-Compliant Permission & Settings Flow**:
  * Native, deferred photo library permission onboarding.
  * Settings sheet featuring an interactive threshold slider with preset snapping and selection haptics.

---

## Requirements

* **iOS**: 17.0+
* **Xcode**: 16.0+
* **Swift**: 5.9+ / Swift 6

---

## Getting Started

1. Clone the repository:
   ```bash
   git clone https://github.com/<your-username>/Pixart.git
   cd Pixart
   ```
2. Open `Pixart.xcodeproj` in Xcode.
3. Select your target device or iOS Simulator.
4. Build and run (**⌘R**).
