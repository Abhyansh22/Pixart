//
//  GroupedAssetViewModel.swift
//  Pixart
//

import Photos
import SwiftUI
import Combine
import Observation

@Observable
@MainActor
final class GroupedAssetViewModel {
    var groups: [AssetGroup] = []
    var isLoading: Bool = false
    var progressStage: String?
    var progressFraction: Double?
    
    let category: GalleryCategory
    @ObservationIgnored
    private var scanTask: Task<Void, Never>?
    @ObservationIgnored
    private var cancellables = Set<AnyCancellable>()
    
    init(category: GalleryCategory) {
        self.category = category
        
        PhotoLibraryService.shared.libraryChangePublisher
            .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.load()
            }
            .store(in: &cancellables)
    }
    
    func load() {
        scanTask?.cancel()
        groups.removeAll()
        isLoading = true
        progressStage = "Analyzing library…"
        progressFraction = nil
        
        scanTask = Task {
            switch category {
            case .duplicatePhotos:
                let result = await DuplicatePhotoService.findDuplicates { [weak self] group in
                    Task { @MainActor in
                        self?.groups.append(group)
                    }
                }
                if !Task.isCancelled {
                    self.groups = result
                }
                
            case .duplicateVideos:
                let result = await DuplicateVideoService.findDuplicates { [weak self] group in
                    Task { @MainActor in
                        self?.groups.append(group)
                    }
                }
                if !Task.isCancelled {
                    self.groups = result
                }
                
            case .similarPhotos:
                let result = await SimilarPhotoService.findSimilarPhotos { [weak self] progress in
                    Task { @MainActor in
                        self?.progressStage = progress.stage
                        if progress.total > 0 {
                            self?.progressFraction = Double(progress.completed) / Double(progress.total)
                        }
                    }
                }
                if !Task.isCancelled {
                    self.groups = result
                }
                
            default:
                break
            }
            
            isLoading = false
            progressStage = nil
            progressFraction = nil
        }
    }
    
    func cancel() {
        scanTask?.cancel()
        scanTask = nil
        isLoading = false
        progressStage = nil
        progressFraction = nil
    }
}
