import SwiftUI

@main
struct SocksProxyApp: App {
    init() {
        // Initialize storage manager
        _ = StorageManager.shared

        // Load saved servers
        ServerListViewModel.shared.loadServers()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
