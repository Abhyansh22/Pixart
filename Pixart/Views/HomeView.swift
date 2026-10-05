//
//  HomeView.swift
//  Pixart
//

import SwiftUI
import Photos

struct HomeView: View {
    @ObservedObject var photoService = PhotoLibraryService.shared
    @StateObject private var viewModel = HomeViewModel()
    @State private var navigationPath = NavigationPath()
    
    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header Subtitle
                    Text("Organize, inspect duplicates, and optimize your device photo storage with ease.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                    
                    // Limited permission banner if needed
                    if photoService.authorizationStatus == .limited {
                        limitedAccessBanner
                            .padding(.horizontal, 16)
                    }
                    
                    // 6 Categories Grid
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(GalleryCategory.allCases) { category in
                            NavigationLink(value: category) {
                                categoryCard(category)
                                    .contentShape(RoundedRectangle(cornerRadius: 18))
                            }
                            .buttonStyle(CardButtonStyle())
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.vertical, 16)
            }
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Pixart")
            .navigationDestination(for: GalleryCategory.self) { category in
                if category.isGrouped {
                    GroupedAssetGridView(category: category)
                } else {
                    AssetGridView(category: category)
                }
            }
            .refreshable {
                viewModel.refreshCounts()
            }
        }
        .onAppear {
            viewModel.refreshCounts()
            handleCommandLineArguments()
        }
        .onOpenURL { url in
            handleDeepLink(url)
        }
    }
    
    private func handleCommandLineArguments() {
        let args = ProcessInfo.processInfo.arguments
        if let idx = args.firstIndex(of: "-category"), idx + 1 < args.count {
            let catArg = args[idx + 1].lowercased()
            if let matched = GalleryCategory.allCases.first(where: { $0.rawValue.lowercased() == catArg }) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    navigationPath = NavigationPath([matched])
                }
            }
        }
    }
    
    private func handleDeepLink(_ url: URL) {
        let catArg = url.lastPathComponent.lowercased()
        if let matched = GalleryCategory.allCases.first(where: { $0.rawValue.lowercased() == catArg }) {
            navigationPath = NavigationPath([matched])
        }
    }
    
    // MARK: - Category Card View
    
    @ViewBuilder
    private func categoryCard(_ category: GalleryCategory) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(category.themeColor.opacity(0.15))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: category.iconName)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(category.themeColor)
                }
                
                Spacer()
                
                if let count = viewModel.counts[category] {
                    Text("\(count)")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(uiColor: .tertiarySystemFill), in: Capsule())
                } else if viewModel.isLoadingCounts && (category == .screenshots || category == .videos) {
                    ProgressView()
                        .controlSize(.mini)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(category.title)
                    .font(.headline)
                    .foregroundStyle(Color(uiColor: .label))
                    .lineLimit(1)
                
                Text(category.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer(minLength: 0)
            
            HStack {
                Text("Open")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(category.themeColor)
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(category.themeColor.opacity(0.8))
            }
        }
        .padding(16)
        .frame(minHeight: 160)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
    
    @ViewBuilder
    private var limitedAccessBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(.blue)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Limited Photo Access")
                    .font(.subheadline.bold())
                Text("Pixart only has access to selected photos. Grant full access in Settings to scan your whole library.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button("Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .font(.caption.bold())
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(12)
        .background(Color.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
    }
}

/// Custom button style for responsive card press animations
struct CardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}
