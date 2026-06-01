//
//  ContentView.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import ConversionEngine
import SwiftUI

/// phase-0 placeholder root; the real 5-tab shell is built in phase 3.
struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "number")
                .font(.largeTitle)
            Text(verbatim: "NumberConverter")
            Text(
                verbatim: "bases \(ConversionEngine.supportedBaseRange.lowerBound)-\(ConversionEngine.supportedBaseRange.upperBound)"
            )
            .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    ContentView()
}
