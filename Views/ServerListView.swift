import SwiftUI

struct ServerListView: View {
    @StateObject private var viewModel = ServerListViewModel.shared
    @State private var showingAddServer = false
    @State private var editingServer: ProxyServer?

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("搜索服务器", text: $viewModel.searchText)
                    .textFieldStyle(.plain)
                if !viewModel.searchText.isEmpty {
                    Button(action: { viewModel.searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(12)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            .padding()

            // Server list
            List {
                ForEach(viewModel.filteredServers) { server in
                    ServerRowView(
                        server: server,
                        isSelected: server.isSelected,
                        testResult: viewModel.getTestResult(for: server)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        viewModel.selectServer(server)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            viewModel.deleteServer(server)
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            viewModel.testServer(server)
                        } label: {
                            Label("测试", systemImage: "network")
                        }
                        .tint(.blue)

                        Button {
                            editingServer = server
                        } label: {
                            Label("编辑", systemImage: "pencil")
                        }
                        .tint(.orange)
                    }
                    .contextMenu {
                        Button {
                            viewModel.selectServer(server)
                        } label: {
                            Label("选择", systemImage: "checkmark.circle")
                        }

                        Button {
                            viewModel.testServer(server)
                        } label: {
                            Label("测试连接", systemImage: "network")
                        }

                        Button {
                            editingServer = server
                        } label: {
                            Label("编辑", systemImage: "pencil")
                        }

                        Divider()

                        Button(role: .destructive) {
                            viewModel.deleteServer(server)
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
        .navigationTitle("服务器列表")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showingAddServer = true
                }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddServer) {
            NavigationView {
                ServerEditView(server: nil) { newServer in
                    viewModel.addServer(newServer)
                }
            }
        }
        .sheet(item: $editingServer) { server in
            NavigationView {
                ServerEditView(server: server) { updatedServer in
                    viewModel.updateServer(updatedServer)
                }
            }
        }
        .overlay {
            if viewModel.servers.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "server.rack")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    Text("暂无服务器")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("点击右上角添加服务器")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Button("添加服务器") {
                        showingAddServer = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }
}

struct ServerRowView: View {
    let server: ProxyServer
    let isSelected: Bool
    let testResult: ServerTestResult?

    var body: some View {
        HStack(spacing: 12) {
            // Test result indicator
            if let result = testResult {
                Image(systemName: result.icon)
                    .foregroundColor(colorFromString(result.color))
                    .font(.title3)
                    .rotationEffect(result.status == .testing ? .degrees(0) : .degrees(0))
                    .animation(result.status == .testing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: result.status)
            } else {
                Image(systemName: "circle")
                    .foregroundColor(.gray)
                    .font(.title3)
            }

            // Server info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(server.name)
                        .font(.headline)

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.blue)
                            .font(.caption)
                    }
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

                // Latency display
                if let result = testResult, case .success = result.status, let latency = result.latency {
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill")
                            .font(.caption2)
                        Text("\(latency)ms")
                            .font(.caption)
                    }
                    .foregroundColor(.green)
                }
            }

            Spacer()

            // Selection indicator
            if isSelected {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 12, height: 12)
            }
        }
        .padding(.vertical, 8)
    }

    private func colorFromString(_ colorString: String) -> Color {
        switch colorString {
        case "green": return .green
        case "red": return .red
        case "orange": return .orange
        default: return .gray
        }
    }
}

#Preview {
    NavigationView {
        ServerListView()
    }
}
