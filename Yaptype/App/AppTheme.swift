import AppKit
import SwiftUI

enum YaptypeTheme {
    static let canvas = Color(hex: "F6F3EE")
    static let sidebar = Color(hex: "F4F0EA")
    static let card = Color.white
    static let ink = Color(hex: "2B241C")
    static let muted = Color(hex: "8A8076")
    static let line = Color(hex: "E8E2D8")
    static let orange = Color(hex: "E87832")
    static let orangeSoft = Color(hex: "FDE8D4")
    static let green = Color(hex: "2FA36B")
}

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        self.init(
            .sRGB,
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255,
            opacity: 1
        )
    }
}

struct YaptypeCard<Content: View>: View {
    var padding: CGFloat = 20
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(YaptypeTheme.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(YaptypeTheme.line, lineWidth: 1)
                    )
            }
    }
}

struct YaptypeLogoMark: View {
    var size: CGFloat = 28

    var body: some View {
        Group {
            if let image = Self.image {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
    }

    static var image: NSImage? {
        if let named = NSImage(named: "YaptypeLogo") {
            return named
        }
        #if SWIFT_PACKAGE
        if let moduleImage = Bundle.module.image(forResource: "YaptypeLogo") {
            return moduleImage
        }
        #endif
        if let url = Bundle.main.url(forResource: "Yaptype_Yaptype", withExtension: "bundle"),
           let bundle = Bundle(url: url),
           let bundled = bundle.image(forResource: "YaptypeLogo") {
            return bundled
        }
        return NSImage(named: "AppIcon") ?? NSApplication.shared.applicationIconImage
    }
}

struct PageHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 26, weight: .regular))
                .foregroundStyle(YaptypeTheme.ink)
            Text(subtitle)
                .font(.system(size: 13))
                .foregroundStyle(YaptypeTheme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct OrangeButton: View {
    let title: String
    var symbol: String?
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let symbol {
                    Image(systemName: symbol)
                }
                Text(title)
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(YaptypeTheme.orange, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct GhostButton: View {
    let title: String
    var symbol: String?
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let symbol {
                    Image(systemName: symbol)
                }
                Text(title)
            }
            .font(.system(size: 13))
            .foregroundStyle(YaptypeTheme.ink)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule().stroke(YaptypeTheme.line, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct StatusDot: View {
    var ok: Bool
    var label: String

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(ok ? YaptypeTheme.green : Color.orange)
                .frame(width: 7, height: 7)
            Text(label)
                .foregroundStyle(ok ? YaptypeTheme.green : YaptypeTheme.muted)
        }
        .font(.system(size: 12))
    }
}

struct SettingsRow<Trailing: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundStyle(YaptypeTheme.ink)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(YaptypeTheme.muted)
                }
            }
            Spacer()
            trailing
        }
        .padding(.vertical, 10)
    }
}
