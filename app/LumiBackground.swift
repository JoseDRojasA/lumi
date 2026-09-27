//
//  LumiBackground.swift
//  app
//
//  A soft, softly lit gradient backdrop that adapts to light/dark.
//

import SwiftUI

struct LumiBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        LinearGradient(
            colors: gradientColors,
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var gradientColors: [Color] {
        switch colorScheme {
        case .dark:
            // Deep lavender dusk into a warm, dim dawn.
            return [
                Color(red: 0.16, green: 0.15, blue: 0.28),
                Color(red: 0.28, green: 0.20, blue: 0.24)
            ]
        default:
            // Soft lavender dusk into a warm dawn.
            return [
                Color(red: 0.85, green: 0.83, blue: 0.95),
                Color(red: 0.99, green: 0.92, blue: 0.86)
            ]
        }
    }
}

#Preview {
    LumiBackground()
}
