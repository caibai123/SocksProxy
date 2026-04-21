import Foundation

struct ProxyServer: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var host: String
    var port: Int
    var username: String?
    var password: String?
    var isSelected: Bool

    init(id: UUID = UUID(), name: String, host: String, port: Int, username: String? = nil, password: String? = nil, isSelected: Bool = false) {
        self.id = id
        self.name = name
        self.host = host
        self.port = port
        self.username = username
        self.password = password
        self.isSelected = isSelected
    }

    static func == (lhs: ProxyServer, rhs: ProxyServer) -> Bool {
        lhs.id == rhs.id
    }
}
