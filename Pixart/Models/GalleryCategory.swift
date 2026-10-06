//
//  GalleryCategory.swift
//  Pixart
//

import SwiftUI

nonisolated enum GalleryCategory: String, CaseIterable, Identifiable, Sendable {
    case screenshots
    case videos
    case duplicatePhotos
    case similarPhotos
    case duplicateVideos
    case largeVideos
    
    public var id: String { rawValue }
    
    public var title: String {
        switch self {
        case .screenshots:
            return "Screenshots"
        case .videos:
            return "Videos"
        case .duplicatePhotos:
            return "Duplicate Photos"
        case .similarPhotos:
            return "Similar Photos"
        case .duplicateVideos:
            return "Duplicate Videos"
        case .largeVideos:
            return "Large Videos"
        }
    }
    
    public var subtitle: String {
        switch self {
        case .screenshots:
            return "All captured screens"
        case .videos:
            return "Full video library"
        case .duplicatePhotos:
            return "Exact photo copies"
        case .similarPhotos:
            return "Visually resembling shots"
        case .duplicateVideos:
            return "Exact video duplicates"
        case .largeVideos:
            return "Heavy storage consumers"
        }
    }
    
    public var iconName: String {
        switch self {
        case .screenshots:
            return "camera.viewfinder"
        case .videos:
            return "video.fill"
        case .duplicatePhotos:
            return "doc.on.doc.fill"
        case .similarPhotos:
            return "photo.stack.fill"
        case .duplicateVideos:
            return "photo.on.rectangle.fill"
        case .largeVideos:
            return "opticaldiscdrive"
        }
    }
    
    public var themeColor: Color {
        switch self {
        case .screenshots:
            return .blue
        case .videos:
            return .purple
        case .duplicatePhotos:
            return .orange
        case .similarPhotos:
            return .pink
        case .duplicateVideos:
            return .indigo
        case .largeVideos:
            return .red
        }
    }
    
    public var isGrouped: Bool {
        switch self {
        case .duplicatePhotos, .similarPhotos, .duplicateVideos:
            return true
        case .screenshots, .videos, .largeVideos:
            return false
        }
    }
}
