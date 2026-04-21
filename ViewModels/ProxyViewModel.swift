import Foundation
import Combine

class ProxyViewModel: ObservableObject {
    @Published var status: ConnectionStatus = .disconnected
    @Published var currentServer: ProxyServer?
    @Published var errorMessage: String?

    private let proxyManager = ProxyManager.shared
    private var cancellables = Set<AnyCancellable>()

    var isConnected: Bool {
        if case .connected = status {
            return true
        }
        return false
    }

    var isConnecting: Bool {
        if case .connecting = status {
            return true
        }
        return false
    }

    var statusText: String {
        switch status {
        case .disconnected:
            return "未连接"
        case .connecting:
            return "连接中..."
        case .connected:
            return "已连接"
        case .error(let message):
            return "错误: \(message)"
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

        proxyManager.$currentServer
            .receive(on: DispatchQueue.main)
            .sink { [weak self] server in
                self?.currentServer = server
            }
            .store(in: &cancellables)

        proxyManager.$errorMessage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                self?.errorMessage = message
            }
            .store(in: &cancellables)
    }

    func connect() {
        if let server = currentServer {
            proxyManager.connect(to: server)
        } else if let selectedServer = ServerListViewModel.shared.servers.first(where: { $0.isSelected }) {
            currentServer = selectedServer
            proxyManager.connect(to: selectedServer)
        }
    }

    func disconnect() {
        proxyManager.disconnect()
    }

    func selectServer(_ server: ProxyServer) {
        currentServer = server
        ServerListViewModel.shared.selectServer(server)
    }
}
