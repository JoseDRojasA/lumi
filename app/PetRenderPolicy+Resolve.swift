//
//  PetRenderPolicy+Resolve.swift
//  app
//
//  Resolves a per-device render policy from the device idiom and view size.
//

import CoreGraphics
import LumiRendering

#if canImport(UIKit)
import UIKit
#endif

/// The device family the app is running on, independent of window size.
enum LumiDeviceIdiom {
    case phone, pad, mac

    /// The idiom for the current runtime (UIDevice / macOS / Mac Catalyst).
    static var current: LumiDeviceIdiom {
        #if os(macOS)
        return .mac
        #elseif targetEnvironment(macCatalyst)
        return .mac
        #else
        return UIDevice.current.userInterfaceIdiom == .pad ? .pad : .phone
        #endif
    }
}

extension PetRenderPolicy {
    /// Pure resolver: phone uses orientation (landscape when wider than tall),
    /// pad and mac map directly.
    static func resolve(idiom: LumiDeviceIdiom, size: CGSize) -> PetRenderPolicy {
        switch idiom {
        case .phone:
            return size.width > size.height ? .phoneLandscape : .phone
        case .pad:
            return .pad
        case .mac:
            return .mac
        }
    }
}
