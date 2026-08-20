import SwiftUI

struct SettingsWindow: View {
    @ObservedObject var shortcutPreferences: GlobalShortcutPreferences
    @ObservedObject var drawingPreferences: DrawingPreferences

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Global Shortcut")

            VStack(alignment: .leading, spacing: 6) {
                settingRow("Key") {
                    Picker("Key", selection: keyBinding) {
                        ForEach(GlobalShortcutKey.allCases) { key in
                            Text(key.name).tag(key)
                        }
                    }
                    .labelsHidden()
                    .controlSize(.small)
                    .frame(width: 84)
                }

                settingRow("Modifiers") {
                    HStack(spacing: 14) {
                        modifierToggle("\u{2303}", name: "Control", modifier: .control)
                        modifierToggle("\u{2325}", name: "Option", modifier: .option)
                        modifierToggle("\u{21E7}", name: "Shift", modifier: .shift)
                        modifierToggle("\u{2318}", name: "Command", modifier: .command)
                    }
                }

                settingRow("Current") {
                    HStack(spacing: 10) {
                        Text(shortcutPreferences.shortcut.displayName)
                            .font(.system(.body, design: .monospaced))
                            .bold()

                        Button("Reset") {
                            shortcutPreferences.reset()
                        }
                        .controlSize(.small)
                    }
                }
            }

            Text("At least one modifier key is required.")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.leading, 74)

            Divider()

            sectionHeader("Drawing")

            Toggle("Clear after stop drawing", isOn: clearsAfterStopBinding)
                .toggleStyle(CheckboxToggleStyle())
                .help("Erase every stroke automatically when the overlay is turned off.")
        }
        .padding(16)
        .frame(width: 360, alignment: .topLeading)
    }

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

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
    }

    private func settingRow<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .foregroundColor(.secondary)
                .frame(width: 66, alignment: .trailing)
            content()
        }
    }

    private func modifierToggle(
        _ symbol: String,
        name: String,
        modifier: GlobalShortcutModifiers
    ) -> some View {
        Toggle(
            symbol,
            isOn: Binding(
                get: { shortcutPreferences.shortcut.modifiers.contains(modifier) },
                set: { shortcutPreferences.setModifier(modifier, enabled: $0) }
            )
        )
        .toggleStyle(CheckboxToggleStyle())
        .help(name)
        .accessibilityLabel(name)
    }
}
