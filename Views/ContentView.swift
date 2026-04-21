import SwiftUI

struct ContentView: View {
    @StateObject private var proxyVM = ProxyViewModel()
    @StateObject private var serverListVM = ServerListViewModel.shared
    @State private var showingServerList = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Connection Status Card
                    StatusCard(
                        status: proxyVM.status,
                        server: proxyVM.currentServer ?? serverListVM.getSelectedServer()
                    )

                    // Connection Button
                    Button(action: {
                        if proxyVM.isConnected {
                            proxyVM.disconnect()
                        } else {
                            proxyVM.connect()
                        }
                    }) {
                        HStack(spacing: 12) {
                            if proxyVM.isConnecting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: proxyVM.isConnected ? "stop.fill" : "play.fill")
                            }

                            Text(buttonText)
                                .font(.headline)
                        }
                        .frame(width: 220, height: 56)
                    }
                    .buttonStyle(ConnectionButtonStyle(isConnected: proxyVM.isConnected))
                    .disabled(proxyVM.isConnecting)
                    .padding(.top, 8)

                    // Quick Actions
                    HStack(spacing: 16) {
                        // Reconnect button
                        if proxyVM.isConnected {
                            QuickActionButton(
                                icon: "arrow.clockwise",
                                title: "重连",
                                color: .orange
                            ) {
                                proxyVM.disconnect()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    proxyVM.connect()
                                }
                            }
                        }

                        // Server list button
                        QuickActionButton(
                            icon: "list.bullet",
                            title: "服务器",
                            color: .blue
                        ) {
                            showingServerList = true
                        }
                    }

                    // Error Message
                    if let error = proxyVM.errorMessage {
                        ErrorBanner(message: error)
                    }

                    Spacer(minLength: 20)

                    // Quick Stats
                    if proxyVM.isConnected {
                        ConnectionStatsCard()
                    }

                    // Settings Link
                    NavigationLink(destination: SettingsView()) {
                        SettingsRow()
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
                .padding(.horizontal)
            }
            .navigationTitle("SOCKS5 代理")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingServerList) {
                NavigationView {
                    ServerListView()
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("完成") {
                                    showingServerList = false
                                }
                            }
                        }
                }
            }
        }
    }

    private var buttonText: String {
        if proxyVM.isConnecting {
            return "连接中..."
        } else if proxyVM.isConnected {
            return "断开连接"
        } else {
            return "连接代理"
        }
    }
}

struct QuickActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.caption)
            }
            .frame(width: 80, height: 60)
            .background(color.opacity(0.1))
            .foregroundColor(color)
            .cornerRadius(12)
        }
    }
}

struct ErrorBanner: View {
    let message: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.white)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.white)
                .multilineTextAlignment(.leading)

            Spacer()
        }
        .padding()
        .background(Color.red)
        .cornerRadius(12)
    }
}

struct ConnectionStatsCard: View {
    @ObservedObject private var proxyManager = ProxyManager.shared

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("连接统计")
                    .font(.headline)
                Spacer()
            }

            Divider()

            HStack {
                StatItem(
                    icon: "clock",
                    title: "持续时间",
                    value: proxyManager.connectionDuration
                )

                Spacer()

                StatItem(
                    icon: "network",
                    title: "状态",
                    value: "活跃"
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct StatItem: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text(value)
                .font(.system(.subheadline, design: .monospaced))
                .fontWeight(.medium)
        }
    }
}

struct SettingsRow: View {
    var body: some View {
        HStack {
            Image(systemName: "gear")
                .font(.title2)
                .foregroundColor(.secondary)

            Text("设置")
                .font(.headline)
                .foregroundColor(.primary)

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct ConnectionButtonStyle: ButtonStyle {
    let isConnected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(isConnected ? Color.red : Color.blue)
            .foregroundColor(.white)
            .cornerRadius(28)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
            .shadow(color: (isConnected ? Color.red : Color.blue).opacity(0.3), radius: 8, x: 0, y: 4)
    }
}

#Preview {
    ContentView()
}
