//
//  DetailAccessibilityTests.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import XCTest

@MainActor
extension NumberConverterUITests {
    func testDetailButtonsAnnounceTheirLocalizedDestinations() throws {
        for language in UITestLanguage.allCases {
            launch(language)
            let identifiers = [
                "converter.detail.2", "converter.detail.8", "converter.detail.10", "converter.detail.16",
                "converter.all.detail"
            ]
            var labels: [String] = []
            for (identifier, destination) in zip(identifiers, language.expectedDetailDestinations) {
                let control = try require(identifier)
                try reveal(control, identifier: identifier)
                XCTAssertTrue(control.label.contains(destination), "\(identifier): \(control.label)")
                labels.append(control.label)
            }
            XCTAssertEqual(labels.count, 5)
            XCTAssertEqual(Set(labels).count, 5, "Every info button must announce a distinct destination")
            let proof = XCTAttachment(string: labels.joined(separator: "\n"))
            proof.name = "\(language.rawValue)-detail-button-VoiceOver-labels"
            proof.lifetime = .keepAlways
            add(proof)
            app.terminate()
        }
    }
}

private extension UITestLanguage {
    var expectedDetailDestinations: [String] {
        switch self {
        case .english: ["Binary", "Octal", "Decimal", "Hexadecimal", "All bases from 2 to 36"]
        case .russian: ["Двоичная", "Восьмеричная", "Десятичная", "Шестнадцатеричная", "Все системы с 2 по 36"]
        case .spanish: ["Binario", "Octal", "Decimal", "Hexadecimal", "Todas las bases del 2 al 36"]
        case .german: ["Binär", "Oktal", "Dezimal", "Hexadezimal", "Alle Basen von 2 bis 36"]
        case .french: ["Binaire", "Octal", "Décimal", "Hexadécimal", "Toutes les bases de 2 à 36"]
        case .portuguese: ["Binário", "Octal", "Decimal", "Hexadecimal", "Todas as bases de 2 a 36"]
        }
    }
}
