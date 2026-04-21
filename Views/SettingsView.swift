import SwiftUI

struct SettingsView: View {
    @AppStorage("autoConnect") private var autoConnect = false
    @AppStorage("connectionTimeout") private var connectionTimeout = 10.0
    @AppStorage("showNotifications") private var showNotifications = true
    @AppStorage("vibrateOnConnect") private var vibrateOnConnect = true

    @State private var showingClearAlert = false
    @State private var showingExportSheet = false
    @State private var showingImportPicker = false
    @State private var exportedConfig: String = ""

    var body: some View {
        Form {
            // Connection Settings
            Section {
                Toggle("启动时自动连接", isOn: $autoConnect)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("连接超时")
                        Spacer()
                        Text("\(Int(connectionTimeout)) 秒")
                            .foregroundColor(.secondary)
                    }

                    Slider(value: $connectionTimeout, in: 5...30, step: 5)
                        .tint(.blue)
                }
            } header: {
                Text("连接设置")
            } footer: {
                Text("自动连接将在应用启动时连接上次选中的服务器")
            }

            // Notifications
            Section {
                Toggle("显示通知", isOn: $showNotifications)
                Toggle("连接时震动", isOn: $vibrateOnConnect)
            } header: {
                Text("通知")
            } footer: {
                Text("连接状态变化时显示系统通知")
            }

            // Server Management
            Section {
                NavigationLink(destination: ServerListView()) {
                    HStack {
                        Image(systemName: "server.rack")
                            .foregroundColor(.blue)
                        Text("管理服务器")
                    }
                }

                NavigationLink(destination: ConnectionLogView()) {
                    HStack {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundColor(.orange)
                        Text("连接日志")
                    }
                }

                Button(action: exportConfig) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(.blue)
                        Text("导出配置")
                            .foregroundColor(.primary)
                    }
                }

                Button(action: { showingImportPicker = true }) {
                    HStack {
                        Image(systemName: "square.and.arrow.down")
                            .foregroundColor(.blue)
                        Text("导入配置")
                            .foregroundColor(.primary)
                    }
                }
            } header: {
                Text("服务器管理")
            }

            // About
            Section {
                HStack {
                    Text("版本")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("构建")
                    Spacer()
                    Text("1")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("协议")
                    Spacer()
                    Text("SOCKS5")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("认证")
                    Spacer()
                    Text("RFC 1929")
                        .foregroundColor(.secondary)
                }

                Link(destination: URL(string: "https://github.com")!) {
                    HStack {
                        Text("GitHub")
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text("关于")
            }

            // Data Management
            Section {
                Button(action: { showingClearAlert = true }) {
                    HStack {
                        Spacer()
                        Text("清除所有数据")
                            .foregroundColor(.red)
                        Spacer()
                    }
                }
            } footer: {
                Text("清除所有保存的服务器、设置和连接历史")
            }
        }
        .navigationTitle("设置")
        .alert("清除所有数据", isPresented: $showingClearAlert) {
            Button("取消", role: .cancel) { }
            Button("清除", role: .destructive) {
                clearAllData()
            }
        } message: {
            Text("确定要清除所有数据吗？此操作无法撤销。")
        }
        .sheet(isPresented: $showingExportSheet) {
            NavigationView {
                VStack(spacing: 20) {
                    Text("导出配置")
                        .font(.headline)
                        .padding(.top)

                    Text("复制以下配置信息")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    ScrollView {
                        Text(exportedConfig)
                            .font(.system(.caption, design: .monospaced))
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                    .frame(maxHeight: 300)

                    Button("复制到剪贴板") {
                        UIPasteboard.general.string = exportedConfig
                    }
                    .buttonStyle(.borderedProminent)

                    Spacer()
                }
                .padding()
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("完成") {
                            showingExportSheet = false
                        }
                    }
                }
            }
        }
        .fileImporter(
            isPresented: $showingImportPicker,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }
    }

    private func exportConfig() {
        let servers = ServerListViewModel.shared.servers

        do {
            let data = try JSONEncoder().encode(servers)
            exportedConfig = String(data: data, encoding: .utf8) ?? "编码失败"
            showingExportSheet = true
        } catch {
            exportedConfig = "导出失败: \(error.localizedDescription)"
            showingExportSheet = true
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }

            do {
                let data = try Data(contentsOf: url)
                let servers = try JSONDecoder().decode([ProxyServer].self, from: data)

                // Add imported servers
                for server in servers {
                    ServerListViewModel.shared.addServer(server)
                }
            } catch {
                print("Import failed: \(error)")
            }

        case .failure(let error):
            print("File picker failed: \(error)")
        }
    }

    private func clearAllData() {
        // Clear UserDefaults
        UserDefaults.standard.removeObject(forKey: "proxy_servers")
        UserDefaults.standard.removeObject(forKey: "selected_server_id")
        UserDefaults.standard.removeObject(forKey: "connection_log")

        // Reload servers
        ServerListViewModel.shared.loadServers()

        // Reset settings
        autoConnect = false
        connectionTimeout = 10.0
        showNotifications = true
        vibrateOnConnect = true
    }
}

#Preview {
    NavigationView {
        SettingsView()
    }
}
