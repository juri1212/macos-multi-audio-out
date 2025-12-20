//
//  SharedUI.swift
//  Duophonic
//
//  Created by Juri Beforth on 13.12.25.
//

import Combine

// Replace @Observable macro with classic ObservableObject for compatibility
class AppState: ObservableObject {
    @Published var launchAtLogin = false
}
