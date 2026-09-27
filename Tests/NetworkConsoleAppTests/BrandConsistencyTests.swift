import XCTest
@testable import NetworkConsoleApp
@testable import NetworkCore

final class BrandConsistencyTests: XCTestCase {
    func testSupportPackageFilenameUsesNetDoctorPrefix() {
        let exporter = SupportPackageExporter()
        let filename = exporter.suggestedFilename(now: Date(timeIntervalSince1970: 0))
        XCTAssertTrue(filename.hasPrefix("NetDoctor-Support-"), "支持包文件名应使用 NetDoctor 前缀")
        XCTAssertFalse(filename.contains("NetworkConsoleLite"), "支持包文件名不应含旧品牌")
    }

    func testTimelineStoreDirectoryUsesNetDoctor() {
        let url = TimelineStore.defaultFileURL()
        XCTAssertNotNil(url)
        XCTAssertTrue(url?.path.contains("NetDoctor") == true, "TimelineStore 路径应含 NetDoctor")
        XCTAssertFalse(url?.path.contains("NetworkConsoleLite") == true, "TimelineStore 路径不应含旧品牌")
    }

    func testTimelineStoreMigrateMethodExists() {
        TimelineStore.migrateLegacyDirectoryIfNeeded()
    }

    func testAppSettingsKeyUsesNetDoctorPrefix() {
        let defaults = UserDefaults.standard
        let testValue = "brand-consistency-test"
        defaults.removeObject(forKey: "netdoctor.settings")
        defaults.set(testValue, forKey: "netdoctor.settings")
        let read = defaults.string(forKey: "netdoctor.settings")
        XCTAssertEqual(read, testValue)
        defaults.removeObject(forKey: "netdoctor.settings")
    }

    func testNoBrandResidueInCoreSources() {
        let url = TimelineStore.defaultFileURL()
        XCTAssertNotNil(url)
        XCTAssertTrue(url?.path.contains("NetworkConsoleLite") == false)
    }
}