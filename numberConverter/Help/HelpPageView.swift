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
                Text(topic.title)
                    .font(.title2.bold())
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("help.title")

                ForEach(topic.blocks) { block in
                    HelpBlockView(block: block)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .scrollIndicators(.hidden)
        .accessibilityIdentifier("help.content")
        .navigationTitle(Text("nav.info"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { AppLogger.help.info("help page opened: \(topic.id, privacy: .public)") }
    }
}

// MARK: - HelpBlockView

/// renders a single help block: prose as body text, or a monospaced block
/// inside a horizontally scrollable container so columns stay aligned.
private struct HelpBlockView: View {
    @Environment(\.locale) private var locale
    let block: HelpBlock

    var body: some View {
        switch block {
        case let .paragraph(resource):
            localizedText(resource)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
                .accessibilityIdentifier("help.block.\(resource.key)")
        case let .mono(text):
            MonospacedBlock(text: Text(verbatim: text))
        case let .localizedMono(resource):
            MonospacedBlock(text: localizedText(resource))
                .accessibilityIdentifier("help.block.\(resource.key)")
        }
    }

    /// Mathematical asterisks are multiplication signs, not Markdown emphasis.
    private func localizedText(_ resource: LocalizedStringResource) -> Text {
        var localized = resource
        localized.locale = locale
        return Text(verbatim: String(localized: localized))
    }
}

// MARK: - MonospacedBlock

/// a monospaced, horizontally scrollable block for ascii tables
/// and aligned computations.
private struct MonospacedBlock: View {
    let text: Text

    var body: some View {
        ScrollView(.horizontal) {
            text
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
