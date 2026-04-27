import Foundation

struct ProxyServer: Identifiable, Codable {
    var id: UUID
    var name: String
    var host: String
    var port: Int
    var username: String?
    var password: String?

    static let defaultServer = ProxyServer(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        name: "默认服务器",
        host: "121.204.251.76",
        port: 1081,
        username: "cb",
        password: "cb"
    )
}
