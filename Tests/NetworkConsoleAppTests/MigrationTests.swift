import XCTest
@testable import NetworkConsoleApp

final class MigrationTests: XCTestCase {
    private let oldSettingsKey = "networkConsoleLite.settings"
    private let newSettingsKey = "netdoctor.settings"
    private let oldLanguageKey = "networkConsoleLite.language"
    private let newLanguageKey = "netdoctor.language"

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: oldSettingsKey)
        UserDefaults.standard.removeObject(forKey: newSettingsKey)
        UserDefaults.standard.removeObject(forKey: oldLanguageKey)
        UserDefaults.standard.removeObject(forKey: newLanguageKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: oldSettingsKey)
        UserDefaults.standard.removeObject(forKey: newSettingsKey)
        UserDefaults.standard.removeObject(forKey: oldLanguageKey)
        UserDefaults.standard.removeObject(forKey: newLanguageKey)
        super.tearDown()
    }

    func testSettingsMigrateWhenOldKeyExistsAndNewKeyMissing() {
        let payload = "legacy-settings-payload"
        UserDefaults.standard.set(payload, forKey: oldSettingsKey)
        XCTAssertNil(UserDefaults.standard.object(forKey: newSettingsKey))
        AppSettings.migrateLegacySettingsIfNeeded()
        let migrated = UserDefaults.standard.string(forKey: newSettingsKey)
        XCTAssertEqual(migrated, payload, "旧 key 有值 + 新 key 无值 → 应迁移")
    }

    func testSettingsDoNotMigrateWhenNewKeyAlreadyExists() {
        let oldPayload = "legacy-settings-payload"
        let newPayload = "current-settings-payload"
        UserDefaults.standard.set(oldPayload, forKey: oldSettingsKey)
        UserDefaults.standard.set(newPayload, forKey: newSettingsKey)
        AppSettings.migrateLegacySettingsIfNeeded()
        let current = UserDefaults.standard.string(forKey: newSettingsKey)
        XCTAssertEqual(current, newPayload, "新 key 已有值 → 不应覆盖")
    }

    func testSettingsDoNotMigrateWhenOldKeyMissing() {
        AppSettings.migrateLegacySettingsIfNeeded()
        XCTAssertNil(UserDefaults.standard.object(forKey: newSettingsKey), "旧 key 无值 → 不迁移")
    }

    func testSettingsMigrationDoesNotDeleteOldKey() {
        let payload = "legacy-settings-payload"
        UserDefaults.standard.set(payload, forKey: oldSettingsKey)
        AppSettings.migrateLegacySettingsIfNeeded()
        let oldStillExists = UserDefaults.standard.string(forKey: oldSettingsKey)
        XCTAssertEqual(oldStillExists, payload, "迁移后旧 key 不应删除（降级兼容）")
    }

    func testSettingsMigrationIsIdempotent() {
        let payload = "legacy-settings-payload"
        UserDefaults.standard.set(payload, forKey: oldSettingsKey)
        AppSettings.migrateLegacySettingsIfNeeded()
        let firstMigration = UserDefaults.standard.string(forKey: newSettingsKey)
        AppSettings.migrateLegacySettingsIfNeeded()
        let secondMigration = UserDefaults.standard.string(forKey: newSettingsKey)
        XCTAssertEqual(firstMigration, secondMigration, "重复迁移应幂等")
    }
}