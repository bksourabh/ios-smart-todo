//
//  ThemeManager.swift
//  smart todo
//
//  Created by Sourabh Mazumder on 4/1/2026.
//

import SwiftUI
import Combine

final class ThemeManager: ObservableObject {
    @Published private(set) var themeValue: String
    
    init() {
        self.themeValue = UserDefaults.standard.string(forKey: "appTheme") ?? "adaptive"
    }
    
    var colorScheme: ColorScheme? {
        switch themeValue {
        case "light":
            return .light
        case "dark":
            return .dark
        case "adaptive":
            return nil // nil means use system preference
        default:
            return nil
        }
    }
    
    var isDarkMode: Bool {
        themeValue == "dark"
    }
    
    var isAdaptive: Bool {
        themeValue == "adaptive"
    }
    
    func setTheme(_ theme: String) {
        themeValue = theme
        UserDefaults.standard.set(themeValue, forKey: "appTheme")
    }
    
    func toggleTheme() {
        // Cycle through: adaptive -> light -> dark -> adaptive
        switch themeValue {
        case "adaptive":
            themeValue = "light"
        case "light":
            themeValue = "dark"
        case "dark":
            themeValue = "adaptive"
        default:
            themeValue = "adaptive"
        }
        UserDefaults.standard.set(themeValue, forKey: "appTheme")
    }
}

