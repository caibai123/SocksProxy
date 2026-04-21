import Foundation
import Combine

class ServerListViewModel: ObservableObject {
    static let shared = ServerListViewModel()

    @Published var servers: [ProxyServer] = []
    @Published var searchText: String = ""
    @Published var isTesting: Bool = false
    @Published var testResults: [UUID: ServerTestResult] = [:]

    private let storageKey = "proxy_servers"
    private let selectedKey = "selected_server_id"

    private init() {
        loadServers()
    }

    var filteredServers: [ProxyServer] {
        if searchText.isEmpty {
            return servers
        }
        return servers.filter { server in
            server.name.localizedCaseInsensitiveContains(searchText) ||
            server.host.localizedCaseInsensitiveContains(searchText)
        }
    }

    func loadServers() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([ProxyServer].self, from: data) {
            servers = decoded
        }
    }

    func saveServers() {
        if let encoded = try? JSONEncoder().encode(servers) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }

    func addServer(_ server: ProxyServer) {
        servers.append(server)
        saveServers()
    }

    func updateServer(_ server: ProxyServer) {
        if let index = servers.firstIndex(where: { $0.id == server.id }) {
            servers[index] = server
            saveServers()
        }
    }

    func deleteServer(at indexSet: IndexSet) {
        let filteredIndices = indexSet.compactMap { index in
            filteredServers.firstIndex(where: { $0.id == servers[index].id })
        }
        servers.remove(atOffsets: IndexSet(filteredIndices))
        saveServers()
    }

    func deleteServer(_ server: ProxyServer) {
        servers.removeAll { $0.id == server.id }
        saveServers()
    }

    func selectServer(_ server: ProxyServer) {
        for index in servers.indices {
            servers[index].isSelected = (servers[index].id == server.id)
        }
        saveServers()
        UserDefaults.standard.set(server.id.uuidString, forKey: selectedKey)
    }

    func getSelectedServer() -> ProxyServer? {
        return servers.first { $0.isSelected }
    }

    // MARK: - Server Testing

    func testServer(_ server: ProxyServer) {
        isTesting = true
        testResults[server.id] = ServerTestResult(status: .testing, latency: nil)

        let startTime = Date()

        // Create test connection
        let connection = Socks5Connection(delegate: nil)

        // Use a simple TCP connection test instead of full SOCKS5 handshake
        // since we're just testing if the server is reachable
        var request = URLRequest(url: URL(string: "https://\(server.host):\(server.port)")!)
        request.httpMethod = "CONNECT"
        request.timeoutInterval = 5

        let task = URLSession.shared.dataTask(with: request) { [weak self] _, response, error in
            DispatchQueue.main.async {
                self?.isTesting = false

                let latency = Date().timeIntervalSince(startTime) * 1000 // Convert to ms

                if let error = error {
                    self?.testResults[server.id] = ServerTestResult(
                        status: .failed(error.localizedDescription),
                        latency: nil
                    )
                } else if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 200 || httpResponse.statusCode == 407 {
                        // 407 means proxy requires authentication, but server is reachable
                        self?.testResults[server.id] = ServerTestResult(
                            status: .success,
                            latency: Int(latency)
                        )
                    } else {
                        self?.testResults[server.id] = ServerTestResult(
                            status: .failed("Status: \(httpResponse.statusCode)"),
                            latency: nil
                        )
                    }
                } else {
                    self?.testResults[server.id] = ServerTestResult(
                        status: .success,
                        latency: Int(latency)
                    )
                }
            }
        }
        task.resume()

        // Timeout fallback
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            if self?.testResults[server.id]?.status == .testing {
                self?.testResults[server.id] = ServerTestResult(
                    status: .failed("Connection timeout"),
                    latency: nil
                )
                task.cancel()
            }
        }
    }

    func getTestResult(for server: ProxyServer) -> ServerTestResult? {
        return testResults[server.id]
    }
}

struct ServerTestResult {
    enum TestStatus {
        case testing
        case success
        case failed(String)
    }

    let status: TestStatus
    let latency: Int?

    var icon: String {
        switch status {
        case .testing: return "arrow.triangle.2.circlepath"
        case .success: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        }
    }

    var color: String {
        switch status {
        case .testing: return "orange"
        case .success: return "green"
        case .failed: return "red"
        }
    }
}
