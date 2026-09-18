import AppKit
import SwiftUI

struct MacPopupButton<Value: Hashable>: View {
    @Binding var selection: Value
    var options: [(value: Value, title: String)]
    var placeholder: String? = nil
    var isEnabled: ((Value) -> Bool)? = nil
    var onSelect: ((Value) -> Void)? = nil
    @State private var open = false

    var body: some View {
        Button {
            guard !options.isEmpty else { return }
            open.toggle()
        } label: {
            HStack(spacing: 8) {
                Text(currentTitle)
                    .foregroundStyle(showsPlaceholder ? YaptypeTheme.muted : YaptypeTheme.ink)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(YaptypeTheme.muted)
            }
            .font(.system(size: 13))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity, minHeight: 24, alignment: .leading)
            .background(YaptypeTheme.canvas, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(YaptypeTheme.line, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(options.isEmpty)
        .popover(isPresented: $open, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(options, id: \.value) { option in
                    let enabled = optionEnabled(option.value)
                    Button {
                        guard enabled else { return }
                        selection = option.value
                        open = false
                        onSelect?(option.value)
                    } label: {
                        HStack(spacing: 8) {
                            Text(option.title)
                                .foregroundStyle(enabled ? YaptypeTheme.ink : YaptypeTheme.muted)
                            Spacer(minLength: 12)
                            if enabled, option.value == selection {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(YaptypeTheme.orange)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!enabled)
                }
            }
            .padding(6)
            .frame(minWidth: 180)
        }
    }

    private var showsPlaceholder: Bool {
        guard placeholder != nil else { return options.isEmpty }
        return !optionEnabled(selection) || !options.contains(where: { $0.value == selection })
    }

    private var currentTitle: String {
        if showsPlaceholder {
            return placeholder ?? "None available"
        }
        if options.isEmpty { return "None available" }
        return options.first { $0.value == selection }?.title ?? options[0].title
    }

    private func optionEnabled(_ value: Value) -> Bool {
        isEnabled?(value) ?? true
    }
}
