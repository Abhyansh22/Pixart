//
//  AssetListViewModel.swift
//  Pixart
//

import Photos
import SwiftUI
import Combine
import Observation

@Observable
@MainActor
final class AssetListViewModel {
    var assets: [PHAsset] = []
    var fileSizes: [String: Int64] = [:]
    var isLoading: Bool = false
    var progressMessage: String?
    
    let category: GalleryCategory
    @ObservationIgnored
    private var loadTask: Task<Void, Never>?
    @ObservationIgnored
    private var cancellables = Set<AnyCancellable>()
    
    init(category: GalleryCategory) {
        self.category = category
        
        PhotoLibraryService.shared.libraryChangePublisher
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.load()
            }
            .store(in: &cancellables)
    }
    
    func load() {
        loadTask?.cancel()
        loadTask = Task {
            isLoading = true
            progressMessage = "Loading assets…"
            
            switch category {
            case .screenshots:
                let result = await ScreenshotService.fetchScreenshots()
                if !Task.isCancelled {
                    self.assets = result
                }
                
            case .videos:
                let result = await VideoService.fetchVideos()
                if !Task.isCancelled {
                    self.assets = result
                }
                
            case .largeVideos:
                progressMessage = "Scanning video storage sizes…"
                let threshold = AppSettings.shared.largeVideoThresholdBytes
                let result = await LargeVideoService.fetchLargeVideos(minThresholdBytes: threshold) { [weak self] done, total in
                    Task { @MainActor in
                        self?.progressMessage = "Scanning videos (\(done)/\(total))…"
                    }
                }
                if !Task.isCancelled {
                    self.assets = result.assets
                    self.fileSizes = result.fileSizes
                }
                
            default:
                break
            }
            
            isLoading = false
            progressMessage = nil
        }
    }
    
    func cancel() {
        loadTask?.cancel()
        loadTask = nil
        isLoading = false
        progressMessage = nil
    }
    
    // MARK: - Prefetching support for smooth scrolling
    func prefetch(around index: Int, window: Int = 30) {
        guard !assets.isEmpty else { return }
        let startIndex = max(0, index - window)
        let endIndex = min(assets.count, index + window)
        let slice = Array(assets[startIndex..<endIndex])
        PhotoLibraryService.shared.startCaching(assets: slice)
    }
}
