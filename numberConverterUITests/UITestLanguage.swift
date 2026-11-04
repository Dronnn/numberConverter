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
}
