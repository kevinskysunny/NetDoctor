import XCTest
@testable import NetworkConsoleApp

final class SystemSettingsNavigatorTests: XCTestCase {
    func testAllPanesHaveValidURLs() {
        for pane in SystemSettingsPane.allCases {
            XCTAssertNotNil(pane.url, "\(pane) URL should be valid")
            XCTAssertTrue(pane.url?.scheme == "x-apple.systempreferences", "\(pane) scheme should be x-apple.systempreferences")
        }
    }

    func testSpecificPaneURLs() {
        XCTAssertEqual(SystemSettingsPane.network.url?.absoluteString, "x-apple.systempreferences:com.apple.preference.network")
        XCTAssertEqual(SystemSettingsPane.wifi.url?.absoluteString, "x-apple.systempreferences:com.apple.preference.network?Wi-Fi")
        XCTAssertEqual(SystemSettingsPane.ethernet.url?.absoluteString, "x-apple.systempreferences:com.apple.preference.network?Ethernet")
        XCTAssertEqual(SystemSettingsPane.dns.url?.absoluteString, "x-apple.systempreferences:com.apple.Network-Settings.extension?DNS")
    }

    func testFallbackPaneConfigurations() {
        XCTAssertNil(SystemSettingsPane.network.fallbackPane)
        XCTAssertEqual(SystemSettingsPane.wifi.fallbackPane, .network)
        XCTAssertEqual(SystemSettingsPane.ethernet.fallbackPane, .network)
        XCTAssertEqual(SystemSettingsPane.dns.fallbackPane, .network)
    }

    func testOpenPrimarySuccessDoesNotTriggerFallback() {
        var openedURLs = [URL]()
        let opener: SystemSettingsNavigator.URLOpener = { url in
            openedURLs.append(url)
            return true
        }

        let result = SystemSettingsNavigator.open(.dns, opener: opener)
        XCTAssertTrue(result)
        XCTAssertEqual(openedURLs.count, 1)
        XCTAssertEqual(openedURLs.first, SystemSettingsPane.dns.url)
    }

    func testOpenPrimaryFailureTriggersFallback() {
        var openedURLs = [URL]()
        let opener: SystemSettingsNavigator.URLOpener = { url in
            openedURLs.append(url)
            if url == SystemSettingsPane.dns.url {
                return false
            }
            return true
        }

        let result = SystemSettingsNavigator.open(.dns, opener: opener)
        XCTAssertTrue(result)
        XCTAssertEqual(openedURLs.count, 2)
        XCTAssertEqual(openedURLs[0], SystemSettingsPane.dns.url)
        XCTAssertEqual(openedURLs[1], SystemSettingsPane.network.url)
    }

    func testOpenNetworkFailureReturnsFalseWithoutFallback() {
        var openedURLs = [URL]()
        let opener: SystemSettingsNavigator.URLOpener = { url in
            openedURLs.append(url)
            return false
        }

        let result = SystemSettingsNavigator.open(.network, opener: opener)
        XCTAssertFalse(result)
        XCTAssertEqual(openedURLs.count, 1)
        XCTAssertEqual(openedURLs.first, SystemSettingsPane.network.url)
    }
}
