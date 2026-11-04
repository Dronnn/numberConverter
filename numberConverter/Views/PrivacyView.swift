//
//  PrivacyView.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import SwiftUI

/// The app's privacy policy is readable offline in every supported language.
struct PrivacyView: View {
    private let sections: [(title: LocalizedStringResource, body: LocalizedStringResource)] = [
        ("privacy.section.1.title", "privacy.section.1.body"),
        ("privacy.section.2.title", "privacy.section.2.body"),
        ("privacy.section.3.title", "privacy.section.3.body"),
        ("privacy.section.4.title", "privacy.section.4.body"),
        ("privacy.section.5.title", "privacy.section.5.body"),
        ("privacy.section.6.title", "privacy.section.6.body")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("privacy.title")
                    .font(.title2.bold())
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("privacy.title")

                Text("privacy.updated")
                    .font(.subheadline)

                ForEach(sections.indices, id: \.self) { index in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(sections[index].title)
                            .font(.headline)
                            .accessibilityAddTraits(.isHeader)
                        Text(sections[index].body)
                            .textSelection(.enabled)
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("privacy.section.\(index + 1)")
                }

                policyLinks
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: 680, alignment: .leading)
            .padding()
            .frame(maxWidth: .infinity)
        }
        .accessibilityIdentifier("privacy.content")
        .navigationTitle(Text("privacy.nav"))
        .navigationBarTitleDisplayMode(.inline)
        .helpCloseToolbar()
    }

    private var policyLinks: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let url = URL(string: "https://github.com/Dronnn/numberConverter/blob/main/PRIVACY.md") {
                Link(destination: url) {
                    Label("privacy.website", systemImage: "arrow.up.right.square")
                        .frame(minHeight: 44, alignment: .leading)
                }
                .accessibilityIdentifier("privacy.website")
            }
            if let url = URL(string: "https://www.apple.com/legal/privacy/") {
                Link(destination: url) {
                    Label("privacy.applePolicy", systemImage: "arrow.up.right.square")
                        .frame(minHeight: 44, alignment: .leading)
                }
                .accessibilityIdentifier("privacy.applePolicy")
            }
        }
    }
}

#Preview {
    NavigationStack {
        PrivacyView()
    }
}
