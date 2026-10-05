//
//  AssetGridView.swift
//  Pixart
//

import SwiftUI
import Photos

struct AssetGridView: View {
    @StateObject private var viewModel: AssetListViewModel
    @State private var selectedAsset: PHAsset?
    
    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]
    
    init(category: GalleryCategory) {
        _viewModel = StateObject(wrappedValue: AssetListViewModel(category: category))
    }
    
    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()
            
            if viewModel.isLoading && viewModel.assets.isEmpty {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    if let msg = viewModel.progressMessage {
                        Text(msg)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
            } else if viewModel.assets.isEmpty {
                ContentUnavailableView(
                    "No \(viewModel.category.title) Found",
                    systemImage: viewModel.category.iconName,
                    description: Text("Your photo library doesn't contain any items in this category.")
                )
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        // Summary header bar
                        summaryBar
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                        
                        LazyVGrid(columns: columns, spacing: 2) {
                            ForEach(Array(viewModel.assets.enumerated()), id: \.element.localIdentifier) { index, asset in
                                let badgeText = badge(for: asset)
                                
                                ThumbnailView(
                                    asset: asset,
                                    badgeText: badgeText
                                )
                                .onTapGesture {
                                    selectedAsset = asset
                                }
                                .onAppear {
                                    viewModel.prefetch(around: index)
                                }
                            }
                        }
                    }
                }
                .refreshable {
                    viewModel.load()
                }
            }
        }
        .navigationTitle(viewModel.category.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if viewModel.assets.isEmpty {
                viewModel.load()
            }
        }
        .onDisappear {
            viewModel.cancel()
        }
        .sheet(item: $selectedAsset) { asset in
            FullScreenAssetView(asset: asset)
        }
    }
    
    private func badge(for asset: PHAsset) -> String? {
        if viewModel.category == .largeVideos {
            if let bytes = viewModel.fileSizes[asset.localIdentifier] {
                return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
            }
        }
        return nil
    }
    
    @ViewBuilder
    private var summaryBar: some View {
        HStack {
            Text("\(viewModel.assets.count) items")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            
            Spacer()
            
            if viewModel.category == .largeVideos {
                let totalBytes = viewModel.fileSizes.values.reduce(0, +)
                if totalBytes > 0 {
                    Text("Total: \(ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file))")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(uiColor: .tertiarySystemFill), in: Capsule())
                }
            }
        }
    }
}
