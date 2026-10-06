//
//  FeaturePrintCache.swift
//  Pixart
//

import Foundation
import Vision
import SwiftData

// MARK: - SwiftData Persistent Model

@Model
final class CachedFeaturePrint {
    @Attribute(.unique) var localIdentifier: String
    @Attribute(.externalStorage) var featureData: Data
    var aspectBand: Int
    var weekBucket: Int64
    
    init(localIdentifier: String, featureData: Data, aspectBand: Int, weekBucket: Int64) {
        self.localIdentifier = localIdentifier
        self.featureData = featureData
        self.aspectBand = aspectBand
        self.weekBucket = weekBucket
    }
}

// MARK: - SwiftData ModelActor Cache

/// Thread-safe SwiftData cache for Vision VNFeaturePrintObservation data.
@ModelActor
actor FeaturePrintCache {
    static let shared: FeaturePrintCache = {
        cleanLegacyDatabaseIfNeeded()
        do {
            let schema = Schema([CachedFeaturePrint.self])
            let config = ModelConfiguration("FeaturePrintStore", isStoredInMemoryOnly: false)
            let container = try ModelContainer(for: schema, configurations: [config])
            return FeaturePrintCache(modelContainer: container)
        } catch {
            fatalError("Failed to initialize ModelContainer for FeaturePrintCache: \(error)")
        }
    }()
    
    /// Cleans up legacy SQLite file from previous versions if present
    private static func cleanLegacyDatabaseIfNeeded() {
        let fileManager = FileManager.default
        if let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let legacySQLite = appSupport.appendingPathComponent("feature_prints_v1.sqlite")
            if fileManager.fileExists(atPath: legacySQLite.path) {
                try? fileManager.removeItem(at: legacySQLite)
            }
        }
    }
    
    struct CachedPrint: @unchecked Sendable {
        let identifier: String
        let observation: VNFeaturePrintObservation
        let aspectBand: Int
        let weekBucket: Int64
    }
    
    /// Returns the set of all asset identifiers already present in the cache.
    func getAllCachedIdentifiers() -> Set<String> {
        var descriptor = FetchDescriptor<CachedFeaturePrint>()
        descriptor.propertiesToFetch = [\.localIdentifier]
        guard let prints = try? modelContext.fetch(descriptor) else { return [] }
        return Set(prints.map(\.localIdentifier))
    }
    
    /// Saves a batch of feature prints to SwiftData.
    func saveBatch(items: [(id: String, observation: VNFeaturePrintObservation, aspectBand: Int, weekBucket: Int64)]) {
        guard !items.isEmpty else { return }
        
        for item in items {
            do {
                let data = try NSKeyedArchiver.archivedData(withRootObject: item.observation, requiringSecureCoding: true)
                let model = CachedFeaturePrint(
                    localIdentifier: item.id,
                    featureData: data,
                    aspectBand: item.aspectBand,
                    weekBucket: item.weekBucket
                )
                modelContext.insert(model)
            } catch {
                print("[FeaturePrintCache] Failed to archive observation for \(item.id): \(error)")
            }
        }
        
        do {
            try modelContext.save()
        } catch {
            print("[FeaturePrintCache] Failed to save batch: \(error)")
        }
    }
    
    /// Loads all cached feature prints.
    func loadAll() -> [CachedPrint] {
        let descriptor = FetchDescriptor<CachedFeaturePrint>()
        guard let models = try? modelContext.fetch(descriptor) else { return [] }
        
        var results = [CachedPrint]()
        results.reserveCapacity(models.count)
        
        for model in models {
            if let observation = try? NSKeyedUnarchiver.unarchivedObject(ofClass: VNFeaturePrintObservation.self, from: model.featureData) {
                results.append(CachedPrint(
                    identifier: model.localIdentifier,
                    observation: observation,
                    aspectBand: model.aspectBand,
                    weekBucket: model.weekBucket
                ))
            }
        }
        return results
    }
    
    /// Removes specified identifiers from the cache (e.g. when deleted from photo library).
    func remove(identifiers: [String]) {
        guard !identifiers.isEmpty else { return }
        let idSet = Set(identifiers)
        let descriptor = FetchDescriptor<CachedFeaturePrint>()
        guard let models = try? modelContext.fetch(descriptor) else { return }
        
        for model in models where idSet.contains(model.localIdentifier) {
            modelContext.delete(model)
        }
        
        try? modelContext.save()
    }
    
    /// Clears all cached feature prints.
    func clear() {
        try? modelContext.delete(model: CachedFeaturePrint.self)
        try? modelContext.save()
    }
}
