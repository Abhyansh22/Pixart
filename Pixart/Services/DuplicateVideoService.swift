//
//  DuplicateVideoService.swift
//  Pixart
//

import Photos
import Foundation

nonisolated enum DuplicateVideoService {
    /// Discovers exact duplicate videos using duration, dimensions, timestamp, and resource file size.
    static func findDuplicates(
        onGroupFound: (@Sendable (AssetGroup) -> Void)? = nil
    ) async -> [AssetGroup] {
        await Task.detached(priority: .userInitiated) {
            let options = PHFetchOptions()
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            
            let fetchResult = PHAsset.fetchAssets(with: .video, options: options)
            guard fetchResult.count > 1 else { return [] }
            
            // Pass 1: Bucket by dimensions, rounded duration, and rounded creation timestamp
            struct CandidateKey: Hashable {
                let width: Int
                let height: Int
                let durationTenths: Int
                let timestamp: Int64
            }
            
            var candidateBuckets: [CandidateKey: [PHAsset]] = [:]
            
            fetchResult.enumerateObjects { asset, _, stop in
                if Task.isCancelled {
                    stop.pointee = true
                    return
                }
                
                let durationTenths = Int((asset.duration * 10).rounded())
                let key = CandidateKey(
                    width: asset.pixelWidth,
                    height: asset.pixelHeight,
                    durationTenths: durationTenths,
                    timestamp: asset.roundedCreationTimestamp
                )
                candidateBuckets[key, default: []].append(asset)
            }
            
            if Task.isCancelled { return [] }
            
            let candidateGroups = candidateBuckets.values.filter { $0.count >= 2 }
            var confirmedGroups: [AssetGroup] = []
            var groupIndex = 1
            
            for candidates in candidateGroups {
                if Task.isCancelled { break }
                
                var sizeBuckets: [Int64: [PHAsset]] = [:]
                for asset in candidates {
                    if let size = asset.primaryResourceFileSize, size > 0 {
                        sizeBuckets[size, default: []].append(asset)
                    }
                }
                
                for (size, assets) in sizeBuckets where assets.count >= 2 {
                    let group = AssetGroup(
                        title: "Video Duplicate #\(groupIndex)",
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
