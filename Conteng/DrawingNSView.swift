import SwiftUI

final class DrawingNSView: NSView {
    private let document: DrawingDocument
    private let preferences: DrawingPreferences
    private let canvasID: CanvasID

    private var currentStroke: Stroke?
    private var cursorLocation: CGPoint?
    private var startPoint: CGPoint?
    private var isDrawingStraightLine = false
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
        isDrawingStraightLine = event.modifierFlags.contains(.shift)
        currentStroke = Stroke(
            points: [point],
            width: preferences.strokeWidth,
            color: preferences.strokeColor
        )
        cursorLocation = nil
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)

        if isDrawingStraightLine, let startPoint {
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

        if isDrawingStraightLine, let startPoint {
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
            let radius = max(1, preferences.strokeWidth / 2)
            let indicatorRect = NSRect(
                x: cursorLocation.x - radius,
                y: cursorLocation.y - radius,
                width: radius * 2,
                height: radius * 2
            )
            let indicator = NSBezierPath(ovalIn: indicatorRect)
            preferences.strokeColor.nsColor.setFill()
            indicator.fill()
        }
    }

    private func draw(_ stroke: Stroke) {
        guard stroke.points.count > 1 else {
            if let point = stroke.points.first {
                let radius = stroke.width / 2
                let dotRect = NSRect(
                    x: point.x - radius,
                    y: point.y - radius,
                    width: radius * 2,
                    height: radius * 2
                )
                stroke.color.nsColor.setFill()
                NSBezierPath(ovalIn: dotRect).fill()
            }
            return
        }

        let path = StrokePathBuilder.makePath(points: stroke.points)
        stroke.color.nsColor.setStroke()
        path.lineWidth = stroke.width
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
        menu.addItem(makeWidthMenuItem())
        menu.addItem(makeColorMenuItem())

        menu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "")
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
        document.clear()
        needsDisplay = true
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
