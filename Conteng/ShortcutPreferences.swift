import AppKit
import Combine
import HotKey

enum GlobalShortcutKey: String, CaseIterable, Identifiable {
    case tab
    case space
    case a, b, c, d, e, f, g, h, i, j, k, l, m
    case n, o, p, q, r, s, t, u, v, w, x, y, z
    case zero = "0"
    case one = "1"
    case two = "2"
    case three = "3"
    case four = "4"
    case five = "5"
    case six = "6"
    case seven = "7"
    case eight = "8"
    case nine = "9"
    case grave

    var id: String { rawValue }

    var name: String {
        switch self {
        case .tab: "Tab"
        case .space: "Space"
        case .grave: "`"
        default: rawValue.uppercased()
        }
    }

    var hotKey: Key {
        Key(string: rawValue) ?? .tab
    }

    var menuKeyEquivalent: String {
        switch self {
        case .tab: "\t"
        case .space: " "
        case .grave: "`"
        default: rawValue
        }
    }
}

struct GlobalShortcutModifiers: OptionSet, Equatable {
    let rawValue: Int

    static let command = GlobalShortcutModifiers(rawValue: 1 << 0)
    static let option = GlobalShortcutModifiers(rawValue: 1 << 1)
    static let control = GlobalShortcutModifiers(rawValue: 1 << 2)
    static let shift = GlobalShortcutModifiers(rawValue: 1 << 3)

    var eventModifiers: NSEvent.ModifierFlags {
        var modifiers: NSEvent.ModifierFlags = []
        if contains(.command) { modifiers.insert(.command) }
        if contains(.option) { modifiers.insert(.option) }
        if contains(.control) { modifiers.insert(.control) }
        if contains(.shift) { modifiers.insert(.shift) }
        return modifiers
    }

    var symbols: String {
        var result = ""
        if contains(.control) { result += "⌃" }
        if contains(.option) { result += "⌥" }
        if contains(.shift) { result += "⇧" }
        if contains(.command) { result += "⌘" }
        return result
    }
}

struct GlobalShortcut: Equatable {
    var key: GlobalShortcutKey
    var modifiers: GlobalShortcutModifiers

    var displayName: String {
        "\(modifiers.symbols)\(key.name)"
    }
}

final class GlobalShortcutPreferences: ObservableObject {
    static let shared = GlobalShortcutPreferences()
    static let defaultShortcut = GlobalShortcut(key: .tab, modifiers: .option)

    private enum DefaultsKey {
        static let key = "shortcut.key"
        static let modifiers = "shortcut.modifiers"
    }

    private let defaults: UserDefaults
    @Published private(set) var shortcut: GlobalShortcut

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let storedKey = defaults.string(forKey: DefaultsKey.key).flatMap(GlobalShortcutKey.init(rawValue:))
        let storedModifiers = GlobalShortcutModifiers(
            rawValue: defaults.integer(forKey: DefaultsKey.modifiers)
        )

        if let storedKey, !storedModifiers.isEmpty {
            shortcut = GlobalShortcut(key: storedKey, modifiers: storedModifiers)
        } else {
            shortcut = Self.defaultShortcut
        }
    }

    func setKey(_ key: GlobalShortcutKey) {
        setShortcut(GlobalShortcut(key: key, modifiers: shortcut.modifiers))
    }

    func setModifiers(_ modifiers: GlobalShortcutModifiers) {
        guard !modifiers.isEmpty else { return }
        setShortcut(GlobalShortcut(key: shortcut.key, modifiers: modifiers))
    }

    func setModifier(_ modifier: GlobalShortcutModifiers, enabled: Bool) {
        var modifiers = shortcut.modifiers
        if enabled {
            modifiers.insert(modifier)
        } else {
            modifiers.remove(modifier)
        }
        setModifiers(modifiers)
    }

    func reset() {
        setShortcut(Self.defaultShortcut)
    }

    private func setShortcut(_ newShortcut: GlobalShortcut) {
        guard newShortcut != shortcut, !newShortcut.modifiers.isEmpty else { return }
        shortcut = newShortcut
        defaults.set(newShortcut.key.rawValue, forKey: DefaultsKey.key)
        defaults.set(newShortcut.modifiers.rawValue, forKey: DefaultsKey.modifiers)
        NotificationCenter.default.post(name: .globalShortcutDidChange, object: self)
    }
}
