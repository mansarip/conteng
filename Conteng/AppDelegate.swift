import Cocoa
import HotKey
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var overlayWindows: [CanvasID: OverlayWindow] = [:]
    private var isOverlayVisible = false
    private var hotKey: HotKey?
    private var aboutWindow: NSWindow?
    private var guidesWindow: NSWindow?

    private let drawingDocument = DrawingDocument()
    private let drawingPreferences = DrawingPreferences.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureStatusItem()
        registerObservers()

        hotKey = HotKey(key: .tab, modifiers: [.option])
        hotKey?.keyDownHandler = { [weak self] in
            self?.toggleOverlay()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        NotificationCenter.default.removeObserver(self)
    }

    private func configureStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            if let image = NSImage(
                systemSymbolName: "paintbrush.fill",
                accessibilityDescription: "Conteng"
            ) {
                button.image = image
                button.image?.isTemplate = true
            } else {
                button.image = NSImage(named: "StatusBarIcon")
                button.image?.isTemplate = true
            }
        }

        statusItem.menu = makeMenu()
    }

    private func registerObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(scheduleMenuRefresh),
            name: .drawingDocumentDidChange,
            object: drawingDocument
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(scheduleMenuRefresh),
            name: .drawingPreferencesDidChange,
            object: drawingPreferences
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    // MARK: - Status menu

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()

        let drawItem = NSMenuItem(
            title: isOverlayVisible ? "Stop Drawing" : "Start Drawing",
            action: #selector(toggleOverlayFromMenu),
            keyEquivalent: "\t"
        )
        drawItem.keyEquivalentModifierMask = [.option]
        drawItem.target = self
        menu.addItem(drawItem)

        menu.addItem(NSMenuItem.separator())

        let undoItem = NSMenuItem(title: "Undo", action: #selector(undoStroke), keyEquivalent: "z")
        undoItem.keyEquivalentModifierMask = [.command]
        undoItem.target = self
        undoItem.isEnabled = drawingDocument.canUndo
        menu.addItem(undoItem)

        let redoItem = NSMenuItem(title: "Redo", action: #selector(redoStroke), keyEquivalent: "z")
        redoItem.keyEquivalentModifierMask = [.command, .shift]
        redoItem.target = self
        redoItem.isEnabled = drawingDocument.canRedo
        menu.addItem(redoItem)

        let clearItem = NSMenuItem(title: "Clear", action: #selector(clearAll), keyEquivalent: "\u{001B}")
        clearItem.target = self
        clearItem.isEnabled = !drawingDocument.isEmpty
        menu.addItem(clearItem)

        menu.addItem(makeWidthMenuItem())
        menu.addItem(makeColorMenuItem())

        menu.addItem(NSMenuItem.separator())
        let guidesItem = NSMenuItem(title: "Guides", action: #selector(showGuides), keyEquivalent: "")
        guidesItem.target = self
        menu.addItem(guidesItem)

        let aboutItem = NSMenuItem(title: "About", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.keyEquivalentModifierMask = [.command]
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    private func makeWidthMenuItem() -> NSMenuItem {
        let widthMenu = NSMenu(title: "Stroke Width")

        for width in DrawingPreferences.availableWidths {
            let item = NSMenuItem(
                title: "\(Int(width)) px",
                action: #selector(setStrokeWidth(_:)),
                keyEquivalent: ""
            )
            item.representedObject = NSNumber(value: Double(width))
            item.state = width == drawingPreferences.strokeWidth ? .on : .off
            item.target = self
            widthMenu.addItem(item)
        }

        let widthItem = NSMenuItem(title: "Stroke Width", action: nil, keyEquivalent: "")
        widthItem.submenu = widthMenu
        return widthItem
    }

    private func makeColorMenuItem() -> NSMenuItem {
        let colorMenu = NSMenu(title: "Color")

        for color in StrokeColor.allCases {
            let item = NSMenuItem(
                title: color.name,
                action: #selector(setStrokeColor(_:)),
                keyEquivalent: ""
            )
            item.representedObject = color.rawValue
            item.state = color == drawingPreferences.strokeColor ? .on : .off
            item.target = self
            colorMenu.addItem(item)
        }

        let colorItem = NSMenuItem(title: "Color", action: nil, keyEquivalent: "")
        colorItem.submenu = colorMenu
        return colorItem
    }

    @objc private func scheduleMenuRefresh() {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.statusItem != nil else { return }
            self.statusItem.menu = self.makeMenu()
        }
    }

    // MARK: - Overlay windows

    private func toggleOverlay() {
        if isOverlayVisible {
            overlayWindows.values.forEach { $0.orderOut(nil) }
            isOverlayVisible = false
        } else {
            synchronizeOverlayWindows()
            showOverlayWindows()
            isOverlayVisible = true
        }

        statusItem.menu = makeMenu()
    }

    private func synchronizeOverlayWindows() {
        var connectedDisplays = Set<CanvasID>()

        for screen in NSScreen.screens {
            guard let canvasID = displayID(for: screen) else { continue }
            connectedDisplays.insert(canvasID)

            if let window = overlayWindows[canvasID] {
                window.setFrame(screen.visibleFrame, display: false)
                continue
            }

            let contentView = NSHostingView(
                rootView: ContentView(
                    document: drawingDocument,
                    preferences: drawingPreferences,
                    canvasID: canvasID
                )
            )
            let window = OverlayWindow(contentRect: screen.visibleFrame, contentView: contentView)
            overlayWindows[canvasID] = window
        }

        let disconnectedDisplays = overlayWindows.keys.filter { !connectedDisplays.contains($0) }
        for canvasID in disconnectedDisplays {
            overlayWindows[canvasID]?.orderOut(nil)
            overlayWindows.removeValue(forKey: canvasID)
        }
    }

    private func showOverlayWindows() {
        let activeCanvasID = screenUnderPointer().flatMap(displayID(for:))

        for (canvasID, window) in overlayWindows where canvasID != activeCanvasID {
            window.orderFront(nil)
        }

        if let activeCanvasID, let activeWindow = overlayWindows[activeCanvasID] {
            activeWindow.makeKeyAndOrderFront(nil)
        } else {
            overlayWindows.values.first?.makeKeyAndOrderFront(nil)
        }
    }

    private func screenUnderPointer() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouseLocation, $0.frame, false) }
    }

    private func displayID(for screen: NSScreen) -> CanvasID? {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        return (screen.deviceDescription[key] as? NSNumber)?.uint32Value
    }

    @objc private func screenParametersDidChange() {
        guard isOverlayVisible else { return }
        synchronizeOverlayWindows()
        showOverlayWindows()
    }

    // MARK: - Menu actions

    @objc private func toggleOverlayFromMenu() {
        toggleOverlay()
    }

    @objc private func undoStroke() {
        drawingDocument.undo()
    }

    @objc private func redoStroke() {
        drawingDocument.redo()
    }

    @objc private func clearAll() {
        drawingDocument.clear()
    }

    @objc private func setStrokeWidth(_ sender: NSMenuItem) {
        guard let width = sender.representedObject as? NSNumber else { return }
        drawingPreferences.setStrokeWidth(CGFloat(width.doubleValue))
    }

    @objc private func setStrokeColor(_ sender: NSMenuItem) {
        guard let rawColor = sender.representedObject as? String,
              let color = StrokeColor(rawValue: rawColor) else { return }
        drawingPreferences.setStrokeColor(color)
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    @objc private func showGuides() {
        if guidesWindow == nil {
            let content = NSHostingView(rootView: GuidesWindow())
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 450, height: 500),
                styleMask: [.titled, .closable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.center()
            window.contentView = content
            window.title = "Guides"
            window.isReleasedWhenClosed = false
            window.minSize = NSSize(width: 400, height: 450)
            guidesWindow = window
        }

        guidesWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func showAbout() {
        if aboutWindow == nil {
            let content = NSHostingView(rootView: AboutWindow())
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 320, height: 280),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.center()
            window.contentView = content
            window.title = "About"
            window.isReleasedWhenClosed = false
            aboutWindow = window
        }

        aboutWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
