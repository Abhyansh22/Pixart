//
//  AppSettings.swift
//  Pixart
//

import SwiftUI
import Observation

@Observable
@MainActor
final class AppSettings {
    static let shared = AppSettings()
    
    /// Preset threshold options in megabytes
    static let presetsMB: [Int] = [50, 100, 200, 500, 1000]
    static let defaultThresholdMB: Int = 200
    private static let thresholdKey = "pixart.settings.largeVideoThresholdMB"
    
    var largeVideoThresholdMB: Int {
        didSet {
            print("[AppSettings] largeVideoThresholdMB changed from \(oldValue) to \(largeVideoThresholdMB)")
            UserDefaults.standard.set(largeVideoThresholdMB, forKey: Self.thresholdKey)
        }
    }
    
    init() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-resetSettings") {
            UserDefaults.standard.removeObject(forKey: Self.thresholdKey)
        }
        #endif
        let stored = UserDefaults.standard.integer(forKey: Self.thresholdKey)
        if stored > 0 {
            self.largeVideoThresholdMB = stored
        } else {
            self.largeVideoThresholdMB = Self.defaultThresholdMB
        }
    }
    
    var largeVideoThresholdBytes: Int64 {
        Int64(largeVideoThresholdMB) * 1024 * 1024
    }
    
    static func formatMB(_ mb: Int) -> String {
        if mb >= 1000 {
            let gb = Double(mb) / 1000.0
            return gb.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(gb)) GB" : String(format: "%.1f GB", gb)
        }
        return "\(mb) MB"
    }
    
    func resetToDefault() {
        largeVideoThresholdMB = Self.defaultThresholdMB
    }
}
