import AppKit

typealias CanvasID = CGDirectDisplayID

enum StrokeColor: String, CaseIterable, Equatable {
    case red
    case blue
    case green
    case black

    var name: String {
        rawValue.capitalized
    }

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

    init(
        id: UUID = UUID(),
        points: [CGPoint],
        width: CGFloat,
        color: StrokeColor
    ) {
        self.id = id
        self.points = points
        self.width = width
        self.color = color
    }
}

final class DrawingDocument {
    private enum HistoryAction {
        case add(canvasID: CanvasID, stroke: Stroke)
        case clear(snapshot: [CanvasID: [Stroke]])
    }

    private var strokesByCanvas: [CanvasID: [Stroke]] = [:]
    private var undoStack: [HistoryAction] = []
    private var redoStack: [HistoryAction] = []

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }
    var isEmpty: Bool { strokesByCanvas.values.allSatisfy(\.isEmpty) }

    func strokes(for canvasID: CanvasID) -> [Stroke] {
        strokesByCanvas[canvasID] ?? []
    }

    func add(_ stroke: Stroke, to canvasID: CanvasID) {
        strokesByCanvas[canvasID, default: []].append(stroke)
        undoStack.append(.add(canvasID: canvasID, stroke: stroke))
        redoStack.removeAll()
        notifyChange()
    }

    func clear() {
        let snapshot = strokesByCanvas.filter { !$0.value.isEmpty }
        guard !snapshot.isEmpty else { return }

        strokesByCanvas.removeAll()
        undoStack.append(.clear(snapshot: snapshot))
        redoStack.removeAll()
        notifyChange()
    }

    func undo() {
        guard let action = undoStack.popLast() else { return }

        switch action {
        case let .add(canvasID, stroke):
            strokesByCanvas[canvasID]?.removeAll { $0.id == stroke.id }
        case let .clear(snapshot):
            strokesByCanvas = snapshot
        }

        redoStack.append(action)
        notifyChange()
    }

    func redo() {
        guard let action = redoStack.popLast() else { return }

        switch action {
        case let .add(canvasID, stroke):
            strokesByCanvas[canvasID, default: []].append(stroke)
        case .clear:
            strokesByCanvas.removeAll()
        }

        undoStack.append(action)
        notifyChange()
    }

    private func notifyChange() {
        NotificationCenter.default.post(name: .drawingDocumentDidChange, object: self)
    }
}

final class DrawingPreferences {
    static let shared = DrawingPreferences()
    static let availableWidths: [CGFloat] = [2, 4, 5, 6, 7, 8, 10]

    private enum Key {
        static let strokeWidth = "drawing.strokeWidth"
        static let strokeColor = "drawing.strokeColor"
    }

    private let defaults: UserDefaults

    private(set) var strokeWidth: CGFloat
    private(set) var strokeColor: StrokeColor

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
    }

    func setStrokeWidth(_ width: CGFloat) {
        guard Self.availableWidths.contains(width), width != strokeWidth else { return }
        strokeWidth = width
        defaults.set(Double(width), forKey: Key.strokeWidth)
        notifyChange()
    }

    func decreaseStrokeWidth() {
        guard let index = Self.availableWidths.firstIndex(of: strokeWidth), index > 0 else { return }
        setStrokeWidth(Self.availableWidths[index - 1])
    }

    func increaseStrokeWidth() {
        guard let index = Self.availableWidths.firstIndex(of: strokeWidth),
              index < Self.availableWidths.count - 1 else { return }
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

    private func notifyChange() {
        NotificationCenter.default.post(name: .drawingPreferencesDidChange, object: self)
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

        // Catmull-Rom to cubic Bezier conversion. Each segment ends at its
        // actual input point, including the final mouse position.
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
}
