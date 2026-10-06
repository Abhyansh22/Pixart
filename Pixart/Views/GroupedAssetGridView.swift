//
//  GroupedAssetGridView.swift
//  Pixart
//

import SwiftUI
import Photos

struct GroupedAssetGridView: View {
    @State private var viewModel: GroupedAssetViewModel
    @State private var selectedAsset: PHAsset?
    
    init(category: GalleryCategory) {
        _viewModel = State(wrappedValue: GroupedAssetViewModel(category: category))
    }
    
    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Progress Banner (if active)
                if viewModel.isLoading {
                    analysisBanner
                }
                
                if viewModel.groups.isEmpty && !viewModel.isLoading {
                    emptyState
                } else if viewModel.groups.isEmpty && viewModel.isLoading {
                    VStack(spacing: 16) {
                        Spacer()
                        ProgressView()
                            .scaleEffect(1.3)
                        Text(viewModel.progressStage ?? "Scanning library…")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            summaryHeader
                                .padding(.horizontal, 16)
                                .padding(.top, 8)
                            
                            ForEach(viewModel.groups) { group in
                                groupCard(group)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
        }
        .navigationTitle(viewModel.category.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if viewModel.groups.isEmpty {
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
    
    // MARK: - Subviews
    
    @ViewBuilder
    private var analysisBanner: some View {
        VStack(spacing: 6) {
            HStack {
                ProgressView()
                    .controlSize(.small)
                Text(viewModel.progressStage ?? "Analyzing…")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.primary)
                Spacer()
                if let fraction = viewModel.progressFraction {
                    Text("\(Int(fraction * 100))%")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }
            }
            
            if let fraction = viewModel.progressFraction {
                ProgressView(value: fraction)
                    .tint(viewModel.category.themeColor)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .overlay(Divider(), alignment: .bottom)
    }
    
    @ViewBuilder
    private var summaryHeader: some View {
        HStack {
            Text("\(viewModel.groups.count) groups discovered")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            
            Spacer()
            
            let totalWastedBytes = viewModel.groups.compactMap { group -> Int64? in
                guard let size = group.totalByteSize, group.assets.count > 1 else { return nil }
                // Potential reclaimable size: all but 1 original
                let perItemSize = size / Int64(group.assets.count)
                return perItemSize * Int64(group.assets.count - 1)
            }.reduce(0, +)
            
            if totalWastedBytes > 0 {
                Text("Reclaimable: \(ByteCountFormatter.string(fromByteCount: totalWastedBytes, countStyle: .file))")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.12), in: Capsule())
            }
        }
    }
    
    @ViewBuilder
    private func groupCard(_ group: AssetGroup) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(group.title)
                        .font(.subheadline.weight(.bold))
                    Text("\(group.assets.count) items")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                if let size = group.formattedSize {
                    Text(size)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(uiColor: .tertiarySystemFill), in: Capsule())
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            
            // Thumbnails row
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 8) {
                    ForEach(group.assets, id: \.localIdentifier) { asset in
                        ThumbnailView(
                            asset: asset,
                            targetSize: CGSize(width: 200, height: 200)
                        )
                        .frame(width: 100, height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.black.opacity(0.06), lineWidth: 1)
                        )
                        .onTapGesture {
                            selectedAsset = asset
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
            }
        }
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 2)
        .padding(.horizontal, 16)
    }
    
    @ViewBuilder
    private var emptyState: some View {
        ContentUnavailableView(
            "No \(viewModel.category.title) Found",
            systemImage: "checkmark.circle.fill",
            description: Text(
                viewModel.category == .similarPhotos
                ? "No visually resembling photos detected in your recent library."
                : "Great news! Your library is clean with no exact duplicates found."
            )
        )
    }
}
