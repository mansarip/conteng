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
    var startPoint: CGPoint?
    var isDrawingStraightLine: Bool = false

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
        setupKeyboardShortcuts()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupMenuObservers()
        setupKeyboardShortcuts()
    }

    func setupKeyboardShortcuts() {
        // Remove any existing monitor first to avoid duplicates
        if let existingMonitor = self.localEventMonitor {
            NSEvent.removeMonitor(existingMonitor)
            self.localEventMonitor = nil
        }
        
        self.localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            
            // Check for Escape key
            if event.keyCode == 53 { // ESC key
                self.clearAll()
                return nil // Event handled
            }
            
            // Check for CMD+Z (Undo)
            if event.modifierFlags.contains(.command) && 
            event.charactersIgnoringModifiers?.lowercased() == "z" {
                self.undoStroke()
                return nil // Event handled
            }
            
            // Check for other shortcut keys without requiring window focus
            if let keyChar = event.charactersIgnoringModifiers?.lowercased().first {
                switch keyChar {
                case "w": // Decrease width
                    self.decreaseStrokeWidth()
                    return nil // Event handled
                case "e": // Increase width
                    self.increaseStrokeWidth()
                    return nil // Event handled
                case "r": // Rotate through colors
                    self.rotateColors()
                    return nil // Event handled
                default:
                    break
                }
            }
            
            return event // Not our shortcut, pass the event along
        }
    }

    func rotateColors() {
        // Define available colors in the rotation sequence
        let availableColors: [NSColor] = [.red, .blue, .green, .black]
        
        // Find the current color in the sequence
        var currentIndex = availableColors.firstIndex { $0.isClose(to: strokeColor) } ?? -1
        
        // Move to next color (or back to the beginning)
        currentIndex = (currentIndex + 1) % availableColors.count
        
        // Set the new color
        strokeColor = availableColors[currentIndex]
        
        // Update cursor indicator right away if visible
        if cursorLocation != nil {
            if let window = self.window {
                let mouseLoc = window.mouseLocationOutsideOfEventStream
                let viewLoc = convert(mouseLoc, from: nil)
                cursorLocation = viewLoc
            }
            needsDisplay = true
        }
    }

    // Add property to store the monitor
    private var localEventMonitor: Any?

    // Make sure to remove the monitor in deinit
    deinit {
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
        }
        NotificationCenter.default.removeObserver(self)
    }

    func decreaseStrokeWidth() {
        let availableWidths = [2, 4, 5, 6, 7, 8, 10]
        // Find current width or next smaller
        var newWidth: Int = 2 // Default to smallest
        
        for width in availableWidths.sorted(by: >) {
            if width < Int(strokeWidth) {
                newWidth = width
                break
            }
        }
        
        strokeWidth = CGFloat(newWidth)
        needsDisplay = true
    }

    func increaseStrokeWidth() {
        let availableWidths = [2, 4, 5, 6, 7, 8, 10]
        // Find current width or next larger
        var newWidth: Int = 10 // Default to largest
        
        for width in availableWidths.sorted() {
            if width > Int(strokeWidth) {
                newWidth = width
                break
            }
        }
        
        strokeWidth = CGFloat(newWidth)
        needsDisplay = true
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
        startPoint = point
        
        // Check if Shift is held for straight line drawing
        isDrawingStraightLine = event.modifierFlags.contains(.shift)
        
        currentStroke = Stroke(points: [point], width: strokeWidth, color: strokeColor)
        needsDisplay = true
        cursorLocation = nil
    }

    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        
        if isDrawingStraightLine, let start = startPoint {
            // For straight line, only keep start and current point
            currentStroke?.points = [start, point]
        } else {
            // Normal curve drawing
            currentStroke?.points.append(point)
        }
        
        needsDisplay = true
        cursorLocation = nil
    }

    override func mouseUp(with event: NSEvent) {
        if let stroke = currentStroke, !stroke.points.isEmpty {
            strokes.append(stroke)
            currentStroke = nil
            needsDisplay = true
        }
        
        // Reset straight line mode
        isDrawingStraightLine = false
        startPoint = nil
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        // Lukis stroke macam biasa
        for stroke in strokes { drawSmoothPath(stroke) }
        if let stroke = currentStroke { drawSmoothPath(stroke) }

        // --- Lukis dot indicator pada cursor
        if let loc = cursorLocation {
            let dotRadius: CGFloat = strokeWidth - 1  // Size based on stroke width
            let dotRect = NSRect(x: loc.x - dotRadius, y: loc.y - dotRadius, width: dotRadius*2, height: dotRadius*2)
            let path = NSBezierPath(ovalIn: dotRect)
            strokeColor.setFill()  // Use current stroke color instead of systemRed
            path.fill()
        }
    }

    private func drawSmoothPath(_ stroke: Stroke) {
        guard stroke.points.count > 1 else {
            // Handle single point case
            if stroke.points.count == 1 {
                let point = stroke.points[0]
                let dotRadius: CGFloat = stroke.width / 2
                let dotRect = NSRect(x: point.x - dotRadius, y: point.y - dotRadius, width: dotRadius*2, height: dotRadius*2)
                let path = NSBezierPath(ovalIn: dotRect)
                stroke.color.setFill()
                path.fill()
            }
            return
        }
        
        let path = NSBezierPath()
        path.move(to: stroke.points[0])

        // If it's a straight line (only 2 points), draw a straight line
        if stroke.points.count == 2 {
            path.line(to: stroke.points[1])
        } else {
            // Draw smooth curve for multiple points
            for i in 1..<stroke.points.count {
                let prev = stroke.points[i - 1]
                let curr = stroke.points[i]
                let mid = CGPoint(x: (prev.x + curr.x) / 2, y: (prev.y + curr.y) / 2)
                path.curve(to: mid, controlPoint1: prev, controlPoint2: curr)
            }
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
        let undoItem = NSMenuItem(title: "Undo (⌘Z)", action: #selector(undoStroke), keyEquivalent: "")
        undoItem.target = self
        menu.addItem(undoItem)

        // Clear
        let clearItem = NSMenuItem(title: "Clear (Esc)", action: #selector(clearAll), keyEquivalent: "")
        clearItem.target = self
        menu.addItem(clearItem)

        // Stroke Width submenu
        let widthMenu = NSMenu(title: "Stroke Width")
        let widths = [2, 4, 5, 6, 7, 8, 10]
        for width in widths {
            let item = NSMenuItem(title: "\(width) px", action: #selector(setStrokeWidth(_:)), keyEquivalent: "")
            item.representedObject = width
            item.target = self
            widthMenu.addItem(item)
        }

        widthMenu.addItem(NSMenuItem.separator())
        let decreaseItem = NSMenuItem(title: "Decrease Width (W)", action: #selector(decreaseWidthAction), keyEquivalent: "")
        decreaseItem.target = self
        widthMenu.addItem(decreaseItem)

        let increaseItem = NSMenuItem(title: "Increase Width (E)", action: #selector(increaseWidthAction), keyEquivalent: "")
        increaseItem.target = self
        widthMenu.addItem(increaseItem)

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

        // Add a color rotation option at the end of color menu
        colorMenu.addItem(NSMenuItem.separator())
        let rotateItem = NSMenuItem(title: "Rotate Colors (R)", action: #selector(rotateColorsAction), keyEquivalent: "")
        rotateItem.target = self
        colorMenu.addItem(rotateItem)

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

    @objc func decreaseWidthAction() {
        decreaseStrokeWidth()
    }

    @objc func increaseWidthAction() {
        increaseStrokeWidth()
    }

    @objc func rotateColorsAction() {
        rotateColors()
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

extension NSColor {
    func isClose(to color: NSColor) -> Bool {
        // Convert both colors to the same color space for comparison
        let c1 = self.usingColorSpace(.sRGB)!
        let c2 = color.usingColorSpace(.sRGB)!
        
        // Get the components
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        
        c1.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        c2.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        
        // Calculate the difference - colors are "close" if components are within tolerance
        let tolerance: CGFloat = 0.1
        return abs(r1 - r2) < tolerance && 
               abs(g1 - g2) < tolerance && 
               abs(b1 - b2) < tolerance
    }
}