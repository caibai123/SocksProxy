import Foundation

struct ConnectionLogEntry: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let serverName: String
    let serverHost: String
    let event: ConnectionEvent
    let duration: TimeInterval?
    let errorMessage: String?

    enum ConnectionEvent: String, Codable {
        case connected
        case disconnected
        case connectionFailed
        case reconnecting
    }

    init(serverName: String, serverHost: String, event: ConnectionEvent, duration: TimeInterval? = nil, errorMessage: String? = nil) {
        self.id = UUID()
        self.timestamp = Date()
        self.serverName = serverName
        self.serverHost = serverHost
        self.event = event
        self.duration = duration
        self.errorMessage = errorMessage
    }

    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: timestamp)
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: timestamp)
    }

    var eventIcon: String {
        switch event {
        case .connected: return "checkmark.circle.fill"
        case .disconnected: return "xmark.circle.fill"
        case .connectionFailed: return "exclamationmark.triangle.fill"
        case .reconnecting: return "arrow.clockwise"
        }
    }

    var eventColor: String {
        switch event {
        case .connected: return "green"
        case .disconnected: return "gray"
        case .connectionFailed: return "red"
        case .reconnecting: return "orange"
        }
    }

    var eventDescription: String {
        switch event {
        case .connected:
            return "已连接到 \(serverName)"
        case .disconnected:
            if let duration = duration {
                let hours = Int(duration) / 3600
                let minutes = (Int(duration) % 3600) / 60
                let seconds = Int(duration) % 60
                return "断开连接 (持续 \(hours)小时\(minutes)分\(seconds)秒)"
            }
            return "已断开连接"
        case .connectionFailed:
            return "连接失败: \(errorMessage ?? "未知错误")"
        case .reconnecting:
            return "正在重新连接..."
        }
    }
}

class ConnectionLogManager: ObservableObject {
    static let shared = ConnectionLogManager()

    @Published var entries: [ConnectionLogEntry] = []

    private let storageKey = "connection_log"
    private let maxEntries = 100

    private init() {
        loadEntries()
    }

    func loadEntries() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([ConnectionLogEntry].self, from: data) {
            entries = decoded
        }
    }

    func saveEntries() {
        if let encoded = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }

    func addEntry(_ entry: ConnectionLogEntry) {
        entries.insert(entry, at: 0)

        // Limit entries
        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }

        saveEntries()
    }

    func logConnection(serverName: String, serverHost: String) {
        let entry = ConnectionLogEntry(
            serverName: serverName,
            serverHost: serverHost,
            event: .connected
        )
        addEntry(entry)
    }

    func logDisconnection(serverName: String, serverHost: String, duration: TimeInterval?) {
        let entry = ConnectionLogEntry(
            serverName: serverName,
            serverHost: serverHost,
            event: .disconnected,
            duration: duration
        )
        addEntry(entry)
    }

    func logConnectionFailed(serverName: String, serverHost: String, error: String?) {
        let entry = ConnectionLogEntry(
            serverName: serverName,
            serverHost: serverHost,
            event: .connectionFailed,
            errorMessage: error
        )
        addEntry(entry)
    }

    func logReconnecting(serverName: String, serverHost: String) {
        let entry = ConnectionLogEntry(
            serverName: serverName,
            serverHost: serverHost,
            event: .reconnecting
        )
        addEntry(entry)
    }

    func clearLog() {
        entries.removeAll()
        saveEntries()
    }

    func getTodayEntries() -> [ConnectionLogEntry] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date())

        return entries.filter { $0.formattedDate == today }
    }

    func getEntriesGroupedByDate() -> [(String, [ConnectionLogEntry])] {
        let grouped = Dictionary(grouping: entries) { $0.formattedDate }
        return grouped.sorted { $0.key > $1.key }
    }
}
