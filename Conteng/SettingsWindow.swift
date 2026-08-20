import SwiftUI
import UniformTypeIdentifiers

struct SettingsWindow: View {
    @ObservedObject var shortcutPreferences: GlobalShortcutPreferences
    @ObservedObject var drawingPreferences: DrawingPreferences

    @State private var dropTargetTool: DrawingTool?

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
                HStack(spacing: 0) {
                    sectionHeader("Toolbar Order", symbol: "slider.horizontal.3")

                    Spacer(minLength: 8)

                    linkButton(
                        "Reset",
                        isEnabled: !isDefaultToolOrder,
                        help: "Restore the original tool order"
                    ) {
                        drawingPreferences.resetToolOrder()
                    }
                }

                card(spacing: 2) {
                    ForEach(Array(drawingPreferences.toolOrder.enumerated()), id: \.element) { position, tool in
                        toolRow(tool, at: position)
                    }
                }

                Text("Drag a tool or use the arrows. Number keys follow this order.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    sectionHeader("Colors", symbol: "paintpalette.fill")

                    Spacer(minLength: 8)

                    linkButton(
                        "Add",
                        isEnabled: drawingPreferences.canAddColor,
                        help: "Add a color to the palette"
                    ) {
                        drawingPreferences.addSuggestedColor()
                    }

                    linkButton(
                        "Reset",
                        isEnabled: !isDefaultPalette,
                        help: "Restore the original colors"
                    ) {
                        drawingPreferences.resetColorPalette()
                    }
                }

                card(spacing: 6) {
                    LazyVGrid(
                        columns: Array(
                            repeating: GridItem(.flexible(), spacing: 6),
                            count: 4
                        ),
                        alignment: .leading,
                        spacing: 6
                    ) {
                        ForEach(drawingPreferences.colorPalette.indices, id: \.self) { index in
                            colorCell(at: index)
                        }
                    }
                }

                Text(paletteCaption)
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

    private var isDefaultToolOrder: Bool {
        drawingPreferences.toolOrder == DrawingPreferences.defaultToolOrder
    }

    private var paletteCaption: String {
        guard drawingPreferences.canAddColor else {
            return "The palette is full at \(DrawingPreferences.maximumPaletteColors) colors."
        }

        return "Click a swatch to change it. R cycles through them while drawing."
    }

    private var isDefaultPalette: Bool {
        drawingPreferences.colorPalette == DrawingPreferences.defaultColorPalette
    }

    private func paletteBinding(at index: Int) -> Binding<Color> {
        Binding(
            get: {
                guard drawingPreferences.colorPalette.indices.contains(index) else { return .clear }
                return Color(drawingPreferences.colorPalette[index].nsColor)
            },
            set: { newColor in
                guard let nsColor = Self.nsColor(from: newColor) else { return }
                drawingPreferences.replaceColor(at: index, with: StrokeColor(nsColor: nsColor))
            }
        )
    }

    private static func nsColor(from color: Color) -> NSColor? {
        if #available(macOS 12.0, *) {
            return NSColor(color)
        }

        return color.cgColor.flatMap(NSColor.init(cgColor:))
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

    private func card<Content: View>(
        spacing: CGFloat = 8,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: spacing) {
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

    private func colorCell(at index: Int) -> some View {
        HStack(spacing: 2) {
            ColorPicker("", selection: paletteBinding(at: index), supportsOpacity: false)
                .labelsHidden()
                .controlSize(.mini)
                .help(drawingPreferences.colorPalette[index].name)

            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    drawingPreferences.removeColor(at: index)
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.secondary)
                    .frame(width: 14, height: 14)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(!drawingPreferences.canRemoveColor)
            .opacity(drawingPreferences.canRemoveColor ? 1 : 0.3)
            .help("Remove this color")
            .accessibilityLabel("Remove \(drawingPreferences.colorPalette[index].name)")
        }
    }

    private func linkButton(
        _ title: String,
        isEnabled: Bool,
        help: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(title) {
            withAnimation(.easeInOut(duration: 0.18)) {
                action()
            }
        }
        .buttonStyle(PlainButtonStyle())
        .font(.system(size: 11, weight: .semibold))
        .foregroundColor(isEnabled ? .accentColor : .secondary)
        .disabled(!isEnabled)
        .help(help)
    }

    private func toolRow(_ tool: DrawingTool, at position: Int) -> some View {
        HStack(spacing: 8) {
            Text(drawingPreferences.keyboardShortcut(for: tool) ?? "–")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(.secondary)
                .frame(width: 16, height: 16)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.primary.opacity(0.07))
                )

            Image(systemName: tool.symbolName)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 16)

            Text(tool.name)
                .font(.system(size: 12))

            Spacer(minLength: 8)

            moveButton(
                "chevron.up",
                tool: tool,
                destination: position - 1,
                isEnabled: position > 0,
                label: "Move \(tool.name) earlier"
            )
            moveButton(
                "chevron.down",
                tool: tool,
                destination: position + 1,
                isEnabled: position < drawingPreferences.toolOrder.count - 1,
                label: "Move \(tool.name) later"
            )

            Image(systemName: "line.horizontal.3")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(NSColor.windowBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.accentColor.opacity(dropTargetTool == tool ? 0.22 : 0))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(
                    dropTargetTool == tool ? Color.accentColor : Color.primary.opacity(0.08),
                    lineWidth: 1
                )
        )
        .contentShape(Rectangle())
        .onDrag { NSItemProvider(object: tool.rawValue as NSString) }
        .onDrop(
            of: [UTType.text],
            isTargeted: Binding(
                get: { dropTargetTool == tool },
                set: { isTargeted in
                    withAnimation(.easeOut(duration: 0.12)) {
                        dropTargetTool = isTargeted ? tool : nil
                    }
                }
            )
        ) { providers in
            dropTool(from: providers, to: position)
        }
    }

    private func moveButton(
        _ symbol: String,
        tool: DrawingTool,
        destination: Int,
        isEnabled: Bool,
        label: String
    ) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                drawingPreferences.moveTool(tool, to: destination)
            }
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 9, weight: .bold))
                .frame(width: 20, height: 18)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.primary.opacity(0.07))
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.3)
        .accessibilityLabel(label)
    }

    private func dropTool(from providers: [NSItemProvider], to destination: Int) -> Bool {
        guard let provider = providers.first else { return false }

        provider.loadObject(ofClass: NSString.self) { object, _ in
            guard let rawTool = object as? NSString,
                  let tool = DrawingTool(rawValue: rawTool as String) else { return }

            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: 0.18)) {
                    dropTargetTool = nil
                    drawingPreferences.moveTool(tool, to: destination)
                }
            }
        }

        return true
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
