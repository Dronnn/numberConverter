//
//  LocalizationTests.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import Foundation
@testable import numberConverter
import Testing

@MainActor
struct LocalizationTests {
    @Test(arguments: ["en", "ru", "es", "de", "fr", "pt-BR"])
    func statisticsResolveInterpolatedCounts(locale: String) {
        var resource = QuizStatsText.message(asked: 12, right: 9)
        resource.locale = Locale(identifier: locale)

        let expected = switch locale {
        case "ru": "Всего вопросов: 12\nиз них правильно: 9"
        case "es": "Preguntas: 12\nRespuestas correctas: 9"
        case "de": "Gestellte Fragen: 12\nRichtige Antworten: 9"
        case "fr": "Questions posées : 12\nBonnes réponses : 9"
        case "pt-BR": "Perguntas: 12\nRespostas corretas: 9"
        default: "Questions asked: 12\nCorrect answers: 9"
        }
        #expect(String(localized: resource) == expected)
    }

    @Test(arguments: ["en", "ru", "es", "de", "fr", "pt-BR"])
    func everyHelpTopicHasTranslatedTitleAndProse(locale: String) {
        for topic in HelpContent.topics {
            var title = topic.title
            title.locale = Locale(identifier: locale)
            #expect(String(localized: title) != title.key)

            #expect(HelpContent.topic(page: topic.id).id == topic.id)
            #expect(!topic.indexRowTitle.key.isEmpty)
            for block in topic.blocks {
                #expect(!block.id.isEmpty)
                switch block {
                case var .paragraph(resource), var .localizedMono(resource):
                    resource.locale = Locale(identifier: locale)
                    #expect(String(localized: resource) != resource.key)
                case .mono:
                    break
                }
            }
        }
    }

    @Test(arguments: ["en", "ru", "es", "de", "fr", "pt-BR"])
    func compiledCatalogHasEveryTranslation(locale: String) throws {
        let source = try strings(locale: "en", table: "Localizable")
        let localized = try strings(locale: locale, table: "Localizable")
        #expect(Set(source.keys) == Set(localized.keys))
        for (key, value) in localized {
            #expect(!value.isEmpty, "Empty translation: \(locale)/\(key)")
            #expect(value != key, "Untranslated key: \(locale)/\(key)")
        }
        let info = try strings(locale: locale, table: "InfoPlist")
        #expect(info["CFBundleDisplayName"]?.isEmpty == false)
    }

    private func strings(locale: String, table: String) throws -> [String: String] {
        let path = try #require(Bundle.main.path(
            forResource: table, ofType: "strings", inDirectory: nil, forLocalization: locale
        ))
        let data = try Data(contentsOf: URL(filePath: path))
        return try #require(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String])
    }
}
