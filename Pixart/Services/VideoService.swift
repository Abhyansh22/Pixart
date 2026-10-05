//
//  VideoService.swift
//  Pixart
//

import Photos
import Foundation

nonisolated enum VideoService {
    /// Fetches all video assets sorted newest first.
    static func fetchVideos() async -> [PHAsset] {
        await Task.detached(priority: .userInitiated) {
            let options = PHFetchOptions()
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            
            let fetchResult = PHAsset.fetchAssets(with: .video, options: options)
            var assets: [PHAsset] = []
            assets.reserveCapacity(fetchResult.count)
            fetchResult.enumerateObjects { asset, _, _ in
                assets.append(asset)
            }
            return assets
        }.value
    }
    
    /// Quick count of all videos (metadata only)
    static func fetchCount() async -> Int {
        await Task.detached(priority: .utility) {
            let options = PHFetchOptions()
            return PHAsset.fetchAssets(with: .video, options: options).count
        }.value
    }
}
