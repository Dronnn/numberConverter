//
//  VoiceOverAlertTests.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import XCTest

@MainActor
extension NumberConverterUITests {
    func testVoiceOverReadsLocalizedModalAlertsInEveryLanguage() throws {
        guard #available(iOS 27.0, *) else {
            throw XCTSkip("Native VoiceOver speech automation requires iOS 27 or later; this OS is unsupported.")
        }
        executionTimeAllowance = 900
        let service = XCUIDevice.shared.voiceOverService
        let originalVoiceOverState = service.isEnabled
        let originalAuditMode = capturesIncludeNativeAudit
        addTeardownBlock {
            await MainActor.run {
                NumberConverterUITests.restoreNativeVoiceOver(
                    XCUIDevice.shared.voiceOverService, enabled: originalVoiceOverState
                )
            }
        }
        capturesIncludeNativeAudit = false
        defer {
            app.terminate()
            capturesIncludeNativeAudit = originalAuditMode
            Self.restoreNativeVoiceOver(service, enabled: originalVoiceOverState)
        }
        if service.isEnabled {
            try service.disable()
        }
        for language in UITestLanguage.allCases {
            try exerciseNativeVoiceOverAlerts(language, service: service)
        }
    }

    @available(iOS 27.0, *)
    private func exerciseNativeVoiceOverAlerts(_ language: UITestLanguage, service: XCUIVoiceOverService) throws {
        let copy = VoiceOverAlertCopy(language: language)
        try verifyInitialAnnouncementContext(appDisplayName: copy.appDisplayName, title: copy.feedback.title)
        launch(language)
        try selectTab(3)
        try tap("quiz.category.binaryInt")
        try replace("quiz.answer", with: "?")
        dismissKeyboard()
        let underlyingLabels = underlyingVoiceOverLabels()
        try tap("quiz.check")
        try inspectNativeVoiceOverAlert(
            language,
            service: service,
            appDisplayName: copy.appDisplayName,
            expected: copy.feedback,
            underlyingLabels: underlyingLabels
        )
        try dismissVoiceOverAlert(ok: copy.feedback.ok)
        try openSessionStatistics()
        try inspectNativeVoiceOverAlert(
            language,
            service: service,
            appDisplayName: copy.appDisplayName,
            expected: copy.statistics,
            underlyingLabels: underlyingLabels
        )
        try dismissVoiceOverAlert(ok: copy.statistics.ok)
        app.terminate()
    }

    @available(iOS 27.0, *)
    private static func restoreNativeVoiceOver(_ service: XCUIVoiceOverService, enabled: Bool) {
        do {
            if service.isEnabled != enabled {
                if enabled {
                    try service.enable()
                } else {
                    try service.disable()
                }
            }
            XCTAssertEqual(service.isEnabled, enabled, "Original VoiceOver state must be restored")
        } catch {
            XCTFail("Could not restore original VoiceOver state: \(error)")
        }
    }

    private func underlyingVoiceOverLabels() -> [String] {
        let identifiers = ["quiz.header", "quiz.prompt", "quiz.next", "quiz.check", "quiz.finish"]
            + Self.tabIdentifiers.map { "app.tab.\($0)" }
        return identifiers.compactMap { identifier in
            let control = element(identifier)
            guard control.exists, !control.label.isEmpty else { return nil }
            return control.label
        }
    }

    @available(iOS 27.0, *)
    private func inspectNativeVoiceOverAlert(
        _ language: UITestLanguage,
        service: XCUIVoiceOverService,
        appDisplayName: String,
        expected: VoiceOverAlertExpectation,
        underlyingLabels: [String]
    ) throws {
        let message = try expectedNativeAlertMessage(expected)
        let labels = [expected.title, message, expected.ok]
        let forbidden = underlyingLabels.filter { label in
            !labels.contains { containsSpokenPhrase(label, in: $0) }
        }
        guard forbidden.count >= 3 else {
            throw VoiceOverAlertFailure
                .assertion("Insufficient distinct underlying-screen labels for modal-focus checks")
        }
        var speech: [String] = []
        defer {
            attachNativeAlertSpeech(
                language,
                service: service,
                name: expected.name,
                appDisplayName: appDisplayName,
                labels: labels,
                forbidden: forbidden,
                speech: speech
            )
        }
        try service.enable()
        guard service.isEnabled else {
            throw VoiceOverAlertFailure.assertion("Public service did not enable VoiceOver")
        }
        try collectNativeAlertSpeech(
            service, appDisplayName: appDisplayName, labels: labels, forbidden: forbidden, speech: &speech
        )
        try service.disable()
        guard !service.isEnabled else {
            throw VoiceOverAlertFailure.assertion("Public service did not disable VoiceOver before UI navigation")
        }
    }

    private func expectedNativeAlertMessage(_ expected: VoiceOverAlertExpectation) throws -> String {
        let alert = app.alerts.firstMatch
        guard alert.waitForExistence(timeout: 5) else {
            throw VoiceOverAlertFailure.assertion("Missing native \(expected.name) alert")
        }
        guard alert.staticTexts[expected.title].exists, alert.buttons[expected.ok].exists else {
            throw VoiceOverAlertFailure
                .assertion("Alert title/OK do not match localized copy: \(alert.debugDescription)")
        }
        guard let message = alert.staticTexts.allElementsBoundByIndex.first(where: {
            $0.label.hasPrefix(expected.messagePrefix) && $0.label.contains(expected.requiredMessageText)
        })?.label else {
            throw VoiceOverAlertFailure.assertion("Missing complete localized alert message: \(alert.debugDescription)")
        }
        return message
    }

    @available(iOS 27.0, *)
    private func collectNativeAlertSpeech(
        _ service: XCUIVoiceOverService,
        appDisplayName: String,
        labels: [String],
        forbidden: [String],
        speech: inout [String]
    ) throws {
        var modalSpeech: [String] = []
        for step in 0 ..< 12 {
            let output = try step == 0 ? service.currentSpeech() : service.moveForward()
            let utterance = output.utterance
            speech.append(utterance)
            let modalUtterance = initialAlertSpeech(
                utterance, step: step, appDisplayName: appDisplayName, title: labels[0]
            )
            modalSpeech.append(modalUtterance)
            guard
                !modalUtterance.isEmpty,
                labels.contains(where: { containsSpokenPhrase($0, in: modalUtterance) })
            else {
                throw VoiceOverAlertFailure
                    .assertion("VoiceOver focused content outside the native alert: \(utterance)")
            }
            guard !forbidden.contains(where: { containsSpokenPhrase($0, in: modalUtterance) }) else {
                throw VoiceOverAlertFailure.assertion("VoiceOver reached underlying-screen content: \(utterance)")
            }
        }
        let distinctSpeech = Set(modalSpeech.map(normalizedNativeSpeech))
        guard distinctSpeech.count >= 2 else {
            throw VoiceOverAlertFailure.assertion("Native VoiceOver focus did not produce distinct speech: \(speech)")
        }
        guard modalSpeech.contains(where: { utterance in
            containsSpokenPhrase(labels[2], in: utterance)
                && !labels.prefix(2).contains { containsSpokenPhrase($0, in: utterance) }
        }) else {
            throw VoiceOverAlertFailure.assertion("VoiceOver never focused the separate modal OK button: \(speech)")
        }
        let completeSpeech = modalSpeech.joined(separator: " ")
        guard labels.allSatisfy({ containsSpokenPhrase($0, in: completeSpeech) }) else {
            throw VoiceOverAlertFailure.assertion("VoiceOver did not speak every localized title/message/OK: \(speech)")
        }
    }

    @available(iOS 27.0, *)
    private func attachNativeAlertSpeech(
        _ language: UITestLanguage,
        service: XCUIVoiceOverService,
        name: String,
        appDisplayName: String,
        labels: [String],
        forbidden: [String],
        speech: [String]
    ) {
        let attachment = XCTAttachment(string: """
        Locale: \(language.rawValue); native alert: \(name); content size: L.
        Expected localized app display name: \(appDisplayName).
        Expected localized title/message/OK: \(labels).
        Forbidden underlying-screen labels: \(forbidden).
        Observed native speech: \(speech).
        Only step zero's exact complete app-name + alert-title announcement is interpreted as title context.
        API provides utterances, not focused-element identifiers. Every observed step must name modal content;
        unrelated or underlying-screen speech fails. This is bounded semantic focus traversal,
        not exhaustive node identity.
        Service: \(service.debugDescription)
        """)
        attachment.name = "voiceover-\(language.rawValue)-\(name)-native-speech"
        attachment.lifetime = .keepAlways
        add(attachment)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "voiceover-\(language.rawValue)-\(name)-screen"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    private func dismissVoiceOverAlert(ok: String) throws {
        let alert = app.alerts.firstMatch
        alert.buttons[ok].tap()
        let dismissed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: alert)
        guard XCTWaiter.wait(for: [dismissed], timeout: 5) == .completed else {
            throw VoiceOverAlertFailure.assertion("Native alert did not dismiss after OK")
        }
    }

    private func containsSpokenPhrase(_ phrase: String, in utterance: String) -> Bool {
        let expected = normalizedNativeSpeech(phrase)
        return !expected.isEmpty && (" " + normalizedNativeSpeech(utterance) + " ").contains(" " + expected + " ")
    }

    private func normalizedNativeSpeech(_ value: String) -> String {
        value.lowercased().split { !$0.isLetter && !$0.isNumber }.joined(separator: " ")
    }

    private func initialAlertSpeech(_ utterance: String, step: Int, appDisplayName: String, title: String) -> String {
        guard
            step == 0,
            normalizedNativeSpeech(utterance) == normalizedNativeSpeech(appDisplayName + " " + title)
        else { return utterance }
        return title
    }

    private func verifyInitialAnnouncementContext(appDisplayName: String, title: String) throws {
        let announcement = appDisplayName + " " + title
        guard initialAlertSpeech(announcement, step: 0, appDisplayName: appDisplayName, title: title) == title else {
            throw VoiceOverAlertFailure.assertion("Exact initial app-name/title context must preserve the modal title")
        }
        let unmodified = [
            (announcement, 1),
            (appDisplayName + " tab", 0),
            (announcement + " tab", 0),
            (appDisplayName + " other " + title, 0)
        ]
        for (utterance, step) in unmodified {
            guard initialAlertSpeech(utterance, step: step, appDisplayName: appDisplayName, title: title) == utterance
            else {
                throw VoiceOverAlertFailure.assertion("App-name context must not conceal later or unrelated speech")
            }
        }
    }
}

private enum VoiceOverAlertFailure: Error {
    case assertion(String)
}

private struct VoiceOverAlertExpectation {
    let name: String
    let title: String
    let messagePrefix: String
    let requiredMessageText: String
    let ok: String
}

private struct VoiceOverAlertCopy {
    let appDisplayName: String
    let feedback: VoiceOverAlertExpectation
    let statistics: VoiceOverAlertExpectation

    init(language: UITestLanguage) {
        appDisplayName = language.voiceOverAppDisplayName
        let values = language.voiceOverAlertTextValues
        feedback = VoiceOverAlertExpectation(
            name: "wrong-answer",
            title: values[0],
            messagePrefix: values[1],
            requiredMessageText: values[2],
            ok: values[6]
        )
        statistics = VoiceOverAlertExpectation(
            name: "statistics",
            title: values[3],
            messagePrefix: values[4],
            requiredMessageText: values[5],
            ok: values[6]
        )
    }
}

private extension UITestLanguage {
    var voiceOverAppDisplayName: String {
        switch self {
        case .english: "Base Lab"
        case .russian: "Числа"
        case .spanish, .french, .portuguese: "Bases"
        case .german: "Basen"
        }
    }

    var voiceOverAlertTextValues: [String] {
        switch self {
        case .english:
            [
                "Answer",
                "Your answer is incorrect",
                "Correct answer:",
                "Statistics",
                "Questions asked:",
                "Correct answers:",
                "OK"
            ]
        case .russian:
            [
                "Ответ",
                "Ваш ответ неверный",
                "Правильный ответ:",
                "Статистика",
                "Всего вопросов:",
                "из них правильно:",
                "ОК"
            ]
        case .spanish:
            [
                "Respuesta",
                "Tu respuesta es incorrecta",
                "Respuesta correcta:",
                "Estadísticas",
                "Preguntas:",
                "Respuestas correctas:",
                "Aceptar"
            ]
        case .german:
            [
                "Antwort",
                "Deine Antwort ist falsch",
                "Richtige Antwort:",
                "Statistik",
                "Gestellte Fragen:",
                "Richtige Antworten:",
                "OK"
            ]
        case .french:
            [
                "Réponse",
                "Votre réponse est incorrecte",
                "Bonne réponse :",
                "Statistiques",
                "Questions posées :",
                "Bonnes réponses :",
                "OK"
            ]
        case .portuguese:
            [
                "Resposta",
                "Sua resposta está incorreta",
                "Resposta correta:",
                "Estatísticas",
                "Perguntas:",
                "Respostas corretas:",
                "OK"
            ]
        }
    }
}
