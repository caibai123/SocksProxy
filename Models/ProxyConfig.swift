import Foundation

struct ProxyConfig: Codable {
    var serverID: UUID?
    var autoConnect: Bool
    var connectionTimeout: TimeInterval

    init(serverID: UUID? = nil, autoConnect: Bool = false, connectionTimeout: TimeInterval = 10.0) {
        self.serverID = serverID
        self.autoConnect = autoConnect
        self.connectionTimeout = connectionTimeout
    }
}
