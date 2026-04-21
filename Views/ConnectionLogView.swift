import SwiftUI

struct ConnectionLogView: View {
    @StateObject private var logManager = ConnectionLogManager.shared
    @State private var selectedFilter: LogFilter = .all

    enum LogFilter: String, CaseIterable {
        case all = "全部"
        case today = "今天"
        case errors = "错误"
    }

    var filteredEntries: [ConnectionLogEntry] {
        switch selectedFilter {
        case .all:
            return logManager.entries
        case .today:
            return logManager.getTodayEntries()
        case .errors:
            return logManager.entries.filter {
                if case .connectionFailed = $0.event {
                    return true
                }
                return false
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Filter Picker
            Picker("筛选", selection: $selectedFilter) {
                ForEach(LogFilter.allCases, id: \.self) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            if filteredEntries.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "doc.text")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    Text("暂无日志")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("连接历史将显示在这里")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                List {
                    ForEach(filteredEntries) { entry in
                        LogEntryRow(entry: entry)
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("连接日志")
        .toolbar {
            if !logManager.entries.isEmpty {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        logManager.clearLog()
                    }) {
                        Image(systemName: "trash")
                    }
                }
            }
        }
    }
}

struct LogEntryRow: View {
    let entry: ConnectionLogEntry

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: entry.eventIcon)
                .foregroundColor(colorFromString(entry.eventColor))
                .font(.title2)

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.eventDescription)
                    .font(.subheadline)
                    .foregroundColor(.primary)

                HStack(spacing: 8) {
                    Text(entry.formattedTime)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(entry.serverHost)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private func colorFromString(_ colorString: String) -> Color {
        switch colorString {
        case "green": return .green
        case "red": return .red
        case "orange": return .orange
        case "gray": return .gray
        default: return .gray
        }
    }
}

#Preview {
    NavigationView {
        ConnectionLogView()
    }
}
