//
//  PixartApp.swift
//  Pixart
//

import SwiftUI
import Photos

@main
struct PixartApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(PhotoLibraryService.shared)
                .environment(AppSettings.shared)
        }
    }
}

// MARK: - Root View
struct RootView: View {
    @Environment(PhotoLibraryService.self) private var photoService
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some View {
        Group {
            switch photoService.authorizationStatus {
            case .authorized, .limited:
                HomeView()
                
            case .notDetermined:
                PermissionRequestView()
                
            case .denied, .restricted:
                PermissionDeniedView()
                
            @unknown default:
                PermissionDeniedView()
            }
        }
        .animation(.easeInOut(duration: 0.25), value: photoService.authorizationStatus)
        .task {
            photoService.checkAuthorization()
            #if DEBUG
            if photoService.authorizationStatus == .authorized || photoService.authorizationStatus == .limited {
                Task.detached {
                    _ = await AppDiagnostics.runDiagnostics()
                }
            }
            #endif
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                photoService.checkAuthorization()
            }
        }
    }
}

// MARK: - Permission Prompt View
struct PermissionRequestView: View {
    @Environment(PhotoLibraryService.self) private var photoService
    @State private var isRequesting = false
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.12))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "photo.stack.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.blue)
            }
            
            VStack(spacing: 8) {
                Text("Welcome to Pixart")
                    .font(.title.bold())
                
                Text("Pixart needs photo library access to find your screenshots, duplicate media, and large videos.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            Spacer()
            
            Button {
                guard !isRequesting else { return }
                isRequesting = true
                Task {
                    _ = await photoService.requestAuthorization()
                    isRequesting = false
                }
            } label: {
                HStack(spacing: 8) {
                    if isRequesting {
                        ProgressView()
                            .tint(.white)
                    }
                    Text("Allow Photo Access")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isRequesting)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .background(Color(uiColor: .systemBackground).ignoresSafeArea())
    }
}

// MARK: - Permission Denied View
struct PermissionDeniedView: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.12))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.red)
            }
            
            VStack(spacing: 8) {
                Text("Photo Access Required")
                    .font(.title2.bold())
                
                Text("Pixart cannot inspect screenshots, videos, or duplicates without Photo library permissions. Please enable access in Settings.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            Spacer()
            
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("Open Settings")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .background(Color(uiColor: .systemBackground).ignoresSafeArea())
    }
}
