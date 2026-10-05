import AppKit
import Foundation

public enum SystemSettingsPane: String, CaseIterable, Sendable {
    case network = "x-apple.systempreferences:com.apple.preference.network"
    case wifi = "x-apple.systempreferences:com.apple.preference.network?Wi-Fi"
    case ethernet = "x-apple.systempreferences:com.apple.preference.network?Ethernet"
    case dns = "x-apple.systempreferences:com.apple.Network-Settings.extension?DNS"

    public var url: URL? {
        URL(string: rawValue)
    }

    public var fallbackPane: SystemSettingsPane? {
        switch self {
        case .network:
            return nil
        case .wifi, .ethernet, .dns:
            return .network
        }
    }
}

public struct SystemSettingsNavigator {
    public typealias URLOpener = @Sendable (URL) -> Bool

    @discardableResult
    public static func open(
        _ pane: SystemSettingsPane,
        opener: URLOpener = { NSWorkspace.shared.open($0) }
    ) -> Bool {
        guard let url = pane.url else { return false }
        let success = opener(url)
        if !success, let fallback = pane.fallbackPane, let fallbackURL = fallback.url {
            return opener(fallbackURL)
        }
        return success
    }
}
