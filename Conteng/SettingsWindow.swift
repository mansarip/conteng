import SwiftUI

struct SettingsWindow: View {
    @ObservedObject var shortcutPreferences: GlobalShortcutPreferences
    @ObservedObject var drawingPreferences: DrawingPreferences

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                sectionHeader("Global Shortcut", symbol: "keyboard")

                card {
                    HStack(spacing: 6) {
                        ForEach(shortcutKeyCaps, id: \.self) { keyCap($0) }

                        Spacer(minLength: 8)

                        Button("Reset") {
                            shortcutPreferences.reset()
                        }
                        .controlSize(.small)
                        .disabled(shortcutPreferences.shortcut == GlobalShortcutPreferences.defaultShortcut)
                        .help("Reset to \(GlobalShortcutPreferences.defaultShortcut.displayName)")
                    }

                    Divider()

                    HStack(spacing: 6) {
                        modifierButton("\u{2303}", name: "Control", modifier: .control)
                        modifierButton("\u{2325}", name: "Option", modifier: .option)
                        modifierButton("\u{21E7}", name: "Shift", modifier: .shift)
                        modifierButton("\u{2318}", name: "Command", modifier: .command)

                        Spacer(minLength: 8)

                        Picker("Key", selection: keyBinding) {
                            ForEach(GlobalShortcutKey.allCases) { key in
                                Text(key.name).tag(key)
                            }
                        }
                        .labelsHidden()
                        .controlSize(.small)
                        .frame(width: 80)
                    }
                }

                Text("At least one modifier key is required.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                sectionHeader("Drawing", symbol: "paintbrush.fill")

                card {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Clear after stop drawing")
                            Text("Erase every stroke when the overlay is hidden.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer(minLength: 0)

                        Toggle("Clear after stop drawing", isOn: clearsAfterStopBinding)
                            .labelsHidden()
                            .toggleStyle(SwitchToggleStyle())
                            .controlSize(.small)
                    }
                }
            }
        }
        .padding(16)
        .frame(width: 360, alignment: .topLeading)
    }

    // MARK: - Bindings

    private var keyBinding: Binding<GlobalShortcutKey> {
        Binding(
            get: { shortcutPreferences.shortcut.key },
            set: { shortcutPreferences.setKey($0) }
        )
    }

    private var clearsAfterStopBinding: Binding<Bool> {
        Binding(
            get: { drawingPreferences.clearsAfterStopDrawing },
            set: { drawingPreferences.setClearsAfterStopDrawing($0) }
        )
    }

    private var shortcutKeyCaps: [String] {
        let shortcut = shortcutPreferences.shortcut
        return shortcut.modifiers.symbols.map(String.init) + [shortcut.key.name]
    }

    // MARK: - Building blocks

    private func sectionHeader(_ title: String, symbol: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .semibold))
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundColor(.secondary)
        .padding(.leading, 2)
    }

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            content()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
    }

    private func keyCap(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .lineLimit(1)
            .fixedSize()
            .frame(minWidth: 16)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.primary.opacity(0.07))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color.primary.opacity(0.12), lineWidth: 1)
            )
    }

    private func modifierButton(
        _ symbol: String,
        name: String,
        modifier: GlobalShortcutModifiers
    ) -> some View {
        let isEnabled = shortcutPreferences.shortcut.modifiers.contains(modifier)

        return Button {
            shortcutPreferences.setModifier(modifier, enabled: !isEnabled)
        } label: {
            Text(symbol)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 30, height: 22)
                .foregroundColor(isEnabled ? .white : .primary)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isEnabled ? Color.accentColor : Color.primary.opacity(0.07))
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .help(name)
        .accessibilityLabel(name)
        .accessibilityAddTraits(isEnabled ? .isSelected : [])
    }
}
