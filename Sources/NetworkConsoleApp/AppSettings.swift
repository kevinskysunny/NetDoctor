import Foundation
import NetworkCore

struct AppSettings: Codable, Equatable {
    var attemptsPerEndpoint: Int = 3
    var timeoutSeconds: Double = 2.5
    var autoRefreshEnabled: Bool = true
    var refreshIntervalSeconds: Int = 300
    var endpoints: [ReachabilityEndpoint] = ReachabilityEndpoint.defaultPublicEndpoints

    var supportPackageSettings: SupportPackageSettings {
        SupportPackageSettings(
            attemptsPerEndpoint: attemptsPerEndpoint,
            timeoutSeconds: timeoutSeconds,
            autoRefreshEnabled: autoRefreshEnabled,
            refreshIntervalSeconds: refreshIntervalSeconds
        )
    }

    static func load() -> AppSettings {
        Self.migrateLegacySettingsIfNeeded()
        guard
            let data = UserDefaults.standard.data(forKey: "netdoctor.settings"),
            let decoded = try? JSONDecoder().decode(AppSettings.self, from: data)
        else {
            return AppSettings()
        }
        return decoded
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: "netdoctor.settings")
    }

    static func migrateLegacySettingsIfNeeded() {
        let defaults = UserDefaults.standard
        let oldKey = "networkConsoleLite.settings"
        let newKey = "netdoctor.settings"
        if let oldValue = defaults.object(forKey: oldKey), defaults.object(forKey: newKey) == nil {
            defaults.set(oldValue, forKey: newKey)
        }
    }
}
