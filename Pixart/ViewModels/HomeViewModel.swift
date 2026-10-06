//
//  HomeViewModel.swift
//  Pixart
//

import Photos
import SwiftUI
import Combine
import Observation

@Observable
@MainActor
final class HomeViewModel {
    var counts: [GalleryCategory: Int] = [:]
    var isLoadingCounts: Bool = false
    
    @ObservationIgnored
    private var cancellables = Set<AnyCancellable>()
    @ObservationIgnored
    private var countTask: Task<Void, Never>?
    
    init() {
        // Observe library changes to update badge counts automatically
        PhotoLibraryService.shared.libraryChangePublisher
            .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshCounts()
            }
            .store(in: &cancellables)
    }
    
    func refreshCounts() {
        countTask?.cancel()
        countTask = Task {
            isLoadingCounts = true
            
            async let screenshotsCount = ScreenshotService.fetchCount()
            async let videosCount = VideoService.fetchCount()
            let threshold = AppSettings.shared.largeVideoThresholdBytes
            async let largeVideosCount = LargeVideoService.fetchCount(minThresholdBytes: threshold)
            
            let scCount = await screenshotsCount
            let vCount = await videosCount
            let lvCount = await largeVideosCount
            
            if !Task.isCancelled {
                counts[.screenshots] = scCount
                counts[.videos] = vCount
                counts[.largeVideos] = lvCount
            }
            isLoadingCounts = false
        }
    }
}
