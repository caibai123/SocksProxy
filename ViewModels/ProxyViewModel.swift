import Foundation
import Combine

class ProxyViewModel: ObservableObject {
    @Published var status: ProxyStatus = .disconnected
    @Published var connectionDuration: String = "--:--:--"
    @Published var errorMessage: String?

    private let proxyManager = ProxyManager.shared
    private var cancellables = Set<AnyCancellable>()

    var isConnected: Bool {
        if case .connected = status { return true }
        return false
    }

    var isConnecting: Bool {
        if case .connecting = status { return true }
        return false
    }

    var buttonText: String {
        if isConnecting { return "连接中..." }
        if isConnected { return "断开连接" }
        return "连接代理"
    }

    var statusText: String {
        switch status {
        case .disconnected: return "未连接"
        case .connecting: return "连接中..."
        case .connected(let port): return "已连接 (端口: \(port))"
        case .error(let msg): return "错误: \(msg)"
        }
    }

    init() {
        setupBindings()
    }

    private func setupBindings() {
        proxyManager.$status
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.status = status
            }
            .store(in: &cancellables)

        proxyManager.$connectionDuration
            .receive(on: DispatchQueue.main)
            .sink { [weak self] duration in
                self?.connectionDuration = duration
            }
            .store(in: &cancellables)

        proxyManager.$errorMessage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                self?.errorMessage = message
            }
            .store(in: &cancellables)
    }

    func toggle() {
        if isConnected || isConnecting {
            proxyManager.disconnect()
        } else {
            proxyManager.connect()
        }
    }
}
