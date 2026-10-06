//
//  LargeVideoService.swift
//  Pixart
//

import Photos
import Foundation

private final class VideoSizeCache: @unchecked Sendable {
    static let shared = VideoSizeCache()
    private let lock = NSLock()
    private var cache: [String: Int64] = [:]
    
    func size(for asset: PHAsset) -> Int64 {
        lock.lock()
        if let cached = cache[asset.localIdentifier] {
            lock.unlock()
            return cached
        }
        lock.unlock()
        
        let size = asset.primaryResourceFileSize ?? 0
        
        lock.lock()
        cache[asset.localIdentifier] = size
        lock.unlock()
        return size
    }
    
    func clear() {
        lock.lock()
        cache.removeAll()
        lock.unlock()
    }
}

nonisolated enum LargeVideoService {
    struct LargeVideoResult: Sendable {
        let assets: [PHAsset]
        let fileSizes: [String: Int64] // localIdentifier -> bytes
    }
    
    static func clearCache() {
        VideoSizeCache.shared.clear()
    }
    
    /// Fetches count of video assets whose file size meets or exceeds minThresholdBytes.
    static func fetchCount(minThresholdBytes: Int64 = 200 * 1024 * 1024) async -> Int {
        await Task.detached(priority: .utility) {
            let options = PHFetchOptions()
            let fetchResult = PHAsset.fetchAssets(with: .video, options: options)
            guard fetchResult.count > 0 else { return 0 }
            
            var count = 0
            fetchResult.enumerateObjects { asset, _, stop in
                if Task.isCancelled {
                    stop.pointee = true
                    return
                }
                
                let size = VideoSizeCache.shared.size(for: asset)
                if size >= minThresholdBytes {
                    count += 1
                }
            }
            return count
        }.value
    }
    
    /// Fetches video assets with size >= minThresholdBytes, sorted by largest file size first.
    static func fetchLargeVideos(
        minThresholdBytes: Int64 = 200 * 1024 * 1024,
        maxCount: Int = 200,
        progressHandler: (@Sendable (Int, Int) -> Void)? = nil
    ) async -> LargeVideoResult {
        await Task.detached(priority: .userInitiated) {
            let options = PHFetchOptions()
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            
            let fetchResult = PHAsset.fetchAssets(with: .video, options: options)
            let total = fetchResult.count
            guard total > 0 else {
                return LargeVideoResult(assets: [], fileSizes: [:])
            }
            
            var items: [(asset: PHAsset, size: Int64)] = []
            items.reserveCapacity(min(total, maxCount))
            
            var processed = 0
            fetchResult.enumerateObjects { asset, _, stop in
                if Task.isCancelled {
                    stop.pointee = true
                    return
                }
                
                let size = VideoSizeCache.shared.size(for: asset)
                if size >= minThresholdBytes {
                    items.append((asset: asset, size: size))
                }
                
                processed += 1
                if processed % 20 == 0 || processed == total {
                    progressHandler?(processed, total)
                }
            }
            
            if Task.isCancelled {
                return LargeVideoResult(assets: [], fileSizes: [:])
            }
            
            // Sort by largest file size first
            items.sort { $0.size > $1.size }
            
            // Take top N (or all if fewer)
            let topItems = Array(items.prefix(maxCount))
            var sizeMap: [String: Int64] = [:]
            for item in topItems {
                sizeMap[item.asset.localIdentifier] = item.size
            }
            
            return LargeVideoResult(
                assets: topItems.map(\.asset),
                fileSizes: sizeMap
            )
        }.value
    }
}
