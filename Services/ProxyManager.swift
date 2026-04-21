import Foundation
import Combine

enum ConnectionStatus: Equatable {
    case disconnected
    case connecting
    case connected
    case error(String)

    static func == (lhs: ConnectionStatus, rhs: ConnectionStatus) -> Bool {
        switch (lhs, rhs) {
        case (.disconnected, .disconnected): return true
        case (.connecting, .connecting): return true
        case (.connected, .connected): return true
        case (.error(let a), .error(let b)): return a == b
        default: return false
        }
    }
}

enum ConnectionError: Error, LocalizedError {
    case invalidServer
    case connectionTimeout
    case authenticationFailed
    case serverUnreachable
    case networkError(String)
    case unknown

    var errorDescription: String? {
        switch self {
        case .invalidServer:
            return "无效的服务器配置"
        case .connectionTimeout:
            return "连接超时"
        case .authenticationFailed:
            return "认证失败"
        case .serverUnreachable:
            return "服务器不可达"
        case .networkError(let message):
            return "网络错误: \(message)"
        case .unknown:
            return "未知错误"
        }
    }
}

class ProxyManager: ObservableObject, Socks5ConnectionDelegate {
    static let shared = ProxyManager()

    @Published var status: ConnectionStatus = .disconnected
    @Published var currentServer: ProxyServer?
    @Published var errorMessage: String?
    @Published var connectionStartTime: Date?

    private var connection: Socks5Connection?
    private var cancellables = Set<AnyCancellable>()
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 3

    private init() {}

    func connect(to server: ProxyServer) {
        guard status != .connecting else { return }

        // Validate server configuration
        guard isValidServer(server) else {
            status = .error(ConnectionError.invalidServer.localizedDescription ?? "无效服务器")
            errorMessage = ConnectionError.invalidServer.localizedDescription
            return
        }

        status = .connecting
        currentServer = server
        errorMessage = nil
        reconnectAttempts = 0

        establishConnection(to: server)
    }

    private func establishConnection(to server: ProxyServer) {
        connection?.disconnect()
        connection = Socks5Connection(delegate: self)

        // Add connection timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            guard let self = self else { return }
            if case .connecting = self.status {
                self.connection?.disconnect()
                self.status = .error("连接超时")
                self.errorMessage = "连接超时，请检查服务器地址和端口"
            }
        }

        connection?.connect(to: server)
    }

    func disconnect() {
        connection?.disconnect()
        connection = nil
        status = .disconnected
        connectionStartTime = nil
        reconnectAttempts = 0
    }

    func reconnect() {
        guard let server = currentServer else { return }

        if reconnectAttempts < maxReconnectAttempts {
            reconnectAttempts += 1
            disconnect()

            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                self?.status = .connecting
                self?.establishConnection(to: server)
            }
        } else {
            errorMessage = "重连失败，已达到最大重试次数"
            status = .error("重连失败")
        }
    }

    private func isValidServer(_ server: ProxyServer) -> Bool {
        return !server.host.isEmpty &&
               server.port > 0 &&
               server.port <= 65535
    }

    // MARK: - Connection Statistics

    var connectionDuration: String {
        guard let startTime = connectionStartTime else { return "--:--:--" }

        let interval = Date().timeIntervalSince(startTime)
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        let seconds = Int(interval) % 60

        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    // MARK: - Socks5ConnectionDelegate

    func connectionDidConnect() {
        status = .connected
        connectionStartTime = Date()
        errorMessage = nil
        reconnectAttempts = 0

        // Start connection duration timer
        startDurationTimer()
    }

    func connectionDidDisconnect(error: Error?) {
        let wasConnected = connectionStartTime != nil

        status = .disconnected
        connectionStartTime = nil

        if let error = error {
            errorMessage = error.localizedDescription

            // Auto-reconnect on unexpected disconnect
            if wasConnected && reconnectAttempts < maxReconnectAttempts {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                    self?.reconnect()
                }
            }
        }
    }

    func connectionDidFail(with error: Error) {
        status = .error(error.localizedDescription)
        errorMessage = error.localizedDescription
        connectionStartTime = nil
    }

    // MARK: - Timer

    private var durationTimer: Timer?

    private func startDurationTimer() {
        durationTimer?.invalidate()
        durationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.objectWillChange.send()
        }
    }
}
