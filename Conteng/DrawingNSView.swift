import SwiftUI

final class DrawingNSView: NSView {
    private let document: DrawingDocument
    private let preferences: DrawingPreferences
    private let canvasID: CanvasID

    private var currentStroke: Stroke?
    private var cursorLocation: CGPoint?
    private var startPoint: CGPoint?
    private var isDrawingStraightLine = false
    private var eraserStartSnapshot: DrawingDocument.Snapshot?
    private var lastEraserPoint: CGPoint?
    private var localEventMonitor: Any?

    override var acceptsFirstResponder: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    init(
        document: DrawingDocument,
        preferences: DrawingPreferences,
        canvasID: CanvasID
    ) {
        self.document = document
        self.preferences = preferences
        self.canvasID = canvasID
        super.init(frame: .zero)
        setupObservers()
        setupKeyboardShortcuts()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if let localEventMonitor {
            NSEvent.removeMonitor(localEventMonitor)
        }
        NotificationCenter.default.removeObserver(self)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(
            NSTrackingArea(
                rect: bounds,
                options: [.activeAlways, .mouseMoved, .mouseEnteredAndExited, .inVisibleRect],
                owner: self,
                userInfo: nil
            )
        )
    }

    override func mouseMoved(with event: NSEvent) {
        cursorLocation = convert(event.locationInWindow, from: nil)
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        cursorLocation = nil
        needsDisplay = true
    }

    private func setupObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDocumentChange),
            name: .drawingDocumentDidChange,
            object: document
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePreferencesChange),
            name: .drawingPreferencesDidChange,
            object: preferences
        )
    }

    private func setupKeyboardShortcuts() {
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.window?.isKeyWindow == true else { return event }

            if event.keyCode == 53 { // Escape
                self.clearAll()
                return nil
            }

            if event.modifierFlags.contains(.command),
               event.charactersIgnoringModifiers?.lowercased() == "z" {
                if event.modifierFlags.contains(.shift) {
                    self.document.redo()
                } else {
                    self.document.undo()
                }
                return nil
            }

            guard let key = event.charactersIgnoringModifiers?.lowercased().first else {
                return event
            }

            let conflictingModifiers: NSEvent.ModifierFlags = [.command, .control, .option]
            guard event.modifierFlags.intersection(conflictingModifiers).isEmpty else {
                return event
            }

            if let tool = preferences.tool(forKeyboardShortcut: key) {
                preferences.setSelectedTool(tool)
                return nil
            }

            switch key {
            case "w":
                preferences.decreaseStrokeWidth()
                return nil
            case "e":
                preferences.increaseStrokeWidth()
                return nil
            case "r":
                preferences.rotateStrokeColor()
                return nil
            default:
                return event
            }
        }
    }

    @objc private func handleDocumentChange() {
        needsDisplay = true
    }

    @objc private func handlePreferencesChange() {
        updateCursorLocation()
        needsDisplay = true
    }

    private func updateCursorLocation() {
        guard let window else { return }
        cursorLocation = convert(window.mouseLocationOutsideOfEventStream, from: nil)
    }

    // MARK: - Mouse events

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)

        let point = convert(event.locationInWindow, from: nil)
        startPoint = point
        isDrawingStraightLine = event.modifierFlags.contains(.shift) || preferences.selectedTool == .arrow

        if preferences.selectedTool == .eraser {
            eraserStartSnapshot = document.snapshot()
            lastEraserPoint = nil
            eraseThrough(point)
        } else {
            currentStroke = Stroke(
                points: [point],
                width: preferences.strokeWidth,
                color: preferences.strokeColor,
                tool: preferences.selectedTool
            )
        }
        cursorLocation = nil
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)

        if preferences.selectedTool == .eraser {
            eraseThrough(point)
        } else if isDrawingStraightLine, let startPoint {
            currentStroke?.points = [startPoint, point]
        } else if let lastPoint = currentStroke?.points.last,
                  hypot(point.x - lastPoint.x, point.y - lastPoint.y) >= 0.5 {
            currentStroke?.points.append(point)
        }

        cursorLocation = nil
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        let endPoint = convert(event.locationInWindow, from: nil)

        if preferences.selectedTool == .eraser {
            eraseThrough(endPoint)
            if let eraserStartSnapshot {
                document.commitErasure(from: eraserStartSnapshot)
            }
            self.eraserStartSnapshot = nil
            lastEraserPoint = nil
        } else if isDrawingStraightLine, let startPoint {
            currentStroke?.points = [startPoint, endPoint]
        } else if let lastPoint = currentStroke?.points.last,
                  hypot(endPoint.x - lastPoint.x, endPoint.y - lastPoint.y) >= 0.5 {
            currentStroke?.points.append(endPoint)
        }

        if let currentStroke, !currentStroke.points.isEmpty {
            self.currentStroke = nil
            document.add(currentStroke, to: canvasID)
        }

        isDrawingStraightLine = false
        startPoint = nil
        updateCursorLocation()
        needsDisplay = true
    }

    private func eraseThrough(_ point: CGPoint) {
        let radius = max(8, preferences.strokeWidth * 2)

        if let lastEraserPoint {
            let distance = hypot(point.x - lastEraserPoint.x, point.y - lastEraserPoint.y)
            let sampleSpacing = max(2, radius / 2)
            let sampleCount = max(1, Int(ceil(distance / sampleSpacing)))

            for step in 1...sampleCount {
                let progress = CGFloat(step) / CGFloat(sampleCount)
                let samplePoint = CGPoint(
                    x: lastEraserPoint.x + (point.x - lastEraserPoint.x) * progress,
                    y: lastEraserPoint.y + (point.y - lastEraserPoint.y) * progress
                )
                document.erase(at: samplePoint, radius: radius, on: canvasID)
            }
        } else {
            document.erase(at: point, radius: radius, on: canvasID)
        }

        lastEraserPoint = point
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        for stroke in document.strokes(for: canvasID) {
            draw(stroke)
        }
        if let currentStroke {
            draw(currentStroke)
        }

        if let cursorLocation {
            let radius = preferences.selectedTool == .eraser
                ? max(8, preferences.strokeWidth * 2)
                : max(1, preferences.strokeWidth / 2)
            let indicatorRect = NSRect(
                x: cursorLocation.x - radius,
                y: cursorLocation.y - radius,
                width: radius * 2,
                height: radius * 2
            )
            let indicator = NSBezierPath(ovalIn: indicatorRect)
            if preferences.selectedTool == .eraser {
                NSColor.white.withAlphaComponent(0.9).setFill()
                indicator.fill()
                NSColor.systemRed.withAlphaComponent(0.9).setStroke()
                indicator.lineWidth = 1.5
                indicator.stroke()
            } else {
                preferences.strokeColor.nsColor.setFill()
                indicator.fill()
            }
        }
    }

    private func draw(_ stroke: Stroke) {
        guard stroke.points.count > 1 else {
            if let point = stroke.points.first {
                let radius = stroke.renderedWidth / 2
                let dotRect = NSRect(
                    x: point.x - radius,
                    y: point.y - radius,
                    width: radius * 2,
                    height: radius * 2
                )
                let color = stroke.tool == .highlighter
                    ? stroke.color.nsColor.withAlphaComponent(0.32)
                    : stroke.color.nsColor
                color.setFill()
                NSBezierPath(ovalIn: dotRect).fill()
            }
            return
        }

        let path: NSBezierPath
        if stroke.tool == .arrow,
           let startPoint = stroke.points.first,
           let endPoint = stroke.points.last {
            path = StrokePathBuilder.makeArrowPath(from: startPoint, to: endPoint, width: stroke.width)
        } else {
            path = StrokePathBuilder.makePath(points: stroke.points)
        }

        let color = stroke.tool == .highlighter
            ? stroke.color.nsColor.withAlphaComponent(0.32)
            : stroke.color.nsColor
        color.setStroke()
        path.lineWidth = stroke.renderedWidth
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.stroke()
    }

    // MARK: - Context menu

    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = NSMenu(title: "Options")

        let undoItem = NSMenuItem(title: "Undo", action: #selector(undoStroke), keyEquivalent: "z")
        undoItem.keyEquivalentModifierMask = [.command]
        undoItem.target = self
        undoItem.isEnabled = document.canUndo
        menu.addItem(undoItem)

        let redoItem = NSMenuItem(title: "Redo", action: #selector(redoStroke), keyEquivalent: "z")
        redoItem.keyEquivalentModifierMask = [.command, .shift]
        redoItem.target = self
        redoItem.isEnabled = document.canRedo
        menu.addItem(redoItem)

        let clearItem = NSMenuItem(title: "Clear", action: #selector(clearAll), keyEquivalent: "\u{001B}")
        clearItem.target = self
        clearItem.isEnabled = !document.isEmpty
        menu.addItem(clearItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(makeToolMenuItem())
        menu.addItem(makeWidthMenuItem())
        menu.addItem(makeColorMenuItem())

        menu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "")
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    private func makeToolMenuItem() -> NSMenuItem {
        let toolMenu = NSMenu(title: "Tool")

        for tool in preferences.toolOrder {
            let shortcut = preferences.keyboardShortcut(for: tool)
            let item = NSMenuItem(
                title: shortcut.map { "\(tool.name) (\($0))" } ?? tool.name,
                action: #selector(setDrawingTool(_:)),
                keyEquivalent: ""
            )
            item.representedObject = tool.rawValue
            item.state = tool == preferences.selectedTool ? .on : .off
            item.target = self
            toolMenu.addItem(item)
        }

        let toolItem = NSMenuItem(title: "Tool", action: nil, keyEquivalent: "")
        toolItem.submenu = toolMenu
        return toolItem
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
            item.state = width == preferences.strokeWidth ? .on : .off
            item.target = self
            widthMenu.addItem(item)
        }

        widthMenu.addItem(NSMenuItem.separator())
        let decreaseItem = NSMenuItem(
            title: "Decrease Width (W)",
            action: #selector(decreaseWidth),
            keyEquivalent: ""
        )
        decreaseItem.target = self
        widthMenu.addItem(decreaseItem)

        let increaseItem = NSMenuItem(
            title: "Increase Width (E)",
            action: #selector(increaseWidth),
            keyEquivalent: ""
        )
        increaseItem.target = self
        widthMenu.addItem(increaseItem)

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
            item.state = color == preferences.strokeColor ? .on : .off
            item.target = self
            colorMenu.addItem(item)
        }

        colorMenu.addItem(NSMenuItem.separator())
        let rotateItem = NSMenuItem(
            title: "Rotate Colors (R)",
            action: #selector(rotateColors),
            keyEquivalent: ""
        )
        rotateItem.target = self
        colorMenu.addItem(rotateItem)

        let colorItem = NSMenuItem(title: "Color", action: nil, keyEquivalent: "")
        colorItem.submenu = colorMenu
        return colorItem
    }

    // MARK: - Actions

    @objc private func undoStroke() {
        document.undo()
    }

    @objc private func redoStroke() {
        document.redo()
    }

    @objc private func clearAll() {
        currentStroke = nil
        eraserStartSnapshot = nil
        lastEraserPoint = nil
        document.clear()
        needsDisplay = true
    }

    @objc private func setDrawingTool(_ sender: NSMenuItem) {
        guard let rawTool = sender.representedObject as? String,
              let tool = DrawingTool(rawValue: rawTool) else { return }
        preferences.setSelectedTool(tool)
    }

    @objc private func setStrokeWidth(_ sender: NSMenuItem) {
        guard let width = sender.representedObject as? NSNumber else { return }
        preferences.setStrokeWidth(CGFloat(width.doubleValue))
    }

    @objc private func setStrokeColor(_ sender: NSMenuItem) {
        guard let rawColor = sender.representedObject as? String,
              let color = StrokeColor(rawValue: rawColor) else { return }
        preferences.setStrokeColor(color)
    }

    @objc private func decreaseWidth() {
        preferences.decreaseStrokeWidth()
    }

    @objc private func increaseWidth() {
        preferences.increaseStrokeWidth()
    }

    @objc private func rotateColors() {
        preferences.rotateStrokeColor()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}

struct DrawingView: NSViewRepresentable {
    let document: DrawingDocument
    let preferences: DrawingPreferences
    let canvasID: CanvasID

    func makeNSView(context: Context) -> DrawingNSView {
        DrawingNSView(document: document, preferences: preferences, canvasID: canvasID)
    }

    func updateNSView(_ nsView: DrawingNSView, context: Context) {}
}
