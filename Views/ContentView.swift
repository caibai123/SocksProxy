import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ProxyViewModel()

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // App title
                VStack(spacing: 8) {
                    Image(systemName: "network")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)

                    Text("SOCKS5 代理")
                        .font(.title)
                        .fontWeight(.bold)

                    Text("TCP 透明代理工具")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                // Status card
                VStack(spacing: 16) {
                    // Status indicator
                    Circle()
                        .fill(statusColor)
                        .frame(width: 16, height: 16)

                    Text(viewModel.statusText)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)

                    if viewModel.isConnected {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.caption)
                            Text(viewModel.connectionDuration)
                                .font(.system(.caption, design: .monospaced))
                        }
                        .foregroundColor(.secondary)
                    }
                }
                .padding(24)
                .background(Color(.systemGray6))
                .cornerRadius(16)

                // Connect button
                Button(action: {
                    viewModel.toggle()
                }) {
                    HStack(spacing: 12) {
                        if viewModel.isConnecting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: viewModel.isConnected ? "stop.fill" : "play.fill")
                                .font(.title2)
                        }

                        Text(viewModel.buttonText)
                            .font(.headline)
                    }
                    .frame(width: 200, height: 56)
                    .background(viewModel.isConnected ? Color.red : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(28)
                    .shadow(color: (viewModel.isConnected ? Color.red : Color.blue).opacity(0.4),
                            radius: 8, x: 0, y: 4)
                }
                .disabled(viewModel.isConnecting)

                // Error message
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                // Server info (minimal, not editable)
                HStack(spacing: 4) {
                    Image(systemName: "server.rack")
                        .font(.caption2)
                    Text("默认服务器")
                        .font(.caption2)
                    Text("121.204.251.76:1081")
                        .font(.system(.caption2, design: .monospaced))
                }
                .foregroundColor(.secondary)
                .padding(.bottom, 32)
            }
            .padding()
        }
    }

    private var statusColor: Color {
        switch viewModel.status {
        case .disconnected: return .gray
        case .connecting: return .orange
        case .connected: return .green
        case .error: return .red
        }
    }
}

#Preview {
    ContentView()
}
