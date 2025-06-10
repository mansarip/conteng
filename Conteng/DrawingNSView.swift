//
//  DrawingNSView.swift
//  Conteng
//
//  Created by Luqman on 11/06/2025.
//
import SwiftUI

// MARK: - Data Structure
struct Stroke {
    var points: [CGPoint]
    var width: CGFloat
    var color: NSColor
}

// MARK: - Main Drawing NSView
class DrawingNSView: NSView {
    var strokes: [Stroke] = []
    var currentStroke: Stroke?
    var strokeWidth: CGFloat = 5.0
    var strokeColor: NSColor = .red
    var cursorLocation: CGPoint?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        self.trackingAreas.forEach { self.removeTrackingArea($0) }
        let area = NSTrackingArea(rect: self.bounds,
                                  options: [.activeAlways, .mouseMoved, .mouseEnteredAndExited, .inVisibleRect],
                                  owner: self,
                                  userInfo: nil)
        self.addTrackingArea(area)
    }

    override func mouseMoved(with event: NSEvent) {
        cursorLocation = convert(event.locationInWindow, from: nil)
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        cursorLocation = nil
        needsDisplay = true
    }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupMenuObservers()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupMenuObservers()
    }
    
    func setupMenuObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleUndo), name: .menuUndo, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleClear), name: .menuClear, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleSetWidth(_:)), name: .menuSetWidth, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleSetColor(_:)), name: .menuSetColor, object: nil)
    }
    
    @objc func handleUndo() { undoStroke() }
    @objc func handleClear() { clearAll() }
    @objc func handleSetWidth(_ notification: Notification) {
        if let width = notification.object as? Int {
            strokeWidth = CGFloat(width)
        }
    }
    @objc func handleSetColor(_ notification: Notification) {
        if let color = notification.object as? NSColor {
            strokeColor = color
        }
    }

    // MARK: - Mouse Events

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        currentStroke = Stroke(points: [point], width: strokeWidth, color: strokeColor)
        needsDisplay = true
        cursorLocation = nil
    }

    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        currentStroke?.points.append(point)
        needsDisplay = true
        cursorLocation = nil
    }

    override func mouseUp(with event: NSEvent) {
        if let stroke = currentStroke, !stroke.points.isEmpty {
            strokes.append(stroke)
            currentStroke = nil
            needsDisplay = true
        }
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        // Lukis stroke macam biasa
        for stroke in strokes { drawSmoothPath(stroke) }
        if let stroke = currentStroke { drawSmoothPath(stroke) }

        // --- Lukis dot indicator pada cursor
        if let loc = cursorLocation {
            let dotRadius: CGFloat = strokeWidth / 2  // Size based on stroke width
            let dotRect = NSRect(x: loc.x - dotRadius, y: loc.y - dotRadius, width: dotRadius*2, height: dotRadius*2)
            let path = NSBezierPath(ovalIn: dotRect)
            strokeColor.setFill()  // Use current stroke color instead of systemRed
            path.fill()
        }
    }

    private func drawSmoothPath(_ stroke: Stroke) {
        guard stroke.points.count > 1 else { return }
        let path = NSBezierPath()
        path.move(to: stroke.points[0])

        for i in 1..<stroke.points.count {
            let prev = stroke.points[i - 1]
            let curr = stroke.points[i]
            let mid = CGPoint(x: (prev.x + curr.x) / 2, y: (prev.y + curr.y) / 2)
            path.curve(to: mid, controlPoint1: prev, controlPoint2: curr)
        }

        stroke.color.setStroke()
        path.lineWidth = stroke.width
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.stroke()
    }

    // MARK: - Context Menu

    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = NSMenu(title: "Options")

        // Undo
        let undoItem = NSMenuItem(title: "Undo", action: #selector(undoStroke), keyEquivalent: "")
        undoItem.target = self
        menu.addItem(undoItem)

        // Clear
        let clearItem = NSMenuItem(title: "Clear", action: #selector(clearAll), keyEquivalent: "")
        clearItem.target = self
        menu.addItem(clearItem)

        // Stroke Width submenu
        let widthMenu = NSMenu(title: "Stroke Width")
        for width in [2, 4, 5, 6, 7, 8, 10] {
            let item = NSMenuItem(title: "\(width) px", action: #selector(setStrokeWidth(_:)), keyEquivalent: "")
            item.representedObject = width
            item.target = self
            widthMenu.addItem(item)
        }
        let widthItem = NSMenuItem(title: "Stroke Width", action: nil, keyEquivalent: "")
        widthItem.submenu = widthMenu
        menu.addItem(widthItem)

        // Color submenu
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
        
        // --- Separator & Quit
        menu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "")
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    // MARK: - Actions
    
    @objc func quitApp() {
        NSApp.terminate(nil)
    }

    @objc func undoStroke() {
        guard !strokes.isEmpty else { return }
        _ = strokes.removeLast()
        needsDisplay = true
    }

    @objc func clearAll() {
        strokes.removeAll()
        currentStroke = nil
        needsDisplay = true
    }

    @objc func setStrokeWidth(_ sender: NSMenuItem) {
        if let width = sender.representedObject as? Int {
            strokeWidth = CGFloat(width)
        }
    }

    @objc func setStrokeColor(_ sender: NSMenuItem) {
        if let color = sender.representedObject as? NSColor {
            strokeColor = color

            // --- PAKSA UPDATE CURSOR INDICATOR SEKARANG JUGA
            if let window = self.window {
                let mouseLoc = window.mouseLocationOutsideOfEventStream
                let viewLoc = convert(mouseLoc, from: nil)
                cursorLocation = viewLoc
            }
            needsDisplay = true
        }
    }
}

// MARK: - SwiftUI Representable

struct DrawingView: NSViewRepresentable {
    func makeNSView(context: Context) -> DrawingNSView {
        DrawingNSView()
    }

    func updateNSView(_ nsView: DrawingNSView, context: Context) {
        // Nothing to update for now
    }
}
