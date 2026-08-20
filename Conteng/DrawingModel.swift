import AppKit
import Combine

typealias CanvasID = CGDirectDisplayID

enum DrawingTool: String, CaseIterable, Equatable, Identifiable {
    case pen
    case highlighter
    case eraser
    case arrow

    var id: String { rawValue }

    var name: String {
        rawValue.capitalized
    }

    var symbolName: String {
        switch self {
        case .pen: "pencil"
        case .highlighter: "highlighter"
        case .eraser: "eraser"
        case .arrow: "arrow.up.right"
        }
    }
}

/// A concrete colour value. Strokes keep their own copy, so editing or removing a
/// palette entry never repaints drawings that are already on screen.
struct StrokeColor: Identifiable, Equatable, Hashable {
    /// Normalised "#RRGGBB" — the value that is persisted and compared.
    let hex: String

    var id: String { hex }
    var name: String { Self.knownNames[hex] ?? hex }

    private static let knownNames: [String: String] = [
        "#FF0000": "Red",
        "#0000FF": "Blue",
        "#00FF00": "Green",
        "#000000": "Black",
        "#FFFFFF": "White",
        "#FFFF00": "Yellow",
        "#FF9500": "Orange",
        "#FF00FF": "Magenta",
        "#00FFFF": "Cyan"
    ]

    private static let legacyNames: [String: String] = [
        "red": "#FF0000",
        "blue": "#0000FF",
        "green": "#00FF00",
        "black": "#000000"
    ]

    init?(hex: String) {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if value.hasPrefix("#") { value.removeFirst() }
        guard value.count == 6, value.allSatisfy(\.isHexDigit) else { return nil }
        self.hex = "#\(value)"
    }

    init(nsColor: NSColor) {
        guard let color = nsColor.usingColorSpace(.sRGB) else {
            hex = "#000000"
            return
        }

        func channel(_ value: CGFloat) -> Int {
            Int((min(max(value, 0), 1) * 255).rounded())
        }

        hex = String(
            format: "#%02X%02X%02X",
            channel(color.redComponent),
            channel(color.greenComponent),
            channel(color.blueComponent)
        )
    }

    /// Accepts the current hex form as well as the colour names stored by older versions.
    init?(storedValue: String) {
        self.init(hex: Self.legacyNames[storedValue.lowercased()] ?? storedValue)
    }

    var nsColor: NSColor {
        let value = UInt32(hex.dropFirst(), radix: 16) ?? 0
        return NSColor(
            srgbRed: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: 1
        )
    }

    /// Small rounded swatch used to label menu items, which cannot rely on colour names.
    var swatchImage: NSImage {
        let size = NSSize(width: 12, height: 12)
        let image = NSImage(size: size)

        image.lockFocus()
        let path = NSBezierPath(
            roundedRect: NSRect(origin: .zero, size: size).insetBy(dx: 0.5, dy: 0.5),
            xRadius: 3,
            yRadius: 3
        )
        nsColor.setFill()
        path.fill()
        NSColor.separatorColor.setStroke()
        path.stroke()
        image.unlockFocus()

        return image
    }
}

struct Stroke: Identifiable, Equatable {
    let id: UUID
    var points: [CGPoint]
    var width: CGFloat
    var color: StrokeColor
    var tool: DrawingTool

    init(
        id: UUID = UUID(),
        points: [CGPoint],
        width: CGFloat,
        color: StrokeColor,
        tool: DrawingTool = .pen
    ) {
        self.id = id
        self.points = points
        self.width = width
        self.color = color
        self.tool = tool
    }

    var renderedWidth: CGFloat {
        tool == .highlighter ? max(width * 3, 12) : width
    }
}

final class DrawingDocument {
    typealias Snapshot = [CanvasID: [Stroke]]

    private enum HistoryAction {
        case add(canvasID: CanvasID, stroke: Stroke)
        case clear(snapshot: Snapshot)
        case replace(before: Snapshot, after: Snapshot)
    }

    private var strokesByCanvas: Snapshot = [:]
    private var undoStack: [HistoryAction] = []
    private var redoStack: [HistoryAction] = []

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }
    var isEmpty: Bool { strokesByCanvas.values.allSatisfy(\.isEmpty) }

    func strokes(for canvasID: CanvasID) -> [Stroke] {
        strokesByCanvas[canvasID] ?? []
    }

    func snapshot() -> Snapshot {
        strokesByCanvas
    }

    func add(_ stroke: Stroke, to canvasID: CanvasID) {
        guard stroke.tool != .eraser else { return }
        strokesByCanvas[canvasID, default: []].append(stroke)
        undoStack.append(.add(canvasID: canvasID, stroke: stroke))
        redoStack.removeAll()
        notifyChange(historyChanged: true)
    }

    @discardableResult
    func erase(at point: CGPoint, radius: CGFloat, on canvasID: CanvasID) -> Bool {
        guard var strokes = strokesByCanvas[canvasID] else { return false }
        let originalCount = strokes.count
        strokes.removeAll { StrokeHitTester.contains(point, radius: radius, in: $0) }
        guard strokes.count != originalCount else { return false }

        strokesByCanvas[canvasID] = strokes
        notifyChange()
        return true
    }

    func commitErasure(from originalSnapshot: Snapshot) {
        guard originalSnapshot != strokesByCanvas else { return }
        undoStack.append(.replace(before: originalSnapshot, after: strokesByCanvas))
        redoStack.removeAll()
        notifyChange(historyChanged: true)
    }

    func clear() {
        let snapshot = strokesByCanvas.filter { !$0.value.isEmpty }
        guard !snapshot.isEmpty else { return }

        strokesByCanvas.removeAll()
        undoStack.append(.clear(snapshot: snapshot))
        redoStack.removeAll()
        notifyChange(historyChanged: true)
    }

    func undo() {
        guard let action = undoStack.popLast() else { return }

        switch action {
        case let .add(canvasID, stroke):
            strokesByCanvas[canvasID]?.removeAll { $0.id == stroke.id }
        case let .clear(snapshot):
            strokesByCanvas = snapshot
        case let .replace(before, _):
            strokesByCanvas = before
        }

        redoStack.append(action)
        notifyChange(historyChanged: true)
    }

    func redo() {
        guard let action = redoStack.popLast() else { return }

        switch action {
        case let .add(canvasID, stroke):
            strokesByCanvas[canvasID, default: []].append(stroke)
        case .clear:
            strokesByCanvas.removeAll()
        case let .replace(_, after):
            strokesByCanvas = after
        }

        undoStack.append(action)
        notifyChange(historyChanged: true)
    }

    private func notifyChange(historyChanged: Bool = false) {
        NotificationCenter.default.post(name: .drawingDocumentDidChange, object: self)
        if historyChanged {
            NotificationCenter.default.post(name: .drawingHistoryDidChange, object: self)
        }
    }
}

final class DrawingPreferences: ObservableObject {
    static let shared = DrawingPreferences()
    static let availableWidths: [CGFloat] = [2, 4, 5, 6, 7, 8, 10]
    static let defaultToolOrder = DrawingTool.allCases
    static let defaultColorPalette: [StrokeColor] = ["#FF0000", "#0000FF", "#00FF00", "#000000"]
        .compactMap(StrokeColor.init(hex:))
    static let maximumPaletteColors = 8
    static let suggestedColors: [StrokeColor] = [
        "#FF9500", "#FFFF00", "#FF00FF", "#00FFFF", "#FFFFFF", "#8E44AD", "#1ABC9C", "#7F8C8D"
    ].compactMap(StrokeColor.init(hex:))

    private enum Key {
        static let strokeWidth = "drawing.strokeWidth"
        static let strokeColor = "drawing.strokeColor"
        static let selectedTool = "drawing.selectedTool"
        static let clearAfterStop = "drawing.clearAfterStop"
        static let toolOrder = "drawing.toolOrder"
        static let colorPalette = "drawing.colorPalette"
    }

    private let defaults: UserDefaults

    @Published private(set) var strokeWidth: CGFloat
    @Published private(set) var strokeColor: StrokeColor
    @Published private(set) var selectedTool: DrawingTool
    @Published private(set) var clearsAfterStopDrawing: Bool
    @Published private(set) var toolOrder: [DrawingTool]
    @Published private(set) var colorPalette: [StrokeColor]

    var canDecreaseStrokeWidth: Bool {
        guard let index = Self.availableWidths.firstIndex(of: strokeWidth) else { return false }
        return index > 0
    }

    var canIncreaseStrokeWidth: Bool {
        guard let index = Self.availableWidths.firstIndex(of: strokeWidth) else { return false }
        return index < Self.availableWidths.count - 1
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let savedWidth = CGFloat(defaults.double(forKey: Key.strokeWidth))
        strokeWidth = Self.availableWidths.contains(savedWidth) ? savedWidth : 5

        let palette = Self.sanitizedPalette(defaults.stringArray(forKey: Key.colorPalette) ?? [])
        colorPalette = palette

        if let rawColor = defaults.string(forKey: Key.strokeColor),
           let savedColor = StrokeColor(storedValue: rawColor) {
            strokeColor = savedColor
        } else {
            strokeColor = palette[0]
        }

        if let rawTool = defaults.string(forKey: Key.selectedTool),
           let savedTool = DrawingTool(rawValue: rawTool) {
            selectedTool = savedTool
        } else {
            selectedTool = .pen
        }

        clearsAfterStopDrawing = defaults.bool(forKey: Key.clearAfterStop)
        toolOrder = Self.sanitizedToolOrder(defaults.stringArray(forKey: Key.toolOrder) ?? [])
    }

    /// Keeps a stored order usable after tools are added, removed, or duplicated.
    private static func sanitizedToolOrder(_ rawTools: [String]) -> [DrawingTool] {
        var order: [DrawingTool] = []

        for tool in rawTools.compactMap(DrawingTool.init(rawValue:)) where !order.contains(tool) {
            order.append(tool)
        }

        order.append(contentsOf: defaultToolOrder.filter { !order.contains($0) })
        return order
    }

    func keyboardShortcut(for tool: DrawingTool) -> String? {
        guard let index = toolOrder.firstIndex(of: tool), index < 9 else { return nil }
        return String(index + 1)
    }

    func tool(forKeyboardShortcut character: Character) -> DrawingTool? {
        guard let position = character.wholeNumberValue,
              position >= 1, position <= toolOrder.count else { return nil }
        return toolOrder[position - 1]
    }

    func moveTool(_ tool: DrawingTool, to destination: Int) {
        guard let origin = toolOrder.firstIndex(of: tool),
              origin != destination,
              toolOrder.indices.contains(destination) else { return }

        var order = toolOrder
        order.remove(at: origin)
        order.insert(tool, at: destination)

        toolOrder = order
        defaults.set(order.map(\.rawValue), forKey: Key.toolOrder)
        notifyChange()
    }

    func resetToolOrder() {
        guard toolOrder != Self.defaultToolOrder else { return }
        toolOrder = Self.defaultToolOrder
        defaults.removeObject(forKey: Key.toolOrder)
        notifyChange()
    }

    var canAddColor: Bool { colorPalette.count < Self.maximumPaletteColors }
    var canRemoveColor: Bool { colorPalette.count > 1 }

    /// Keeps a stored palette usable: drops unreadable or repeated entries, enforces the
    /// cap, and never leaves the palette empty.
    private static func sanitizedPalette(_ rawColors: [String]) -> [StrokeColor] {
        var palette: [StrokeColor] = []

        for color in rawColors.compactMap(StrokeColor.init(hex:))
        where !palette.contains(color) && palette.count < maximumPaletteColors {
            palette.append(color)
        }

        return palette.isEmpty ? defaultColorPalette : palette
    }

    func addColor(_ color: StrokeColor) {
        guard canAddColor, !colorPalette.contains(color) else {
            setStrokeColor(color)
            return
        }

        colorPalette.append(color)
        persistPalette()
        setStrokeColor(color)
    }

    /// Adds the first unused suggestion, giving the new swatch a colour worth keeping
    /// even if the user never opens the picker.
    func addSuggestedColor() {
        guard canAddColor else { return }

        let unused = { (color: StrokeColor) in !self.colorPalette.contains(color) }
        guard let color = Self.suggestedColors.first(where: unused)
            ?? Self.defaultColorPalette.first(where: unused) else { return }

        addColor(color)
    }

    func replaceColor(at index: Int, with color: StrokeColor) {
        guard colorPalette.indices.contains(index) else { return }

        let replaced = colorPalette[index]
        guard replaced != color else { return }
        // Two identical swatches would collapse into one on the next launch.
        guard !colorPalette.contains(color) else { return }

        colorPalette[index] = color
        persistPalette()

        if strokeColor == replaced {
            setStrokeColor(color)
        } else {
            notifyChange()
        }
    }

    func removeColor(at index: Int) {
        guard canRemoveColor, colorPalette.indices.contains(index) else { return }

        let removed = colorPalette.remove(at: index)
        persistPalette()

        if strokeColor == removed {
            setStrokeColor(colorPalette[min(index, colorPalette.count - 1)])
        } else {
            notifyChange()
        }
    }

    func resetColorPalette() {
        guard colorPalette != Self.defaultColorPalette else { return }

        colorPalette = Self.defaultColorPalette
        defaults.removeObject(forKey: Key.colorPalette)

        if colorPalette.contains(strokeColor) {
            notifyChange()
        } else {
            setStrokeColor(colorPalette[0])
        }
    }

    private func persistPalette() {
        defaults.set(colorPalette.map(\.hex), forKey: Key.colorPalette)
    }

    func setStrokeWidth(_ width: CGFloat) {
        guard Self.availableWidths.contains(width), width != strokeWidth else { return }
        strokeWidth = width
        defaults.set(Double(width), forKey: Key.strokeWidth)
        notifyChange()
    }

    func decreaseStrokeWidth() {
        guard canDecreaseStrokeWidth,
              let index = Self.availableWidths.firstIndex(of: strokeWidth) else { return }
        setStrokeWidth(Self.availableWidths[index - 1])
    }

    func increaseStrokeWidth() {
        guard canIncreaseStrokeWidth,
              let index = Self.availableWidths.firstIndex(of: strokeWidth) else { return }
        setStrokeWidth(Self.availableWidths[index + 1])
    }

    func setStrokeColor(_ color: StrokeColor) {
        guard color != strokeColor else { return }
        strokeColor = color
        defaults.set(color.hex, forKey: Key.strokeColor)
        notifyChange()
    }

    func rotateStrokeColor() {
        guard let index = colorPalette.firstIndex(of: strokeColor) else {
            setStrokeColor(colorPalette[0])
            return
        }

        setStrokeColor(colorPalette[(index + 1) % colorPalette.count])
    }

    func setSelectedTool(_ tool: DrawingTool) {
        guard tool != selectedTool else { return }
        selectedTool = tool
        defaults.set(tool.rawValue, forKey: Key.selectedTool)
        notifyChange()
    }

    func setClearsAfterStopDrawing(_ enabled: Bool) {
        guard enabled != clearsAfterStopDrawing else { return }
        clearsAfterStopDrawing = enabled
        defaults.set(enabled, forKey: Key.clearAfterStop)
        notifyChange()
    }

    private func notifyChange() {
        NotificationCenter.default.post(name: .drawingPreferencesDidChange, object: self)
    }
}

enum StrokeHitTester {
    static func contains(_ point: CGPoint, radius: CGFloat, in stroke: Stroke) -> Bool {
        guard let firstPoint = stroke.points.first else { return false }
        let hitRadius = radius + stroke.renderedWidth / 2

        if stroke.points.count == 1 {
            return distance(from: point, to: firstPoint) <= hitRadius
        }

        for index in 1..<stroke.points.count {
            if distance(
                from: point,
                toSegmentFrom: stroke.points[index - 1],
                to: stroke.points[index]
            ) <= hitRadius {
                return true
            }
        }

        if stroke.tool == .arrow,
           let startPoint = stroke.points.first,
           let endPoint = stroke.points.last {
            for headPoint in StrokePathBuilder.arrowHeadPoints(
                from: startPoint,
                to: endPoint,
                width: stroke.width
            ) where distance(from: point, toSegmentFrom: headPoint, to: endPoint) <= hitRadius {
                return true
            }
        }

        return false
    }

    private static func distance(from point: CGPoint, to otherPoint: CGPoint) -> CGFloat {
        hypot(point.x - otherPoint.x, point.y - otherPoint.y)
    }

    private static func distance(
        from point: CGPoint,
        toSegmentFrom start: CGPoint,
        to end: CGPoint
    ) -> CGFloat {
        let deltaX = end.x - start.x
        let deltaY = end.y - start.y
        let lengthSquared = deltaX * deltaX + deltaY * deltaY

        guard lengthSquared > 0 else { return distance(from: point, to: start) }

        let projection = max(
            0,
            min(1, ((point.x - start.x) * deltaX + (point.y - start.y) * deltaY) / lengthSquared)
        )
        let projectedPoint = CGPoint(
            x: start.x + projection * deltaX,
            y: start.y + projection * deltaY
        )
        return distance(from: point, to: projectedPoint)
    }
}

enum StrokePathBuilder {
    static func makePath(points: [CGPoint]) -> NSBezierPath {
        let path = NSBezierPath()
        guard let firstPoint = points.first else { return path }

        path.move(to: firstPoint)
        guard points.count > 1 else { return path }

        if points.count == 2 {
            path.line(to: points[1])
            return path
        }

        for index in 0..<(points.count - 1) {
            let point0 = index > 0 ? points[index - 1] : points[index]
            let point1 = points[index]
            let point2 = points[index + 1]
            let point3 = index + 2 < points.count ? points[index + 2] : point2

            let controlPoint1 = CGPoint(
                x: point1.x + (point2.x - point0.x) / 6,
                y: point1.y + (point2.y - point0.y) / 6
            )
            let controlPoint2 = CGPoint(
                x: point2.x - (point3.x - point1.x) / 6,
                y: point2.y - (point3.y - point1.y) / 6
            )

            path.curve(to: point2, controlPoint1: controlPoint1, controlPoint2: controlPoint2)
        }

        return path
    }

    static func makeArrowPath(from start: CGPoint, to end: CGPoint, width: CGFloat) -> NSBezierPath {
        let path = NSBezierPath()
        path.move(to: start)
        path.line(to: end)

        let headPoints = arrowHeadPoints(from: start, to: end, width: width)
        guard headPoints.count == 2 else { return path }

        path.move(to: headPoints[0])
        path.line(to: end)
        path.line(to: headPoints[1])
        return path
    }

    static func arrowHeadPoints(from start: CGPoint, to end: CGPoint, width: CGFloat) -> [CGPoint] {
        let angle = atan2(end.y - start.y, end.x - start.x)
        let headLength = max(10, width * 3)
        let spread = CGFloat.pi / 6

        let firstHeadPoint = CGPoint(
            x: end.x - headLength * cos(angle - spread),
            y: end.y - headLength * sin(angle - spread)
        )
        let secondHeadPoint = CGPoint(
            x: end.x - headLength * cos(angle + spread),
            y: end.y - headLength * sin(angle + spread)
        )
        return [firstHeadPoint, secondHeadPoint]
    }
}
