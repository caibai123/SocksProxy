import Foundation
import Combine

class ProxyManager: ObservableObject {
    static let shared = ProxyManager()

    @Published var status: ProxyStatus = .disconnected
    @Published var connectionDuration: String = "--:--:--"
    @Published var errorMessage: String?

    private var server: Socks5Server?
    private var connectionStartTime: Date?
    private var durationTimer: Timer?

    private init() {}

    func connect() {
        guard case .disconnected = status else { return }

        status = .connecting
        errorMessage = nil

        server = Socks5Server()
        server?.delegate = self
        server?.start(port: 1080)
    }

    func disconnect() {
        durationTimer?.invalidate()
        durationTimer = nil

        server?.stop()
        server = nil

        connectionStartTime = nil
        status = .disconnected
        connectionDuration = "--:--:--"
    }
}

extension ProxyManager: Socks5ServerDelegate {
    func socks5ServerDidStart(port: UInt16) {
        DispatchQueue.main.async {
            self.status = .connected(localPort: port)
            self.connectionStartTime = Date()
            self.startDurationTimer()
        }
    }

    func socks5ServerDidStop() {
        DispatchQueue.main.async {
            self.status = .disconnected
        }
    }

    func socks5ServerDidFail(error: String) {
        DispatchQueue.main.async {
            self.status = .error(error)
            self.errorMessage = error
        }
    }
}

extension ProxyManager {
    private func startDurationTimer() {
        durationTimer?.invalidate()
        durationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, let start = self.connectionStartTime else { return }
            let interval = Int(Date().timeIntervalSince(start))
            let h = interval / 3600
            let m = (interval % 3600) / 60
            let s = interval % 60
            self.connectionDuration = String(format: "%02d:%02d:%02d", h, m, s)
        }
    }
}

extension ProxyStatus: CustomStringConvertible {
    var description: String {
        switch self {
        case .disconnected: return "未连接"
        case .connecting: return "连接中..."
        case .connected(let port): return "已连接 (本地端口: \(port))"
        case .error(let msg): return "错误: \(msg)"
        }
    }
}
