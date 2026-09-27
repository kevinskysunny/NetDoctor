import XCTest
@testable import NetworkConsoleApp
@testable import NetworkCore

final class AppModelLocalizationTests: XCTestCase {
    func testVerdictCodeMapsToCorrectL10nKeyInAllLanguages() {
        for code in VerdictCode.allCases {
            let key = code.l10nKey
            for lang in [AppLanguage.chinese, .english, .japanese] {
                let value = L10n.string(key, language: lang)
                XCTAssertNotEqual(value, key, "VerdictCode \(code) 缺失 \(lang.rawValue) 文案")
            }
        }
    }

    func testAdviceCodeMapsToCorrectL10nKeyInAllLanguages() {
        for code in AdviceCode.allCases where code != .unknown {
            let titleKey = code.titleKey
            let messageKey = code.messageKey
            for lang in [AppLanguage.chinese, .english, .japanese] {
                XCTAssertNotEqual(L10n.string(titleKey, language: lang), titleKey, "AdviceCode \(code) title 缺失 \(lang.rawValue) 文案")
                XCTAssertNotEqual(L10n.string(messageKey, language: lang), messageKey, "AdviceCode \(code) message 缺失 \(lang.rawValue) 文案")
            }
        }
    }

    func testVerdictCodeL10nKeyFormat() {
        XCTAssertEqual(VerdictCode.optimal.l10nKey, "verdict.optimal")
        XCTAssertEqual(VerdictCode.criticalDefault.l10nKey, "verdict.criticalDefault")
        XCTAssertEqual(VerdictCode.allProbesFailed.l10nKey, "verdict.allProbesFailed")
    }

    func testAdviceCodeKeyFormat() {
        XCTAssertEqual(AdviceCode.confirmConnection.titleKey, "advice.confirmConnection.title")
        XCTAssertEqual(AdviceCode.confirmConnection.messageKey, "advice.confirmConnection.message")
        XCTAssertEqual(AdviceCode.partialUnreachable.titleKey, "advice.partialUnreachable.title")
    }

    func testVerdictCodeCaseCount() {
        XCTAssertEqual(VerdictCode.allCases.count, 12, "VerdictCode 应有 12 case")
    }

    func testAdviceCodeCaseCount() {
        XCTAssertEqual(AdviceCode.allCases.count, 10, "AdviceCode 应有 10 case（9 advice + .unknown）")
    }
}