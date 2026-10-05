//
//  AssetGroup.swift
//  Pixart
//

import Photos
import Foundation

nonisolated struct AssetGroup: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let title: String
    public let assets: [PHAsset]
    public let totalByteSize: Int64?
    
    public init(id: UUID = UUID(), title: String = "", assets: [PHAsset], totalByteSize: Int64? = nil) {
        self.id = id
        self.title = title
        self.assets = assets
        self.totalByteSize = totalByteSize
    }
    
    public var representativeAsset: PHAsset? {
        assets.first
    }
    
    public var formattedSize: String? {
        guard let size = totalByteSize, size > 0 else { return nil }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
    
    public static func == (lhs: AssetGroup, rhs: AssetGroup) -> Bool {
        lhs.id == rhs.id && lhs.assets.map(\.localIdentifier) == rhs.assets.map(\.localIdentifier)
    }
}
