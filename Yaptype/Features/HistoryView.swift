import SwiftUI

enum HistoryRange: String, CaseIterable, Identifiable {
    case all
    case today
    case week

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "All time"
        case .today: "Today"
        case .week: "Last 7 days"
        }
    }
}

struct HistoryView: View {
    @EnvironmentObject private var history: HistoryStore
    @State private var query = ""
    @State private var kindFilter: HistoryKind?
    @State private var range: HistoryRange = .all

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                PageHeader(title: AppPage.history.title, subtitle: AppPage.history.subtitle)
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(YaptypeTheme.muted)
                    TextField("Search history", text: $query)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(width: 240)
                .background(YaptypeTheme.card, in: Capsule())
                .overlay(Capsule().stroke(YaptypeTheme.line))
            }

            YaptypeCard(padding: 0) {
                VStack(spacing: 0) {
                    HStack {
                        filterChip(title: "All", selected: kindFilter == nil) {
                            kindFilter = nil
                        }
                        ForEach(HistoryKind.allCases) { kind in
                            filterChip(title: kind.filterTitle, selected: kindFilter == kind) {
                                kindFilter = kind
                            }
                        }
                        Spacer()
                        MacPopupButton(
                            selection: $range,
                            options: HistoryRange.allCases.map { ($0, $0.title) }
                        )
                        .frame(width: 140, height: 28)
                    }
                    .padding(16)

                    if filtered.isEmpty {
                        Text("Nothing here yet.")
                            .foregroundStyle(YaptypeTheme.muted)
                            .frame(maxWidth: .infinity, minHeight: 180)
                    } else {
                        ForEach(groupedKeys, id: \.self) { key in
                            HStack {
                                Text(key.uppercased())
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(YaptypeTheme.muted)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                            ForEach(grouped[key] ?? []) { item in
                                historyRow(item)
                                Divider().overlay(YaptypeTheme.line).padding(.leading, 52)
                            }
                        }
                    }

                    HStack {
                        Text("Showing recent activity")
                            .font(.caption)
                            .foregroundStyle(YaptypeTheme.muted)
                        Spacer()
                        Button("Clear history", role: .destructive) {
                            history.clear()
                        }
                        .disabled(history.items.isEmpty)
                    }
                    .padding(16)
                }
            }
            }
        }
        .padding(28)
        .background(YaptypeTheme.canvas)
    }

    private var filtered: [HistoryItem] {
        history.items.filter { item in
            if let kindFilter, item.kind != kindFilter { return false }
            switch range {
            case .all:
                break
            case .today:
                if !Calendar.current.isDateInToday(item.createdAt) { return false }
            case .week:
                if item.createdAt < Date().addingTimeInterval(-7 * 24 * 3600) { return false }
            }
            if query.isEmpty { return true }
            let haystack = (item.displayText + " " + item.displayTitle).lowercased()
            return haystack.contains(query.lowercased())
        }
    }

    private var grouped: [String: [HistoryItem]] {
        Dictionary(grouping: filtered) { item in
            if Calendar.current.isDateInToday(item.createdAt) { return "Today" }
            if Calendar.current.isDateInYesterday(item.createdAt) { return "Yesterday" }
            return item.createdAt.formatted(date: .abbreviated, time: .omitted)
        }
    }

    private var groupedKeys: [String] {
        let order = ["Today", "Yesterday"]
        return grouped.keys.sorted { lhs, rhs in
            let l = order.firstIndex(of: lhs) ?? Int.max
            let r = order.firstIndex(of: rhs) ?? Int.max
            if l != r { return l < r }
            return lhs > rhs
        }
    }

    private func filterChip(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12.5))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .foregroundStyle(selected ? YaptypeTheme.orange : YaptypeTheme.ink)
                .background(
                    Capsule().fill(selected ? YaptypeTheme.orangeSoft : Color.clear)
                )
                .overlay(
                    Capsule().stroke(selected ? Color.clear : YaptypeTheme.line)
                )
        }
        .buttonStyle(.plain)
    }

    private func historyRow(_ item: HistoryItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: item.kind.symbol)
                .foregroundStyle(YaptypeTheme.muted)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 4) {
                Text(item.kind == .dictation ? item.displayText : item.displayTitle)
                    .foregroundStyle(YaptypeTheme.ink)
                    .lineLimit(2)
                if item.kind != .dictation {
                    Text(item.previewText)
                        .foregroundStyle(YaptypeTheme.muted)
                        .lineLimit(1)
                }
                Text("\(item.createdAt.formatted(date: .omitted, time: .shortened)) · \(item.kind.title) · \(item.modelTitle) · \(TimeFormat.compact(item.audioSeconds))")
                    .foregroundStyle(YaptypeTheme.muted)
            }
            Spacer()
            GhostButton(title: "Copy", symbol: "doc.on.doc") {
                Clipboard.copy(item.displayText)
            }
            Button {
                history.delete(item)
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(YaptypeTheme.muted)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .help("Delete")
        }
        .font(.system(size: 13))
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .contextMenu {
            Button("Copy") { Clipboard.copy(item.displayText) }
            Button("Delete", role: .destructive) { history.delete(item) }
        }
    }
}
