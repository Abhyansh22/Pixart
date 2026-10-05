//
//  SimilarPhotoService.swift
//  Pixart
//

import Photos
import Vision
import UIKit

nonisolated enum SimilarPhotoService {
    /// Progress info for UI updates
    struct AnalysisProgress: Sendable {
        let completed: Int
        let total: Int
        let stage: String
    }
    
    typealias PrintItem = (id: String, observation: VNFeaturePrintObservation, aspectBand: Int, weekBucket: Int64)
    
    /// Similarity distance threshold: distances below this are considered visually similar.
    /// Empirically for VNFeaturePrintObservation, < 8.5 captures near-duplicate/burst shots.
    static let similarityDistanceThreshold: Float = 8.5
    
    /// Maximum number of photos to analyze in one pass to guarantee snappy response
    static let maxScanLimit: Int = 2000
    
    /// Union-Find / Disjoint Set Union helper
    final class DisjointSet: @unchecked Sendable {
        private var parent: [String: String] = [:]
        
        func find(_ id: String) -> String {
            if parent[id] == nil {
                parent[id] = id
                return id
            }
            if parent[id] != id {
                parent[id] = find(parent[id]!)
            }
            return parent[id]!
        }
        
        func union(_ id1: String, _ id2: String) {
            let root1 = find(id1)
            let root2 = find(id2)
            if root1 != root2 {
                parent[root2] = root1
            }
        }
    }
    
    /// Finds similar photo groups using Vision feature vectors and bucketing
    static func findSimilarPhotos(
        progressHandler: (@Sendable (AnalysisProgress) -> Void)? = nil
    ) async -> [AssetGroup] {
        await Task.detached(priority: .userInitiated) {
            let options = PHFetchOptions()
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            let fetchResult = PHAsset.fetchAssets(with: .image, options: options)
            let totalInLibrary = fetchResult.count
            guard totalInLibrary > 1 else { return [] }
            
            // Limit to most recent N photos if library is massive
            let scanLimit = min(totalInLibrary, maxScanLimit)
            var assetsToScan: [PHAsset] = []
            assetsToScan.reserveCapacity(scanLimit)
            
            var assetMap: [String: PHAsset] = [:]
            for i in 0..<scanLimit {
                let asset = fetchResult.object(at: i)
                if asset.mediaSubtypes.contains(.photoScreenshot) {
                    continue
                }
                assetsToScan.append(asset)
                assetMap[asset.localIdentifier] = asset
            }
            
            // Stage 1: Check cached feature prints
            progressHandler?(AnalysisProgress(completed: 0, total: assetsToScan.count, stage: "Checking cache…"))
            let cachedIds = await FeaturePrintCache.shared.getAllCachedIdentifiers()
            
            let unanalyzedAssets = assetsToScan.filter { !cachedIds.contains($0.localIdentifier) }
            
            // Stage 2: Generate prints for new assets using TaskLimiter (concurrency = 4)
            if !unanalyzedAssets.isEmpty {
                let limiter = TaskLimiter(maxConcurrent: 4)
                let totalUnanalyzed = unanalyzedAssets.count
                var completedCount = 0
                var batchBuffer: [PrintItem] = []
                
                await withTaskGroup(of: PrintItem?.self) { group in
                    for asset in unanalyzedAssets {
                        if Task.isCancelled { break }
                        
                        group.addTask {
                            if Task.isCancelled { return nil }
                            
                            return await limiter.executeNonThrowing {
                                guard let observation = generateFeaturePrint(for: asset) else {
                                    return nil
                                }
                                return (
                                    id: asset.localIdentifier,
                                    observation: observation,
                                    aspectBand: asset.aspectRatioBand,
                                    weekBucket: asset.creationWeekBucket
                                )
                            }
                        }
                    }
                    
                    for await item in group {
                        if let validItem = item {
                            batchBuffer.append(validItem)
                            completedCount += 1
                            
                            if batchBuffer.count >= 25 {
                                let toSave = batchBuffer
                                batchBuffer.removeAll(keepingCapacity: true)
                                await FeaturePrintCache.shared.saveBatch(items: toSave)
                            }
                            
                            if completedCount % 5 == 0 || completedCount == totalUnanalyzed {
                                progressHandler?(AnalysisProgress(
                                    completed: completedCount,
                                    total: totalUnanalyzed,
                                    stage: "Analyzing photos (\(completedCount)/\(totalUnanalyzed))…"
                                ))
                            }
                        }
                    }
                }
                
                // Flush remaining buffer
                if !batchBuffer.isEmpty {
                    await FeaturePrintCache.shared.saveBatch(items: batchBuffer)
                }
            }
            
            if Task.isCancelled { return [] }
            
            // Stage 3: Load cached prints & cluster by bucket
            progressHandler?(AnalysisProgress(completed: assetsToScan.count, total: assetsToScan.count, stage: "Clustering similar photos…"))
            
            let allPrints = await FeaturePrintCache.shared.loadAll()
            // Filter to only those in current scan set
            let relevantPrints = allPrints.filter { assetMap[$0.identifier] != nil }
            
            // Bucket prints by (aspectBand, weekBucket)
            struct BucketKey: Hashable {
                let aspectBand: Int
                let weekBucket: Int64
            }
            
            var buckets: [BucketKey: [FeaturePrintCache.CachedPrint]] = [:]
            for printItem in relevantPrints {
                let key = BucketKey(aspectBand: printItem.aspectBand, weekBucket: printItem.weekBucket)
                buckets[key, default: []].append(printItem)
            }
            
            let dsu = DisjointSet()
            
            for (_, bucketItems) in buckets {
                if Task.isCancelled { break }
                guard bucketItems.count >= 2 else { continue }
                
                // Pairwise comparison within the bucket
                for i in 0..<bucketItems.count {
                    for j in (i + 1)..<bucketItems.count {
                        let a = bucketItems[i]
                        let b = bucketItems[j]
                        
                        var distance: Float = 0
                        do {
                            try a.observation.computeDistance(&distance, to: b.observation)
                            if distance < similarityDistanceThreshold {
                                dsu.union(a.identifier, b.identifier)
                            }
                        } catch {
                            // Skip invalid comparison
                        }
                    }
                }
            }
            
            if Task.isCancelled { return [] }
            
            // Group identifiers by root parent
            var clusters: [String: [String]] = [:]
            for item in relevantPrints {
                let root = dsu.find(item.identifier)
                clusters[root, default: []].append(item.identifier)
            }
            
            // Filter clusters with >= 2 items
            var resultGroups: [AssetGroup] = []
            var groupNumber = 1
            
            for (_, ids) in clusters where ids.count >= 2 {
                let assets = ids.compactMap { assetMap[$0] }
                guard assets.count >= 2 else { continue }
                
                let group = AssetGroup(
                    title: "Similar Set #\(groupNumber)",
                    assets: assets
                )
                groupNumber += 1
                resultGroups.append(group)
            }
            
            return resultGroups
        }.value
    }
    
    /// Generates a feature print for a single asset using image data or thumbnail
    private static func generateFeaturePrint(for asset: PHAsset) -> VNFeaturePrintObservation? {
        let dataOptions = PHImageRequestOptions()
        dataOptions.isSynchronous = true
        dataOptions.isNetworkAccessAllowed = true
        dataOptions.deliveryMode = .highQualityFormat
        
        var assetData: Data?
        var assetOrientation: CGImagePropertyOrientation = .up
        
        PHImageManager.default().requestImageDataAndOrientation(for: asset, options: dataOptions) { data, _, orientation, _ in
            assetData = data
            assetOrientation = orientation
        }
        
        if let data = assetData {
            let request = VNGenerateImageFeaturePrintRequest()
            let handler = VNImageRequestHandler(data: data, orientation: assetOrientation, options: [:])
            do {
                try handler.perform([request])
                if let result = request.results?.first as? VNFeaturePrintObservation {
                    return result
                }
            } catch {
                // Ignore and proceed to fallback
            }
        }
        
        // Fallback: requestImage
        let imgOptions = PHImageRequestOptions()
        imgOptions.isSynchronous = true
        imgOptions.isNetworkAccessAllowed = true
        imgOptions.deliveryMode = .highQualityFormat
        
        var fetchedImage: UIImage?
        PHImageManager.default().requestImage(
            for: asset,
            targetSize: CGSize(width: 300, height: 300),
            contentMode: .aspectFill,
            options: imgOptions
        ) { image, _ in
            fetchedImage = image
        }
        
        guard let image = fetchedImage, let cgImage = image.cgImage else {
            return nil
        }
        
        let request = VNGenerateImageFeaturePrintRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
            return request.results?.first as? VNFeaturePrintObservation
        } catch {
            return nil
        }
    }
}
