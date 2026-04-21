import Foundation

class StorageManager {
    static let shared = StorageManager()

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let proxyServers = "proxy_servers"
        static let selectedServerID = "selected_server_id"
        static let autoConnect = "auto_connect"
        static let connectionTimeout = "connection_timeout"
    }

    private init() {}

    // MARK: - Server Management

    func saveServers(_ servers: [ProxyServer]) {
        if let encoded = try? JSONEncoder().encode(servers) {
            defaults.set(encoded, forKey: Keys.proxyServers)
        }
    }

    func loadServers() -> [ProxyServer] {
        guard let data = defaults.data(forKey: Keys.proxyServers),
              let servers = try? JSONDecoder().decode([ProxyServer].self, from: data) else {
            return []
        }
        return servers
    }

    func saveSelectedServerID(_ id: UUID?) {
        defaults.set(id?.uuidString, forKey: Keys.selectedServerID)
    }

    func loadSelectedServerID() -> UUID? {
        guard let idString = defaults.string(forKey: Keys.selectedServerID) else { return nil }
        return UUID(uuidString: idString)
    }

    // MARK: - Settings

    var autoConnect: Bool {
        get { defaults.bool(forKey: Keys.autoConnect) }
        set { defaults.set(newValue, forKey: Keys.autoConnect) }
    }

    var connectionTimeout: TimeInterval {
        get {
            let value = defaults.double(forKey: Keys.connectionTimeout)
            return value > 0 ? value : 10.0
        }
        set { defaults.set(newValue, forKey: Keys.connectionTimeout) }
    }

    // MARK: - Clear Data

    func clearAllData() {
        defaults.removeObject(forKey: Keys.proxyServers)
        defaults.removeObject(forKey: Keys.selectedServerID)
        defaults.removeObject(forKey: Keys.autoConnect)
        defaults.removeObject(forKey: Keys.connectionTimeout)
    }
}
