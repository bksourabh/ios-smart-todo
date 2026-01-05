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
        self.themeValue = UserDefaults.standard.string(forKey: "appTheme") ?? "light"
    }
    
    var colorScheme: ColorScheme? {
        switch themeValue {
        case "light":
            return .light
        case "dark":
            return .dark
        default:
            return .light
        }
    }
    
    var isDarkMode: Bool {
        themeValue == "dark"
    }
    
    func setTheme(_ theme: String) {
        themeValue = theme
        UserDefaults.standard.set(themeValue, forKey: "appTheme")
    }
    
    func toggleTheme() {
        themeValue = themeValue == "light" ? "dark" : "light"
        UserDefaults.standard.set(themeValue, forKey: "appTheme")
    }
}

