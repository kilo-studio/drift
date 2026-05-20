import SwiftUI

/// Shared row primitives used by `SettingsView` and any settings-detail page
/// (e.g. `NotificationsView`). Free functions / value views — no view state —
/// so they compose cleanly without ownership concerns.
///
/// Visual contract: rows are edge-flush (no vertical padding) so the parent
/// `driftCard`'s 20pt outer padding handles the top/bottom spacing without
/// doubling up. Inter-row breathing comes from `SettingsDivider`'s 10pt
/// padding, not from the rows themselves.

/// Card container for a group of settings rows. Just `.driftCard()` with a
/// `VStack(spacing: 0)` to keep dividers edge-flush.
struct SettingsCard<Content: View>: View {
    @ViewBuilder let content: () -> Content
    var body: some View {
        VStack(spacing: 0) {
            content()
        }
        .driftCard()
    }
}

/// Hairline between rows. Carries its own vertical padding so each row stays
/// edge-flush — that way the card's 20pt outer padding doesn't double up
/// against per-row padding at the top/bottom.
struct SettingsDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.driftInkFade.opacity(0.15))
            .frame(height: 0.5)
            .padding(.vertical, 10)
    }
}

/// Toggle row: label + description on the leading edge, native `Toggle` trailing.
struct SettingsToggleRow: View {
    let label: String
    let description: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.driftRowLabel)
                    .foregroundStyle(.driftInk)
                Text(description)
                    .font(.driftRowDescription)
                    .foregroundStyle(.driftInkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(.driftSageDeep)
        }
    }
}

/// Picker row: label + description on the leading edge stay static, while only
/// the trailing value + chevron are the `Menu`'s tap target. This keeps the
/// row label visible when the menu is open (a whole-row Menu would dim the
/// label as part of its highlight, which reads as the row "disappearing").
struct SettingsPickerRow<T: Hashable>: View {
    let label: String
    let description: String
    @Binding var selection: T
    let options: [T]
    let formatted: (T) -> String

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.driftRowLabel)
                    .foregroundStyle(.driftInk)
                Text(description)
                    .font(.driftRowDescription)
                    .foregroundStyle(.driftInkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Menu {
                Picker("", selection: $selection) {
                    ForEach(options, id: \.self) { opt in
                        Text(formatted(opt)).tag(opt)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(formatted(selection))
                        .font(.driftRowLabel)
                        .foregroundStyle(.driftInkSoft)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.driftInkFade)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 8)
                .contentShape(Rectangle())
            }
        }
    }
}

/// Row that pushes a level deeper in the navigation stack — label + description
/// on the leading edge, trailing chevron-right. Wrap in a `NavigationLink` at
/// the call site (this is just the visual; the link is the parent so the whole
/// row is the tap target).
struct SettingsNavRow: View {
    let label: String
    let description: String

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.driftRowLabel)
                    .foregroundStyle(.driftInk)
                Text(description)
                    .font(.driftRowDescription)
                    .foregroundStyle(.driftInkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.driftInkFade)
        }
        .contentShape(Rectangle())
    }
}

/// Static label/value row (used for "version", etc.).
struct SettingsInfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.driftRowLabel)
                .foregroundStyle(.driftInk)
            Spacer()
            Text(value)
                .font(.driftRowLabel)
                .foregroundStyle(.driftInkSoft)
        }
    }
}

/// External link row — opens `url` in Safari, trailing arrow.up.right glyph.
struct SettingsLinkRow: View {
    let label: String
    let url: URL

    var body: some View {
        Link(destination: url) {
            HStack {
                Text(label)
                    .font(.driftRowLabel)
                    .foregroundStyle(.driftInk)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.driftInkFade)
            }
            .contentShape(Rectangle())
        }
    }
}
