//
//  HomeViewModel.swift
//  Pixart
//

import Photos
import SwiftUI
import Combine

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var counts: [GalleryCategory: Int] = [:]
    @Published var isLoadingCounts: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
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
            
            let scCount = await screenshotsCount
            let vCount = await videosCount
            
            if !Task.isCancelled {
                counts[.screenshots] = scCount
                counts[.videos] = vCount
                counts[.largeVideos] = vCount // Same pool of videos
            }
            isLoadingCounts = false
        }
    }
}
