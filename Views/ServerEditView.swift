import SwiftUI

struct ServerEditView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showingAdvanced = false

    let server: ProxyServer?
    let onSave: (ProxyServer) -> Void

    @State private var name: String = ""
    @State private var host: String = ""
    @State private var port: String = "1080"
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var useAuth: Bool = false

    @State private var nameError: String? = nil
    @State private var hostError: String? = nil
    @State private var portError: String? = nil

    private var isValid: Bool {
        validateAll() &&
        (!useAuth || (!username.isEmpty && !password.isEmpty))
    }

    var body: some View {
        Form {
            // Basic Info Section
            Section {
                TextField("服务器名称", text: $name)
                    .textContentType(.name)
                    .autocapitalization(.words)
                    .onChange(of: name) { _ in validateName() }

                if let error = nameError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            } header: {
                Text("基本信息")
            } footer: {
                Text("为服务器设置一个易于识别的名称")
            }

            // Connection Info Section
            Section {
                HStack {
                    TextField("服务器地址", text: $host)
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        .onChange(of: host) { _ in validateHost() }

                    Button(action: pasteFromClipboard) {
                        Image(systemName: "doc.on.clipboard")
                            .foregroundColor(.blue)
                    }
                }

                if let error = hostError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }

                HStack {
                    TextField("端口", text: $port)
                        .keyboardType(.numberPad)
                        .onChange(of: port) { _ in validatePort() }

                    Text("1-65535")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if let error = portError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            } header: {
                Text("连接信息")
            } footer: {
                Text("输入 SOCKS5 服务器的地址和端口")
            }

            // Authentication Section
            Section {
                Toggle("使用认证", isOn: $useAuth)

                if useAuth {
                    TextField("用户名", text: $username)
                        .textContentType(.username)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()

                    SecureField("密码", text: $password)
                        .textContentType(.password)
                }
            } header: {
                Text("认证设置")
            } footer: {
                if !useAuth {
                    Text("部分 SOCKS5 服务器可能需要认证")
                } else {
                    Text("输入 SOCKS5 服务器提供的用户名和密码")
                }
            }

            // Advanced Options
            Section {
                DisclosureGroup("高级选项", isExpanded: $showingAdvanced) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("协议版本")
                            Spacer()
                            Text("SOCKS5")
                                .foregroundColor(.secondary)
                        }

                        HStack {
                            Text("超时设置")
                            Spacer()
                            Text("10 秒")
                                .foregroundColor(.secondary)
                        }

                        HStack {
                            Text("自动重连")
                            Spacer()
                            Text("支持")
                                .foregroundColor(.secondary)
                        }
                    }
                    .font(.subheadline)
                    .padding(.top, 8)
                }
            } header: {
                Text("高级")
            }

            // Quick Actions
            if server != nil {
                Section {
                    Button(action: testConnection) {
                        HStack {
                            Image(systemName: "network")
                            Text("测试连接")
                        }
                    }
                } header: {
                    Text("操作")
                }
            }
        }
        .navigationTitle(server == nil ? "添加服务器" : "编辑服务器")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    saveServer()
                }
                .disabled(!isValid)
            }
        }
        .onAppear {
            loadServerData()
        }
    }

    private func loadServerData() {
        if let server = server {
            name = server.name
            host = server.host
            port = String(server.port)
            username = server.username ?? ""
            password = server.password ?? ""
            useAuth = server.username != nil && !server.username!.isEmpty
        }
    }

    // MARK: - Validation

    private func validateAll() -> Bool {
        let nameValid = validateName()
        let hostValid = validateHost()
        let portValid = validatePort()
        return nameValid && hostValid && portValid
    }

    private func validateName() -> Bool {
        if name.trimmingCharacters(in: .whitespaces).isEmpty {
            nameError = "请输入服务器名称"
            return false
        }
        nameError = nil
        return true
    }

    private func validateHost() -> Bool {
        let trimmedHost = host.trimmingCharacters(in: .whitespaces)
        if trimmedHost.isEmpty {
            hostError = "请输入服务器地址"
            return false
        }

        // Basic validation
        let hostRegex = #"^[a-zA-Z0-9]([a-zA-Z0-9\-\.]*[a-zA-Z0-9])?$"#
        if trimmedHost.range(of: hostRegex, options: .regularExpression) == nil {
            hostError = "请输入有效的服务器地址"
            return false
        }

        hostError = nil
        return true
    }

    private func validatePort() -> Bool {
        guard let portNum = Int(port), portNum > 0, portNum <= 65535 else {
            portError = "端口必须在 1-65535 之间"
            return false
        }
        portError = nil
        return true
    }

    // MARK: - Actions

    private func pasteFromClipboard() {
        if let string = UIPasteboard.general.string {
            host = string
            validateHost()
        }
    }

    private func testConnection() {
        guard isValid else { return }

        let testServer = ProxyServer(
            id: server?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespaces),
            host: host.trimmingCharacters(in: .whitespaces),
            port: Int(port) ?? 1080,
            username: useAuth ? username.trimmingCharacters(in: .whitespaces) : nil,
            password: useAuth ? password : nil,
            isSelected: server?.isSelected ?? false
        )

        ServerListViewModel.shared.testServer(testServer)
    }

    private func saveServer() {
        let newServer = ProxyServer(
            id: server?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespaces),
            host: host.trimmingCharacters(in: .whitespaces),
            port: Int(port) ?? 1080,
            username: useAuth ? username.trimmingCharacters(in: .whitespaces) : nil,
            password: useAuth ? password : nil,
            isSelected: server?.isSelected ?? false
        )
        onSave(newServer)
        dismiss()
    }
}

#Preview {
    NavigationView {
        ServerEditView(server: nil) { _ in }
    }
}
