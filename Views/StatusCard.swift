import SwiftUI

struct StatusCard: View {
    let status: ConnectionStatus
    let server: ProxyServer?
    @ObservedObject private var proxyManager = ProxyManager.shared

    var statusColor: Color {
        switch status {
        case .disconnected:
            return .gray
        case .connecting:
            return .orange
        case .connected:
            return .green
        case .error:
            return .red
        }
    }

    var statusIcon: String {
        switch status {
        case .disconnected:
            return "wifi.slash"
        case .connecting:
            return "wifi.exclamationmark"
        case .connected:
            return "wifi"
        case .error:
            return "exclamationmark.triangle"
        }
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
            return message
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            // Status Icon with animation
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.2))
                    .frame(width: 100, height: 100)

                Circle()
                    .fill(statusColor.opacity(0.4))
                    .frame(width: 80, height: 80)

                Image(systemName: statusIcon)
                    .font(.system(size: 40, weight: .medium))
                    .foregroundColor(statusColor)
            }
            .modifier(PulseAnimation(isAnimating: status == .connecting))

            // Status Text
            Text(statusText)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)

            // Connection Duration
            if case .connected = status {
                HStack {
                    Image(systemName: "clock")
                        .font(.caption)
                    Text(proxyManager.connectionDuration)
                        .font(.system(.caption, design: .monospaced))
                }
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }

            Divider()

            // Server Info
            if let server = server {
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "server.rack")
                            .foregroundColor(.blue)
                        Text(server.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                    }

                    HStack(spacing: 8) {
                        Image(systemName: "network")
                            .font(.caption2)
                        Text("\(server.host):\(server.port)")
                            .font(.subheadline)
                    }
                    .foregroundColor(.secondary)

                    if let username = server.username, !username.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "person.fill")
                                .font(.caption2)
                            Text(username)
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                    }
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title2)
                        .foregroundColor(.orange)
                    Text("未选择服务器")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("请在服务器列表中选择一个服务器")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .padding(.horizontal)
    }
}

struct PulseAnimation: ViewModifier {
    let isAnimating: Bool
    @State private var scale: CGFloat = 1.0

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .onAppear {
                if isAnimating {
                    withAnimation(Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                        scale = 1.1
                    }
                } else {
                    scale = 1.0
                }
            }
            .onChange(of: isAnimating) { newValue in
                if newValue {
                    withAnimation(Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                        scale = 1.1
                    }
                } else {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        scale = 1.0
                    }
                }
            }
    }
}

#Preview {
    VStack(spacing: 20) {
        StatusCard(status: .disconnected, server: nil)

        StatusCard(
            status: .connected,
            server: ProxyServer(
                name: "测试服务器",
                host: "192.168.1.100",
                port: 1080,
                username: "user1",
                password: "pass1"
            )
        )

        StatusCard(
            status: .error("连接失败"),
            server: ProxyServer(
                name: "错误服务器",
                host: "192.168.1.100",
                port: 1080
            )
        )
    }
}
