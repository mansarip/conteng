import SwiftUI

struct MiniToolbar: View {
    @ObservedObject var preferences: DrawingPreferences

    var body: some View {
        HStack(spacing: 6) {
            ForEach(DrawingTool.allCases) { tool in
                Button {
                    preferences.setSelectedTool(tool)
                } label: {
                    Image(systemName: tool.symbolName)
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 28, height: 28)
                        .foregroundColor(tool == preferences.selectedTool ? .white : .primary)
                        .background(
                            RoundedRectangle(cornerRadius: 7)
                                .fill(tool == preferences.selectedTool ? Color.accentColor : Color.clear)
                        )
                }
                .buttonStyle(PlainButtonStyle())
                .help("\(tool.name) (\(tool.keyboardShortcut))")
                .accessibilityLabel(tool.name)
            }

            toolbarDivider

            ForEach(StrokeColor.allCases) { color in
                Button {
                    preferences.setStrokeColor(color)
                } label: {
                    Circle()
                        .fill(Color(color.nsColor))
                        .frame(width: 18, height: 18)
                        .overlay(
                            Circle()
                                .stroke(
                                    color == preferences.strokeColor
                                        ? Color.primary
                                        : Color.secondary.opacity(0.45),
                                    lineWidth: color == preferences.strokeColor ? 2 : 1
                                )
                                .padding(-3)
                        )
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(PlainButtonStyle())
                .help(color.name)
                .accessibilityLabel(color.name)
            }

            toolbarDivider

            Button {
                preferences.decreaseStrokeWidth()
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 28, height: 28)
                    .background(Color.primary.opacity(0.001))
                    .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            .contentShape(Rectangle())
            .disabled(!preferences.canDecreaseStrokeWidth)
            .opacity(preferences.canDecreaseStrokeWidth ? 1 : 0.35)
            .help("Decrease width (W)")
            .accessibilityLabel("Decrease stroke width")

            Text("\(Int(preferences.strokeWidth))")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .frame(minWidth: 18)
                .accessibilityLabel("Stroke width \(Int(preferences.strokeWidth)) pixels")

            Button {
                preferences.increaseStrokeWidth()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 28, height: 28)
                    .background(Color.primary.opacity(0.001))
                    .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            .contentShape(Rectangle())
            .disabled(!preferences.canIncreaseStrokeWidth)
            .opacity(preferences.canIncreaseStrokeWidth ? 1 : 0.35)
            .help("Increase width (E)")
            .accessibilityLabel("Increase stroke width")
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.windowBackgroundColor).opacity(0.96))
                .shadow(color: Color.black.opacity(0.28), radius: 8, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
        )
    }

    private var toolbarDivider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.18))
            .frame(width: 1, height: 22)
            .padding(.horizontal, 3)
    }
}
