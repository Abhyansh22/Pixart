//
//  DuplicatePhotoService.swift
//  Pixart
//

import Photos
import Foundation

nonisolated enum DuplicatePhotoService {
    /// Discovers exact duplicate photos using a two-pass metadata and resource size pipeline.
    /// Returns groups of 2 or more identical photos.
    static func findDuplicates(
        onGroupFound: (@Sendable (AssetGroup) -> Void)? = nil
    ) async -> [AssetGroup] {
        await Task.detached(priority: .userInitiated) {
            let options = PHFetchOptions()
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            
            let fetchResult = PHAsset.fetchAssets(with: .image, options: options)
            guard fetchResult.count > 1 else { return [] }
            
            // Pass 1: Bucket by dimensions and creation time (rounded to 1s)
            struct CandidateKey: Hashable {
                let width: Int
                let height: Int
                let timestamp: Int64
            }
            
            var candidateBuckets: [CandidateKey: [PHAsset]] = [:]
            
            fetchResult.enumerateObjects { asset, index, stop in
                if Task.isCancelled {
                    stop.pointee = true
                    return
                }
                
                // Exclude screenshots
                if asset.mediaSubtypes.contains(.photoScreenshot) {
                    return
                }
                
                let key = CandidateKey(
                    width: asset.pixelWidth,
                    height: asset.pixelHeight,
                    timestamp: asset.roundedCreationTimestamp
                )
                candidateBuckets[key, default: []].append(asset)
            }
            
            if Task.isCancelled { return [] }
            
            // Filter buckets with at least 2 items
            let candidateGroups = candidateBuckets.values.filter { $0.count >= 2 }
            
            // Pass 2: Confirm exact duplicates via PHAssetResource file size
            var confirmedGroups: [AssetGroup] = []
            var groupIndex = 1
            
            for candidates in candidateGroups {
                if Task.isCancelled { break }
                
                // Group candidates by file size
                var sizeBuckets: [Int64: [PHAsset]] = [:]
                for asset in candidates {
                    if let size = asset.primaryResourceFileSize, size > 0 {
                        sizeBuckets[size, default: []].append(asset)
                    }
                }
                
                for (size, assets) in sizeBuckets where assets.count >= 2 {
                    let group = AssetGroup(
                        title: "Photo Duplicate #\(groupIndex)",
                        assets: assets,
                        totalByteSize: size * Int64(assets.count)
                    )
                    groupIndex += 1
                    confirmedGroups.append(group)
                    onGroupFound?(group)
                }
            }
            
            return confirmedGroups
        }.value
    }
}
