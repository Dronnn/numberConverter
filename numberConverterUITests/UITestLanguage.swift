//
//  UITestLanguage.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

enum UITestLanguage: String, CaseIterable {
    case english = "en"
    case russian = "ru"
    case spanish = "es"
    case german = "de"
    case french = "fr"
    case portuguese = "pt-BR"

    var region: String {
        switch self {
        case .english: "en_US"
        case .russian: "ru_RU"
        case .spanish: "es_ES"
        case .german: "de_DE"
        case .french: "fr_FR"
        case .portuguese: "pt_BR"
        }
    }

    var converterTitle: String {
        switch self {
        case .english: "Converter"
        case .russian: "Конвертер"
        case .spanish, .portuguese: "Conversor"
        case .german: "Umrechner"
        case .french: "Convertisseur"
        }
    }

    var tabLabels: [String] {
        switch self {
        case .english: ["Convert", "Bases", "Calculator", "Quiz", "Support"]
        case .russian: ["Перевод", "Системы", "Расчёт", "Тесты", "Поддержка"]
        case .spanish: ["Convertir", "Bases", "Cálculo", "Test", "Apoyar"]
        case .german: ["Umrechnen", "Basen", "Rechner", "Quiz", "Support"]
        case .french: ["Convertir", "Bases", "Calcul", "Quiz", "Soutenir"]
        case .portuguese: ["Converter", "Bases", "Cálculo", "Teste", "Apoiar"]
        }
    }

    var correctAnswer: String {
        switch self {
        case .english: "Your answer is correct"
        case .russian: "Ваш ответ верный"
        case .spanish: "Tu respuesta es correcta"
        case .german: "Deine Antwort ist richtig"
        case .french: "Votre réponse est correcte"
        case .portuguese: "Sua resposta está correta"
        }
    }

    var divisionByZero: String {
        switch self {
        case .english: "Division by zero"
        case .russian: "Деление на ноль"
        case .spanish: "División entre cero"
        case .german: "Division durch null"
        case .french: "Division par zéro"
        case .portuguese: "Divisão por zero"
        }
    }

    var resetStatistics: String {
        switch self {
        case .english: "Reset statistics"
        case .russian: "Сбросить статистику"
        case .spanish: "Restablecer estadísticas"
        case .german: "Statistik zurücksetzen"
        case .french: "Réinitialiser les statistiques"
        case .portuguese: "Redefinir estatísticas"
        }
    }

    var supportExplanation: String {
        switch self {
        case .english:
            "If this app helps you, you can leave a tip to support its development. Thank you!"
        case .russian:
            "Если приложение вам полезно, вы можете поддержать его разработку. Спасибо!"
        case .spanish:
            "Si esta app te resulta útil, puedes dejar una propina para apoyar su desarrollo. ¡Gracias!"
        case .german:
            "Wenn dir die App hilft, kannst du ihre Entwicklung mit einem Trinkgeld unterstützen. Vielen Dank!"
        case .french:
            "Si cette app vous est utile, vous pouvez laisser un pourboire pour soutenir son développement. Merci !"
        case .portuguese:
            "Se este app é útil para você, pode deixar uma gorjeta para apoiar seu desenvolvimento. Obrigado!"
        }
    }

    /// Expected copy is independent of the running app, so a fallback to English fails.
    var localizationLabels: [String: String] {
        switch self {
        case .english:
            [
                "converter.twosComplement": "Binary in two’s complement",
                "allSystems.sourceBaseLabel": "From base",
                "allSystems.targetBaseLabel": "To base",
                "allSystems.convert": "Convert",
                "calculator.baseALabel": "Number base",
                "calculator.resultLabel": "Result",
                "quiz.category.binaryInt": "Binary numbers",
                "quiz.category.hexFraction": "Hexadecimal fractions",
                "quiz.statisticsLabel": "Overall statistics",
                "help.title": "What are number systems?",
                "privacy.title": "Privacy policy"
            ]
        case .russian:
            [
                "converter.twosComplement": "Двоичная система в дополнительном коде",
                "allSystems.sourceBaseLabel": "Из системы",
                "allSystems.targetBaseLabel": "В систему",
                "allSystems.convert": "Конвертировать",
                "calculator.baseALabel": "Основание",
                "calculator.resultLabel": "Ответ",
                "quiz.category.binaryInt": "Двоичная система счисления",
                "quiz.category.hexFraction": "Шестнадцатеричная система счисления (дробная часть)",
                "quiz.statisticsLabel": "Общая статистика",
                "help.title": "Что такое системы счисления?",
                "privacy.title": "Политика конфиденциальности"
            ]
        case .spanish:
            [
                "converter.twosComplement": "Binario en complemento a dos",
                "allSystems.sourceBaseLabel": "Base de origen",
                "allSystems.targetBaseLabel": "Base de destino",
                "allSystems.convert": "Convertir",
                "calculator.baseALabel": "Base numérica",
                "calculator.resultLabel": "Resultado",
                "quiz.category.binaryInt": "Números en base 2 (binario)",
                "quiz.category.hexFraction": "Fracciones en base 16 (hexadecimal)",
                "quiz.statisticsLabel": "Estadísticas generales",
                "help.title": "¿Qué son los sistemas de numeración?",
                "privacy.title": "Política de privacidad"
            ]
        case .german:
            [
                "converter.twosComplement": "Binär im Zweierkomplement",
                "allSystems.sourceBaseLabel": "Ausgangsbasis",
                "allSystems.targetBaseLabel": "Zielbasis",
                "allSystems.convert": "Umrechnen",
                "calculator.baseALabel": "Zahlenbasis",
                "calculator.resultLabel": "Ergebnis",
                "quiz.category.binaryInt": "Ganze Zahlen zur Basis 2 (Binär)",
                "quiz.category.hexFraction": "Brüche zur Basis 16 (Hexadezimal)",
                "quiz.statisticsLabel": "Gesamtstatistik",
                "help.title": "Was sind Zahlensysteme?",
                "privacy.title": "Datenschutzerklärung"
            ]
        case .french:
            [
                "converter.twosComplement": "Binaire en complément à deux",
                "allSystems.sourceBaseLabel": "Base de départ",
                "allSystems.targetBaseLabel": "Base d’arrivée",
                "allSystems.convert": "Convertir",
                "calculator.baseALabel": "Base de numération",
                "calculator.resultLabel": "Résultat",
                "quiz.category.binaryInt": "Entiers en base 2 (binaire)",
                "quiz.category.hexFraction": "Fractions en base 16 (hexadécimal)",
                "quiz.statisticsLabel": "Statistiques globales",
                "help.title": "Qu’est-ce qu’un système de numération ?",
                "privacy.title": "Politique de confidentialité"
            ]
        case .portuguese:
            [
                "converter.twosComplement": "Binário em complemento de dois",
                "allSystems.sourceBaseLabel": "Base de origem",
                "allSystems.targetBaseLabel": "Base de destino",
                "allSystems.convert": "Converter",
                "calculator.baseALabel": "Base numérica",
                "calculator.resultLabel": "Resultado",
                "quiz.category.binaryInt": "Inteiros na base 2 (binário)",
                "quiz.category.hexFraction": "Frações na base 16 (hexadecimal)",
                "quiz.statisticsLabel": "Estatísticas gerais",
                "help.title": "O que são sistemas de numeração?",
                "privacy.title": "Política de privacidade"
            ]
        }
    }
}
