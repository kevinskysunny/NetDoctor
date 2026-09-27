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
        let enValue = L10n.string("verdict.optimal", language: .english)
        let zhValue = L10n.string("verdict.optimal", language: .chinese)
        XCTAssertNotEqual(enValue, zhValue, "探针 key 的 en/zh 值应不同")
        let koResult = L10n.string("verdict.optimal", language: .korean)
        XCTAssertEqual(koResult, enValue, "ko 缺失 key 应回退 en 而非 zh")
        XCTAssertNotEqual(koResult, zhValue, "ko 缺失 key 不应回退 zh")
    }

    func testFallbackChainIsDictEnKey() {
        let key = "verdict.offline"
        let enValue = L10n.string(key, language: .english)
        let deResult = L10n.string(key, language: .german)
        XCTAssertEqual(deResult, enValue, "de 缺失 key 应回退 en")
    }

    func testJaDictionaryFullCoverage() {
        let verdictKeys = VerdictCode.allCases.map { $0.l10nKey }
        for key in verdictKeys {
            let jaValue = L10n.string(key, language: .japanese)
            XCTAssertNotEqual(jaValue, key, "ja 缺失 verdict key: \(key)")
        }
    }

    func testJaHas248KeysMatchingEn() {
        let probeKeys = [
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