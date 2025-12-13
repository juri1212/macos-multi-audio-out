//
//  SharedUI.swift
//  Duophonic
//
//  Created by Juri Beforth on 13.12.25.
//

import Combine
import SwiftUI

extension View {
    public func controlCenterContainer() -> some View {
        self
            .padding(12)
            .background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.06))
            )
            .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 6)
    }
}

// Replace @Observable macro with classic ObservableObject for compatibility
class AppState: ObservableObject {
    @Published var launchAtLogin = false
}
