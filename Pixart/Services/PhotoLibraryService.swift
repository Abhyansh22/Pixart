//
//  PhotoLibraryService.swift
//  Pixart
//

import UIKit
import Photos
import Combine
import Observation

@Observable
@MainActor
final class PhotoLibraryService: NSObject {
    static let shared = PhotoLibraryService()
    
    var authorizationStatus: PHAuthorizationStatus = .notDetermined
    
    @ObservationIgnored
    let libraryChangePublisher = PassthroughSubject<PHChange, Never>()
    
    @ObservationIgnored
    private let imageManager = PHCachingImageManager()
    
    @ObservationIgnored
    private var isObserverRegistered = false
    
    override init() {
        super.init()
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        self.authorizationStatus = status
        print("[PhotoLibraryService] init status=\(status.rawValue)")
        registerObserverIfNeeded()
    }
    
    deinit {
        if isObserverRegistered {
            PHPhotoLibrary.shared().unregisterChangeObserver(self)
        }
    }
    
    func registerObserverIfNeeded() {
        guard !isObserverRegistered else { return }
        if authorizationStatus == .authorized || authorizationStatus == .limited {
            PHPhotoLibrary.shared().register(self)
            isObserverRegistered = true
        }
    }
    
    func checkAuthorization() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        authorizationStatus = status
        print("[PhotoLibraryService] checkAuthorization status=\(status.rawValue)")
        registerObserverIfNeeded()
    }
    
    func requestAuthorization() async -> PHAuthorizationStatus {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        self.authorizationStatus = status
        print("[PhotoLibraryService] requestAuthorization returned status=\(status.rawValue)")
        registerObserverIfNeeded()
        return status
    }
    
    // MARK: - Thumbnail & Full-res Requests
    
    /// Requests a thumbnail image for a given asset.
    /// Returns the initial or best available thumbnail image.
    func requestThumbnail(
        for asset: PHAsset,
        targetSize: CGSize = CGSize(width: 250, height: 250),
        completion: @escaping @Sendable (UIImage?) -> Void
    ) -> PHImageRequestID {
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.isNetworkAccessAllowed = true
        options.resizeMode = .fast
        
        return imageManager.requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: options
        ) { image, _ in
            completion(image)
        }
    }
    
    /// Async request for thumbnail
    func requestThumbnailAsync(
        for asset: PHAsset,
        targetSize: CGSize = CGSize(width: 250, height: 250)
    ) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            options.resizeMode = .fast
            
            var resumed = false
            self.imageManager.requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                if !resumed {
                    resumed = true
                    continuation.resume(returning: image)
                }
            }
        }
    }
    
    /// Requests full-resolution image for preview
    func requestFullImage(for asset: PHAsset) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            
            var resumed = false
            self.imageManager.requestImage(
                for: asset,
                targetSize: PHImageManagerMaximumSize,
                contentMode: .aspectFit,
                options: options
            ) { image, _ in
                if !resumed {
                    resumed = true
                    continuation.resume(returning: image)
                }
            }
        }
    }
    
    /// Cancels an in-flight image request
    func cancelImageRequest(_ requestID: PHImageRequestID) {
        imageManager.cancelImageRequest(requestID)
    }
    
    // MARK: - Caching
    
    func startCaching(assets: [PHAsset], targetSize: CGSize = CGSize(width: 250, height: 250)) {
        guard !assets.isEmpty else { return }
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.isNetworkAccessAllowed = true
        imageManager.startCachingImages(for: assets, targetSize: targetSize, contentMode: .aspectFill, options: options)
    }
    
    func stopCaching(assets: [PHAsset], targetSize: CGSize = CGSize(width: 250, height: 250)) {
        guard !assets.isEmpty else { return }
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.isNetworkAccessAllowed = true
        imageManager.stopCachingImages(for: assets, targetSize: targetSize, contentMode: .aspectFill, options: options)
    }
    
    func stopAllCaching() {
        imageManager.stopCachingImagesForAllAssets()
    }
}

// MARK: - PHPhotoLibraryChangeObserver
extension PhotoLibraryService: PHPhotoLibraryChangeObserver {
    nonisolated func photoLibraryDidChange(_ changeInstance: PHChange) {
        LargeVideoService.clearCache()
        Task { @MainActor in
            self.libraryChangePublisher.send(changeInstance)
        }
    }
}
