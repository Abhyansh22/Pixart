//
//  ThumbnailView.swift
//  Pixart
//

import SwiftUI
import Photos

struct ThumbnailView: View {
    let asset: PHAsset
    var badgeText: String? = nil
    var targetSize: CGSize = CGSize(width: 250, height: 250)
    
    @State private var image: UIImage?
    @State private var requestID: PHImageRequestID?
    
    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottomTrailing) {
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Color(uiColor: .secondarySystemBackground))
                        .overlay(
                            Image(systemName: asset.mediaType == .video ? "video" : "photo")
                                .foregroundStyle(.tertiary)
                                .font(.system(size: 20))
                        )
                }
                
                // Top-leading badge (e.g. file size)
                if let badge = badgeText {
                    VStack {
                        HStack {
                            Text(badge)
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(.black.opacity(0.65), in: Capsule())
                                .foregroundStyle(.white)
                            Spacer()
                        }
                        Spacer()
                    }
                    .padding(5)
                }
                
                // Bottom-trailing badge (video duration or fallback badge)
                if asset.mediaType == .video {
                    HStack(spacing: 3) {
                        Image(systemName: "video.fill")
                            .font(.system(size: 8))
                        if let dur = asset.formattedDuration {
                            Text(dur)
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                        }
                    }
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(.black.opacity(0.65), in: Capsule())
                    .foregroundStyle(.white)
                    .padding(5)
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipped()
        .onAppear {
            loadImage()
        }
        .onDisappear {
            cancelImage()
        }
    }
    
    private func loadImage() {
        guard image == nil else { return }
        requestID = PhotoLibraryService.shared.requestThumbnail(for: asset, targetSize: targetSize) { loadedImage in
            if let loadedImage = loadedImage {
                self.image = loadedImage
            }
        }
    }
    
    private func cancelImage() {
        if let id = requestID {
            PhotoLibraryService.shared.cancelImageRequest(id)
            requestID = nil
        }
    }
}
