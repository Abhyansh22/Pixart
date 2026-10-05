//
//  FullScreenAssetView.swift
//  Pixart
//

import SwiftUI
import Photos
import AVKit

struct FullScreenAssetView: View {
    let asset: PHAsset
    @Environment(\.dismiss) private var dismiss
    
    @State private var fullImage: UIImage?
    @State private var isLoading = true
    @State private var player: AVPlayer?
    @State private var showInfo = true
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if asset.mediaType == .video {
                    if let player = player {
                        VideoPlayer(player: player)
                            .ignoresSafeArea()
                            .onAppear {
                                player.play()
                            }
                            .onDisappear {
                                player.pause()
                            }
                    } else {
                        ProgressView()
                            .tint(.white)
                    }
                } else {
                    if let image = fullImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .ignoresSafeArea()
                    } else if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Unable to load full resolution")
                            .foregroundStyle(.secondary)
                    }
                }
                
                // Metadata overlay at bottom
                if showInfo {
                    VStack {
                        Spacer()
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Label(
                                    asset.mediaType == .video ? "Video" : "Photo",
                                    systemImage: asset.mediaType == .video ? "video.fill" : "photo.fill"
                                )
                                .font(.headline)
                                .foregroundStyle(.white)
                                
                                Spacer()
                                
                                if let size = asset.formattedFileSize {
                                    Text(size)
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.yellow)
                                }
                            }
                            
                            HStack(spacing: 12) {
                                if let date = asset.creationDate {
                                    Text(date.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.8))
                                }
                                
                                Text(asset.formattedDimensions)
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.8))
                                
                                if let dur = asset.formattedDuration {
                                    Text(dur)
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.8))
                                }
                            }
                        }
                        .padding(16)
                        .background(.ultraThinMaterial.opacity(0.8), in: RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal, 16)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.white)
                            .font(.title2)
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        withAnimation {
                            showInfo.toggle()
                        }
                    } label: {
                        Image(systemName: showInfo ? "info.circle.fill" : "info.circle")
                            .foregroundStyle(.white)
                    }
                }
            }
            .task {
                await loadAsset()
            }
        }
    }
    
    private func loadAsset() async {
        if asset.mediaType == .video {
            let options = PHVideoRequestOptions()
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .highQualityFormat
            
            PHImageManager.default().requestPlayerItem(forVideo: asset, options: options) { playerItem, _ in
                if let item = playerItem {
                    DispatchQueue.main.async {
                        self.player = AVPlayer(playerItem: item)
                    }
                }
            }
        } else {
            let image = await PhotoLibraryService.shared.requestFullImage(for: asset)
            self.fullImage = image
            self.isLoading = false
        }
    }
}
