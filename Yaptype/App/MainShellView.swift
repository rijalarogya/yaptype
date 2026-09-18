import SwiftUI

struct MainShellView: View {
    @EnvironmentObject private var navigation: AppNavigation

    var body: some View {
        HStack(spacing: 0) {
            SidebarView()
                .frame(width: 228)
            Divider().background(YaptypeTheme.line)
            page
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(YaptypeTheme.canvas)
        }
        .background(YaptypeTheme.canvas)
        .transaction { $0.animation = nil }
    }

    @ViewBuilder
    private var page: some View {
        switch navigation.page {
        case .home:
            HomeView()
        case .noteTaker:
            NoteTakerView()
        case .fileTranscription:
            FileTranscriptionView()
        case .history:
            HistoryView()
        case .general:
            GeneralSettingsView()
        case .models:
            ModelsSettingsView()
        case .diagnostics:
            DiagnosticsView()
        }
    }
}

struct SidebarView: View {
    @EnvironmentObject private var navigation: AppNavigation

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                YaptypeLogoMark(size: 28)
                Text("Yaptype")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(YaptypeTheme.ink)
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 18)

            sidebarButton(.home)
            sidebarButton(.noteTaker)
            sidebarButton(.fileTranscription)
            sidebarButton(.history)

            Text("SETTINGS")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(YaptypeTheme.muted)
                .padding(.horizontal, 24)
                .padding(.top, 22)
                .padding(.bottom, 8)

            sidebarButton(.general)
            sidebarButton(.models)
            sidebarButton(.diagnostics)

            Spacer()
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(YaptypeTheme.sidebar)
    }

    private func sidebarButton(_ page: AppPage) -> some View {
        let selected = navigation.page == page
        return Button {
            navigation.go(page)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: page.symbol)
                    .font(.system(size: 14))
                    .frame(width: 18)
                Text(page.title)
                    .font(.system(size: 13.5))
                Spacer(minLength: 0)
            }
            .foregroundStyle(selected ? YaptypeTheme.orange : YaptypeTheme.ink.opacity(0.85))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(selected ? YaptypeTheme.orangeSoft : Color.clear)
            )
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
    }
}
