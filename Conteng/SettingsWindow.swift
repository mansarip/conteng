import SwiftUI

struct SettingsWindow: View {
    @ObservedObject var preferences: GlobalShortcutPreferences

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Global Shortcut")
                .font(.title2)
                .bold()

            Text("Choose the shortcut used to start and stop drawing.")
                .foregroundColor(.secondary)

            Picker("Key", selection: keyBinding) {
                ForEach(GlobalShortcutKey.allCases) { key in
                    Text(key.name).tag(key)
                }
            }
            .pickerStyle(MenuPickerStyle())

            HStack(spacing: 18) {
                modifierToggle("⌃ Control", modifier: .control)
                modifierToggle("⌥ Option", modifier: .option)
                modifierToggle("⇧ Shift", modifier: .shift)
                modifierToggle("⌘ Command", modifier: .command)
            }

            HStack {
                Text("Current shortcut:")
                    .foregroundColor(.secondary)
                Text(preferences.shortcut.displayName)
                    .font(.system(.body, design: .monospaced))
                    .bold()

                Spacer()

                Button("Reset to ⌥Tab") {
                    preferences.reset()
                }
            }

            Text("At least one modifier key is required. Changes take effect immediately.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(24)
        .frame(width: 520, height: 245)
    }

    private var keyBinding: Binding<GlobalShortcutKey> {
        Binding(
            get: { preferences.shortcut.key },
            set: { preferences.setKey($0) }
        )
    }

    private func modifierToggle(
        _ title: String,
        modifier: GlobalShortcutModifiers
    ) -> some View {
        Toggle(
            title,
            isOn: Binding(
                get: { preferences.shortcut.modifiers.contains(modifier) },
                set: { preferences.setModifier(modifier, enabled: $0) }
            )
        )
        .toggleStyle(CheckboxToggleStyle())
    }
}
