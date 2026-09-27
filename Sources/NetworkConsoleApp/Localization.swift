import Foundation

enum AppLanguage: String, Codable, CaseIterable, Identifiable, Sendable {
    case system = "system"
    case english = "en"
    case chinese = "zh-Hans"
    case japanese = "ja"
    case korean = "ko"
    case german = "de"
    case french = "fr"
    case spanish = "es"
    case portuguese = "pt"

    var id: String { rawValue }

    var displayName: String {
        displayName(in: .system)
    }

    func displayName(in language: AppLanguage) -> String {
        switch self {
        case .system:
            return L10n.string("settings.language.system", language: language)
        case .english: return "English"
        case .chinese: return "中文"
        case .japanese: return "日本語"
        case .korean: return "한국어"
        case .german: return "Deutsch"
        case .french: return "Français"
        case .spanish: return "Español"
        case .portuguese: return "Português"
        }
    }

    var resolvedLanguage: AppLanguage {
        resolveEffective(preferredLanguages: Locale.preferredLanguages)
    }

    var locale: Locale {
        switch resolvedLanguage {
        case .system: return Locale.current
        case .english: return Locale(identifier: "en_US")
        case .chinese: return Locale(identifier: "zh_Hans_CN")
        case .japanese: return Locale(identifier: "ja_JP")
        case .korean: return Locale(identifier: "ko_KR")
        case .german: return Locale(identifier: "de_DE")
        case .french: return Locale(identifier: "fr_FR")
        case .spanish: return Locale(identifier: "es_ES")
        case .portuguese: return Locale(identifier: "pt_BR")
        }
    }

    func resolveEffective(preferredLanguages: [String] = Locale.preferredLanguages) -> AppLanguage {
        guard self == .system else { return self }
        for identifier in preferredLanguages {
            let lower = identifier.lowercased()
            if lower.hasPrefix("zh") { return .chinese }
            if lower.hasPrefix("ja") { return .japanese }
            if lower.hasPrefix("ko") { return .korean }
            if lower.hasPrefix("de") { return .german }
            if lower.hasPrefix("fr") { return .french }
            if lower.hasPrefix("es") { return .spanish }
            if lower.hasPrefix("pt") { return .portuguese }
            if lower.hasPrefix("en") { return .english }
        }
        return .english
    }

    static func from(stored: String?) -> AppLanguage {
        guard let stored, !stored.isEmpty else { return .system }
        if let exact = AppLanguage(rawValue: stored) {
            return exact
        }
        let lower = stored.lowercased()
        if lower.hasPrefix("zh") { return .chinese }
        if lower.hasPrefix("en") { return .english }
        if lower.hasPrefix("ja") { return .japanese }
        if lower.hasPrefix("ko") { return .korean }
        if lower.hasPrefix("de") { return .german }
        if lower.hasPrefix("fr") { return .french }
        if lower.hasPrefix("es") { return .spanish }
        if lower.hasPrefix("pt") { return .portuguese }
        return .system
    }
}

enum L10n {
    static func string(_ key: String, language: AppLanguage) -> String {
        let resolved = language.resolvedLanguage
        let dict: [String: String]
        switch resolved {
        case .chinese: dict = zh
        case .english: dict = en
        case .japanese: dict = ja
        case .korean: dict = ko
        case .german: dict = de
        case .french: dict = fr
        case .spanish: dict = es
        case .portuguese: dict = pt
        case .system: dict = en
        }
        return dict[key] ?? en[key] ?? key
    }

    static func dictionary(for language: AppLanguage) -> [String: String] {
        let resolved = language.resolvedLanguage
        switch resolved {
        case .chinese: return zh
        case .english: return en
        case .japanese: return ja
        case .korean: return ko
        case .german: return de
        case .french: return fr
        case .spanish: return es
        case .portuguese: return pt
        case .system: return en
        }
    }

}
