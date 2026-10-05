//
//  LargeVideoService.swift
//  Pixart
//

import Photos
import Foundation

nonisolated enum LargeVideoService {
    struct LargeVideoResult: Sendable {
        let assets: [PHAsset]
        let fileSizes: [String: Int64] // localIdentifier -> bytes
    }
    
    /// Fetches all video assets sorted by largest file size first.
    static func fetchLargeVideos(
        maxCount: Int = 100,
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
            items.reserveCapacity(total)
            
            var processed = 0
            fetchResult.enumerateObjects { asset, _, stop in
                if Task.isCancelled {
                    stop.pointee = true
                    return
                }
                
                let size = asset.primaryResourceFileSize ?? 0
                items.append((asset: asset, size: size))
                
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
