//
//  HelpPageView.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import OSLog
import SwiftUI

// MARK: - HelpPageView

/// renders one help topic: a scrolling column of prose paragraphs and
/// monospaced tables, in the order defined by the topic.
struct HelpPageView: View {
    let topic: HelpTopic

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(topic.blocks) { block in
                    HelpBlockView(block: block)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .scrollIndicators(.hidden)
        .navigationTitle(Text(topic.title))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { AppLogger.help.info("help page opened: \(topic.id, privacy: .public)") }
    }
}

// MARK: - HelpBlockView

/// renders a single help block: prose as body text, or a monospaced block
/// inside a horizontally scrollable container so columns stay aligned.
private struct HelpBlockView: View {
    let block: HelpBlock

    var body: some View {
        switch block {
        case let .paragraph(resource):
            Text(resource)
                .textSelection(.enabled)
        case let .mono(text):
            MonospacedBlock(text: text)
        }
    }
}

// MARK: - MonospacedBlock

/// a verbatim, monospaced, horizontally scrollable block for ascii tables
/// and aligned computations.
private struct MonospacedBlock: View {
    let text: String

    var body: some View {
        ScrollView(.horizontal) {
            Text(verbatim: text)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .padding(.vertical, 4)
        }
        .scrollIndicators(.hidden)
    }
}

#Preview {
    NavigationStack {
        HelpPageView(topic: HelpContent.topic(page: 2))
    }
    .environment(\.locale, Locale(identifier: "ru"))
}
