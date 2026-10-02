import XCTest
@testable import NetworkConsoleApp
@testable import NetworkCore

final class L10nFallbackTests: XCTestCase {
    func testKeyExistsInDictReturnsDictValue() {
        let result = L10n.string("app.name", language: .chinese)
        XCTAssertEqual(result, "NetDoctor")
    }

    func testKeyMissingInDictButExistsInEnReturnsEnValue() {
        let result = L10n.string("app.name", language: .korean)
        XCTAssertEqual(result, "NetDoctor")
    }

    func testKeyMissingInDictAndEnReturnsKeyItself() {
        let result = L10n.string("nonexistent.key.xyz", language: .chinese)
        XCTAssertEqual(result, "nonexistent.key.xyz")
    }

    func testNonChineseLanguageDoesNotFallbackToChinese() {
        let probeKey = "probe.test.untranslated"
        let enValue = L10n.string(probeKey, language: .english)
        let zhValue = L10n.string(probeKey, language: .chinese)
        XCTAssertEqual(enValue, probeKey, "en 缺失 key 应回退 key 本身")
        XCTAssertEqual(zhValue, probeKey, "zh 缺失 key 应回退 key 本身（不回退中文）")
        let koResult = L10n.string(probeKey, language: .korean)
        XCTAssertEqual(koResult, probeKey, "ko 缺失 key 应回退 key 本身（不回退 zh）")
    }

    func testFallbackChainIsDictEnKey() {
        let probeKey = "probe.test.untranslated"
        let result = L10n.string(probeKey, language: .german)
        XCTAssertEqual(result, probeKey, "de 缺失 key 且 en 缺失时返回 key 本身")
    }

    func testAll8LanguagesHave274Keys() {
        let expectedCount = 274
        let languages: [AppLanguage] = [.chinese, .english, .japanese, .korean, .german, .french, .spanish, .portuguese]
        for lang in languages {
            let dict = L10n.dictionary(for: lang)
            XCTAssertEqual(dict.count, expectedCount, "\(lang.rawValue) 应有 \(expectedCount) key")
        }
    }

    func testJaDictionaryFullCoverage() {
        let verdictKeys = VerdictCode.allCases.map { $0.l10nKey }
        for key in verdictKeys {
            let jaValue = L10n.string(key, language: .japanese)
            XCTAssertNotEqual(jaValue, key, "ja 缺失 verdict key: \(key)")
        }
    }

    func testJaHas274KeysMatchingEn() {
        let probeKeys = [
            "settings.addEndpoint", "settings.deleteEndpoint", "settings.endpoint.addTitle",
            "settings.endpoint.name", "settings.endpoint.host", "settings.endpoint.protocol",
            "settings.endpoint.port", "settings.endpoint.path", "common.cancel", "common.add",
            "verdict.checking", "verdict.optimal", "verdict.good", "verdict.dnsSlow",
            "verdict.constrained", "verdict.jitterLoss", "verdict.highLatency", "verdict.warningDefault",
            "verdict.offline", "verdict.noInterface", "verdict.allProbesFailed", "verdict.criticalDefault",
            "verdict.notChecked",
            "detail.copyCard",
            "settings.privacy.title", "settings.privacy.subtitle",
            "settings.engine.title", "settings.engine.subtitle",
            "settings.auto.title", "settings.auto.subtitle",
            "settings.endpoints.title", "settings.ecosystem.title",
            "settings.presenterdeck.title", "settings.presenterdeck.desc",
            "dnsRoute.dns.primary", "dnsRoute.dns.secondary",
            "dnsRoute.route.defaultHeroTitle", "dnsRoute.route.telemetryTitle",
            "interfaces.telemetry.activeTitle", "interfaces.telemetry.dualStackTitle",
            "quick.bento.dns", "quick.bento.interface", "quick.bento.latency", "quick.bento.reachability",
            "reachability.chart.title", "reachability.chart.latency",
            "timeline.filter.all", "timeline.filter.checks", "timeline.filter.exports", "timeline.filter.pathChanges",
            "timeline.filterEmpty.title", "timeline.filterEmpty.message",
        ]
        for key in probeKeys {
            let jaValue = L10n.string(key, language: .japanese)
            XCTAssertNotEqual(jaValue, key, "ja 缺失 key: \(key)")
        }
    }
}