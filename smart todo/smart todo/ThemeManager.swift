//
//  ThemeManager.swift
//  smart todo
//
//  Created by Sourabh Mazumder on 4/1/2026.
//

import SwiftUI
import Combine

final class ThemeManager: ObservableObject {
    var colorScheme: ColorScheme? {
        // Always return nil to use system preference
        return nil
    }
}

