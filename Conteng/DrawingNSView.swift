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
    var strokeWidth: CGFloat = 3.0
    var strokeColor: NSColor = .red

    // MARK: - Mouse Events

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        currentStroke = Stroke(points: [point], width: strokeWidth, color: strokeColor)
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        currentStroke?.points.append(point)
        needsDisplay = true
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
        // Lukis semua stroke lama
        for stroke in strokes {
            drawSmoothPath(stroke)
        }
        // Lukis currentStroke (real-time)
        if let stroke = currentStroke {
            drawSmoothPath(stroke)
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
        for width in [2, 4, 6, 8, 10] {
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

        return menu
    }

    // MARK: - Actions

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
