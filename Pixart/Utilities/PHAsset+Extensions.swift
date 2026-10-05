//
//  PHAsset+Extensions.swift
//  Pixart
//

import Photos
import Foundation

extension PHAsset: @retroactive Identifiable {
    public var id: String {
        localIdentifier
    }
}

nonisolated extension PHAsset {
    /// Extracts the file size in bytes from the primary PHAssetResource.
    /// Uses KVC value(forKey: "fileSize") with fallback mechanisms.
    var primaryResourceFileSize: Int64? {
        let resources = PHAssetResource.assetResources(for: self)
        // Prefer resource matching the asset's media type
        let primaryResource = resources.first { res in
            if mediaType == .video {
                return res.type == .video
            } else {
                return res.type == .photo || res.type == .fullSizePhoto
            }
        } ?? resources.first
        
        guard let resource = primaryResource else { return nil }
        
        if let sizeNumber = resource.value(forKey: "fileSize") as? NSNumber {
            return sizeNumber.int64Value
        }
        return nil
    }
    
    /// Formatted file size string (e.g., "14.2 MB", "1.35 GB")
    var formattedFileSize: String? {
        guard let bytes = primaryResourceFileSize else { return nil }
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
    
    /// Formatted video duration string (e.g. "0:45", "12:03")
    var formattedDuration: String? {
        guard mediaType == .video else { return nil }
        let totalSeconds = Int(duration)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    /// Formatted dimensions string (e.g., "1170 × 2532")
    var formattedDimensions: String {
        "\(pixelWidth) × \(pixelHeight)"
    }
    
    /// Aspect ratio category for similarity bucketing (Portrait, Square, Landscape)
    var aspectRatioBand: Int {
        guard pixelHeight > 0 else { return 0 }
        let ratio = Double(pixelWidth) / Double(pixelHeight)
        if ratio < 0.85 {
            return 1 // Portrait
        } else if ratio <= 1.15 {
            return 2 // Square-ish
        } else {
            return 3 // Landscape
        }
    }
    
    /// Rounded timestamp in seconds (discarding millisecond variance)
    var roundedCreationTimestamp: Int64 {
        guard let date = creationDate else { return 0 }
        return Int64(date.timeIntervalSince1970.rounded())
    }
    
    /// 7-day epoch window for coarse temporal bucketing
    var creationWeekBucket: Int64 {
        guard let date = creationDate else { return 0 }
        let secondsPerWeek: Double = 7 * 24 * 60 * 60
        return Int64((date.timeIntervalSince1970 / secondsPerWeek).rounded(.down))
    }
}
