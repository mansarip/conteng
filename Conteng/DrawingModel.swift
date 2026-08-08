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

    var keyboardShortcut: String {
        switch self {
        case .pen: "1"
        case .highlighter: "2"
        case .eraser: "3"
        case .arrow: "4"
        }
    }
}

enum StrokeColor: String, CaseIterable, Equatable, Identifiable {
    case red
    case blue
    case green
    case black

    var id: String { rawValue }
    var name: String { rawValue.capitalized }

    var nsColor: NSColor {
        switch self {
        case .red: .red
        case .blue: .blue
        case .green: .green
        case .black: .black
        }
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

    private enum Key {
        static let strokeWidth = "drawing.strokeWidth"
        static let strokeColor = "drawing.strokeColor"
        static let selectedTool = "drawing.selectedTool"
    }

    private let defaults: UserDefaults

    @Published private(set) var strokeWidth: CGFloat
    @Published private(set) var strokeColor: StrokeColor
    @Published private(set) var selectedTool: DrawingTool

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

        if let rawColor = defaults.string(forKey: Key.strokeColor),
           let savedColor = StrokeColor(rawValue: rawColor) {
            strokeColor = savedColor
        } else {
            strokeColor = .red
        }

        if let rawTool = defaults.string(forKey: Key.selectedTool),
           let savedTool = DrawingTool(rawValue: rawTool) {
            selectedTool = savedTool
        } else {
            selectedTool = .pen
        }
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
        defaults.set(color.rawValue, forKey: Key.strokeColor)
        notifyChange()
    }

    func rotateStrokeColor() {
        guard let index = StrokeColor.allCases.firstIndex(of: strokeColor) else { return }
        let nextIndex = (index + 1) % StrokeColor.allCases.count
        setStrokeColor(StrokeColor.allCases[nextIndex])
    }

    func setSelectedTool(_ tool: DrawingTool) {
        guard tool != selectedTool else { return }
        selectedTool = tool
        defaults.set(tool.rawValue, forKey: Key.selectedTool)
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
