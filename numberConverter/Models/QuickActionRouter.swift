//
//  QuickActionRouter.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import SwiftUI

// MARK: - QuickActionRouter

/// shared bridge between the `AppDelegate` (which receives home-screen quick
/// actions) and the swiftui view tree (which performs the navigation).
/// the delegate stores a `pendingTab`; `RootView` consumes and clears it.
@Observable
@MainActor
final class QuickActionRouter {
    static let shared = QuickActionRouter()

    /// a tab requested by a home-screen quick action, awaiting routing.
    var pendingTab: AppTab?

    private init() {}
}
