//
//  ScreenshotService.swift
//  Pixart
//

import Photos
import Foundation

nonisolated enum ScreenshotService {
    /// Fetches all screenshot assets sorted newest first.
    static func fetchScreenshots() async -> [PHAsset] {
        await Task.detached(priority: .userInitiated) {
            let options = PHFetchOptions()
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            
            // Prefer the system-indexed smart album for screenshots
            let collections = PHAssetCollection.fetchAssetCollections(
                with: .smartAlbum,
                subtype: .smartAlbumScreenshots,
                options: nil
            )
            
            if let screenshotCollection = collections.firstObject {
                let fetchResult = PHAsset.fetchAssets(in: screenshotCollection, options: options)
                if fetchResult.count > 0 {
                    var assets: [PHAsset] = []
                    assets.reserveCapacity(fetchResult.count)
                    fetchResult.enumerateObjects { asset, _, _ in
                        assets.append(asset)
                    }
                    return assets
                }
            }
            
            // Fallback / secondary: check mediaSubtypes or matching screen dimensions
            let allImages = PHAsset.fetchAssets(with: .image, options: options)
            var assets: [PHAsset] = []
            allImages.enumerateObjects { asset, _, _ in
                if asset.mediaSubtypes.contains(.photoScreenshot) {
                    assets.append(asset)
                } else {
                    // On Simulator, imported PNGs matching device screen dimensions
                    let isScreenRes = (asset.pixelWidth == 1170 && asset.pixelHeight == 2532)
                        || (asset.pixelWidth == 1290 && asset.pixelHeight == 2796)
                        || (asset.pixelWidth == 1179 && asset.pixelHeight == 2556)
                        || (asset.pixelWidth == 1206 && asset.pixelHeight == 2622)
                    if isScreenRes {
                        assets.append(asset)
                    }
                }
            }
            return assets
        }.value
    }
    
    /// Quick count of screenshots (metadata only)
    static func fetchCount() async -> Int {
        await Task.detached(priority: .utility) {
            let collections = PHAssetCollection.fetchAssetCollections(
                with: .smartAlbum,
                subtype: .smartAlbumScreenshots,
                options: nil
            )
            if let screenshotCollection = collections.firstObject {
                let count = PHAsset.fetchAssets(in: screenshotCollection, options: nil).count
                if count > 0 { return count }
            }
            
            // Fallback count
            let allImages = PHAsset.fetchAssets(with: .image, options: nil)
            var count = 0
            allImages.enumerateObjects { asset, _, _ in
                if asset.mediaSubtypes.contains(.photoScreenshot)
                    || (asset.pixelWidth == 1170 && asset.pixelHeight == 2532)
                    || (asset.pixelWidth == 1290 && asset.pixelHeight == 2796)
                    || (asset.pixelWidth == 1179 && asset.pixelHeight == 2556)
                    || (asset.pixelWidth == 1206 && asset.pixelHeight == 2622) {
                    count += 1
                }
            }
            return count
        }.value
    }
}
