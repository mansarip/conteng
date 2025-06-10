//
//  AppDelegate.swift
//  Conteng
//
//  Created by Luqman on 11/06/2025.
//

import Cocoa
import SwiftUI
import HotKey // pastikan dah tambah package HotKey

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var window: NSWindow?
    var isOverlayVisible: Bool = false
    var hotKey: HotKey?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 1. Create status bar icon
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "pencil.tip", accessibilityDescription: nil)
        }
        statusItem.menu = makeMenu()

        // 2. Register Option+Tab as toggle
        hotKey = HotKey(key: .tab, modifiers: [.option])
        hotKey?.keyDownHandler = { [weak self] in
            self?.toggleOverlay()
        }
    }

    // MARK: - Status Menu
    func makeMenu() -> NSMenu {
        let menu = NSMenu()

        menu.addItem(withTitle: "Undo", action: #selector(undoStroke), keyEquivalent: "")
        menu.addItem(withTitle: "Clear", action: #selector(clearAll), keyEquivalent: "")

        let widthMenu = NSMenu(title: "Stroke Width")
        for width in [2, 4, 6, 8, 10] {
            let item = NSMenuItem(title: "\(width) px", action: #selector(setStrokeWidth(_:)), keyEquivalent: "")
            item.representedObject = width
            item.target = self
            widthMenu.addItem(item)
        }
        let widthItem = NSMenuItem(title: "Stroke Width", action: nil, keyEquivalent: "")
        widthItem.submenu = widthMenu
        menu.addItem(widthItem)

        let colorMenu = NSMenu(title: "Color")
        let colors: [(String, NSColor)] = [
            ("Red", .red), ("Blue", .blue), ("Green", .green), ("Black", .black)
        ]
        for (name, color) in colors {
            let item = NSMenuItem(title: name, action: #selector(setStrokeColor(_:)), keyEquivalent: "")
            item.representedObject = color
            item.target = self
            colorMenu.addItem(item)
        }
        let colorItem = NSMenuItem(title: "Color", action: nil, keyEquivalent: "")
        colorItem.submenu = colorMenu
        menu.addItem(colorItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Quit", action: #selector(quitApp), keyEquivalent: "")

        return menu
    }

    // MARK: - Overlay logic
    func toggleOverlay() {
        if isOverlayVisible {
            window?.orderOut(nil)
            isOverlayVisible = false
        } else {
            if window == nil {
                let screenRect = NSScreen.main!.visibleFrame
                let hostingView = NSHostingView(rootView: ContentView())
                window = NSWindow(
                    contentRect: screenRect,
                    styleMask: .borderless,
                    backing: .buffered,
                    defer: false)
                window?.level = .mainMenu + 1
                window?.isOpaque = false
                window?.backgroundColor = .clear
                window?.ignoresMouseEvents = false
                window?.hasShadow = false
                window?.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
                window?.contentView = hostingView
            }
            window?.makeKeyAndOrderFront(nil)
            isOverlayVisible = true
        }
    }

    // MARK: - Menu Actions

    @objc func undoStroke() {
        NotificationCenter.default.post(name: .menuUndo, object: nil)
    }

    @objc func clearAll() {
        NotificationCenter.default.post(name: .menuClear, object: nil)
    }

    @objc func setStrokeWidth(_ sender: NSMenuItem) {
        if let width = sender.representedObject as? Int {
            NotificationCenter.default.post(name: .menuSetWidth, object: width)
        }
    }

    @objc func setStrokeColor(_ sender: NSMenuItem) {
        if let color = sender.representedObject as? NSColor {
            NotificationCenter.default.post(name: .menuSetColor, object: color)
        }
    }

    @objc func quitApp() {
        NSApp.terminate(nil)
    }
}

