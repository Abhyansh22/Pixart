//
//  AppDiagnostics.swift
//  Pixart
//

import Foundation
import Photos

nonisolated enum AppDiagnostics {
    struct TestResults: Sendable {
        let screenshotsCount: Int
        let videosCount: Int
        let duplicatePhotosGroups: Int
        let duplicateVideosGroups: Int
        let similarPhotosGroups: Int
        let largeVideosCount: Int
        let durationSeconds: Double
    }
    
    /// Runs a full diagnostic scan across all 6 categories and verifies pipeline correctness
    static func runDiagnostics() async -> TestResults {
        let startTime = CFAbsoluteTimeGetCurrent()
        print("=== [AppDiagnostics] Starting Full Gallery Diagnostic Scan ===")
        
        // Debug inspect all assets
        let allOptions = PHFetchOptions()
        let allAssets = PHAsset.fetchAssets(with: allOptions)
        print("Total assets in library: \(allAssets.count)")
        
        // 1. Screenshots
        let screenshots = await ScreenshotService.fetchScreenshots()
        print("1. Screenshots fetched: \(screenshots.count)")
        
        // 2. Videos
        let videos = await VideoService.fetchVideos()
        print("2. Videos fetched: \(videos.count)")
        
        // 3. Duplicate Photos
        let duplicatePhotos = await DuplicatePhotoService.findDuplicates()
        print("3. Duplicate Photo Groups: \(duplicatePhotos.count)")
        for (i, group) in duplicatePhotos.enumerated() {
            print("   - Group #\(i + 1): \(group.assets.count) items, size: \(group.formattedSize ?? "unknown")")
        }
        
        // 4. Duplicate Videos
        let duplicateVideos = await DuplicateVideoService.findDuplicates()
        print("4. Duplicate Video Groups: \(duplicateVideos.count)")
        for (i, group) in duplicateVideos.enumerated() {
            print("   - Group #\(i + 1): \(group.assets.count) items, size: \(group.formattedSize ?? "unknown")")
        }
        
        // 5. Similar Photos
        let similarPhotos = await SimilarPhotoService.findSimilarPhotos { progress in
            print("   [SimilarPhotos] \(progress.stage)")
        }
        print("5. Similar Photo Groups: \(similarPhotos.count)")
        for (i, group) in similarPhotos.enumerated() {
            print("   - Similar Group #\(i + 1): \(group.assets.count) items")
        }
        
        // 6. Large Videos
        let largeVideos = await LargeVideoService.fetchLargeVideos()
        print("6. Large Videos sorted: \(largeVideos.assets.count)")
        for (i, asset) in largeVideos.assets.prefix(5).enumerated() {
            let size = largeVideos.fileSizes[asset.localIdentifier] ?? 0
            print("   - Video #\(i + 1): \(ByteCountFormatter.string(fromByteCount: size, countStyle: .file)) (\(asset.formattedDuration ?? "0:00"))")
        }
        
        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        print("=== [AppDiagnostics] Scan Complete in \(String(format: "%.2f", elapsed))s ===")
        
        return TestResults(
            screenshotsCount: screenshots.count,
            videosCount: videos.count,
            duplicatePhotosGroups: duplicatePhotos.count,
            duplicateVideosGroups: duplicateVideos.count,
            similarPhotosGroups: similarPhotos.count,
            largeVideosCount: largeVideos.assets.count,
            durationSeconds: elapsed
        )
    }
}
