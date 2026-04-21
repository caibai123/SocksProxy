# SocksProxy

iOS SOCKS5 代理应用，类似 Shadowrocket，支持连接到远程 SOCKS5 服务器。

## 功能特性

### 核心功能
- **SOCKS5 代理连接** - 支持标准 SOCKS5 协议 (RFC 1928)
- **用户名密码认证** - 支持 RFC 1929 用户名/密码认证
- **多服务器管理** - 添加、编辑、删除多个代理服务器
- **服务器选择** - 快速在多个服务器间切换

### 连接功能
- **IPv4/IPv6 支持** - 自动识别和支持 IPv4、IPv6 地址及域名
- **连接超时设置** - 可调节的连接超时时间 (5-30 秒)
- **自动重连** - 连接断开后自动尝试重新连接 (最多 3 次)
- **启动时自动连接** - 可选的自动连接功能

### 服务器管理
- **服务器测试** - 一键测试服务器连通性和延迟
- **配置导入/导出** - JSON 格式，方便备份和分享
- **搜索过滤** - 快速查找服务器

### 连接日志
- **连接历史** - 记录所有连接事件
- **筛选功能** - 按类型筛选 (全部/今天/错误)
- **错误追踪** - 记录连接失败详情

### 用户界面
- **实时状态** - 清晰的连接状态显示
- **连接时长** - 显示当前连接持续时间
- **动画效果** - 连接中的脉冲动画
- **深色模式** - 支持系统深色模式

## 技术栈

| 组件 | 技术 |
|------|------|
| 语言 | Swift 5.0+ |
| UI 框架 | SwiftUI |
| 网络库 | CocoaAsyncSocket |
| 数据存储 | UserDefaults |
| 架构 | MVVM |
| 最低版本 | iOS 15.0 |

## 项目结构

```
SocksProxy/
├── App/
│   └── SocksProxyApp.swift          # 应用入口
├── Models/
│   ├── ProxyServer.swift            # 服务器模型
│   └── ProxyConfig.swift            # 配置模型
├── Views/
│   ├── ContentView.swift            # 主界面
│   ├── StatusCard.swift             # 状态卡片
│   ├── ServerListView.swift         # 服务器列表
│   ├── ServerEditView.swift         # 服务器编辑
│   ├── SettingsView.swift           # 设置页面
│   └── ConnectionLogView.swift      # 连接日志
├── ViewModels/
│   ├── ProxyViewModel.swift          # 代理 ViewModel
│   └── ServerListViewModel.swift     # 服务器列表 ViewModel
├── Services/
│   ├── Socks5Connection.swift        # SOCKS5 连接核心
│   └── ProxyManager.swift            # 代理管理器
├── Utils/
│   ├── StorageManager.swift         # 数据持久化
│   └── ConnectionLogManager.swift   # 日志管理
└── Resources/
    └── Assets.xcassets              # 资源文件
```

## 构建项目

### 前置要求
- Xcode 15.0+
- XcodeGen (用于生成 .xcodeproj)
- 物理 iOS 设备 (用于真机测试)

### 构建步骤

1. **安装 XcodeGen**
   ```bash
   brew install xcodegen
   ```

2. **生成 Xcode 项目**
   ```bash
   cd SocksProxy
   xcodegen generate
   ```

3. **打开项目**
   ```bash
   open SocksProxy.xcodeproj
   ```

4. **配置签名**
   - 在 Xcode 中选择你的 Team
   - 选择物理设备作为运行目标

5. **构建并运行**
   - Product > Build
   - Product > Run

### 自签安装

如需在不通过 App Store 的情况下安装应用：

1. **创建 Apple Developer 账号的证书和配置文件**
2. **在 Xcode 中设置签名 (手动选择证书和配置文件)**
3. **导出 IPA**
   - Product > Archive
   - 选择 Distribute App > Development
4. **使用 AltStore 或 Xcode 安装**

## 使用说明

### 添加服务器
1. 点击主界面"服务器"按钮
2. 点击右下角"+"按钮
3. 输入服务器信息：
   - 服务器名称
   - 服务器地址 (IP 或域名)
   - 端口号 (默认 1080)
   - 用户名密码 (如需认证)

### 连接代理
1. 从服务器列表选择一个服务器
2. 返回主界面
3. 点击"连接代理"按钮
4. 等待连接建立

### 查看日志
1. 进入"设置"
2. 点击"连接日志"
3. 可按类型筛选查看

## 安全说明

- 用户名和密码存储在本地 UserDefaults
- 建议仅在可信网络环境下使用
- 导出的配置包含敏感信息，请妥善保管

## 协议

- SOCKS5 协议: RFC 1928
- SOCKS5 用户名密码认证: RFC 1929

## 版本

当前版本: 1.0.0
