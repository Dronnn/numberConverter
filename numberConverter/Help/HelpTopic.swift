//
//  HelpTopic.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import SwiftUI

// MARK: - HelpBlock

/// a single renderable chunk of a help page, in reading order.
enum HelpBlock: Identifiable {
    /// localized prose paragraph.
    case paragraph(LocalizedStringResource)
    /// language-neutral monospaced block (ascii table or aligned computation),
    /// rendered verbatim inside a horizontally scrollable container.
    case mono(String)

    var id: String {
        switch self {
        case let .paragraph(resource): "p-\(resource.key)"
        case let .mono(text): "m-\(text.hashValue)"
        }
    }
}

// MARK: - HelpTopic

/// one help page: a localized title plus an ordered list of blocks.
struct HelpTopic: Identifiable {
    let id: Int
    /// label shown in the help index list. intentionally differs from `title`
    /// (the legacy menu wording is shorter than the page heading).
    let indexRowTitle: LocalizedStringResource
    let title: LocalizedStringResource
    let blocks: [HelpBlock]
}
