import AppKit
import Testing
@testable import Conteng

struct ContengTests {
    @Test func undoAndRedoFollowStrokeOrderAcrossCanvases() {
        let document = DrawingDocument()
        let firstStroke = makeStroke(x: 10)
        let secondStroke = makeStroke(x: 20)

        document.add(firstStroke, to: 1)
        document.add(secondStroke, to: 2)

        document.undo()
        #expect(document.strokes(for: 1) == [firstStroke])
        #expect(document.strokes(for: 2).isEmpty)
        #expect(document.canRedo)

        document.redo()
        #expect(document.strokes(for: 2) == [secondStroke])
        #expect(!document.canRedo)
    }

    @Test func clearCanBeUndoneAndRedone() {
        let document = DrawingDocument()
        let firstStroke = makeStroke(x: 10)
        let secondStroke = makeStroke(x: 20)
        document.add(firstStroke, to: 1)
        document.add(secondStroke, to: 2)

        document.clear()
        #expect(document.isEmpty)

        document.undo()
        #expect(document.strokes(for: 1) == [firstStroke])
        #expect(document.strokes(for: 2) == [secondStroke])

        document.redo()
        #expect(document.isEmpty)
    }

    @Test func aNewStrokeInvalidatesRedoHistory() {
        let document = DrawingDocument()
        document.add(makeStroke(x: 10), to: 1)
        document.undo()
        #expect(document.canRedo)

        document.add(makeStroke(x: 20), to: 1)
        #expect(!document.canRedo)
    }

    @Test func drawingPreferencesPersistValidSelections() {
        let suiteName = "ContengTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let preferences = DrawingPreferences(defaults: defaults)
        preferences.setStrokeWidth(8)
        preferences.setStrokeColor(.green)

        let restoredPreferences = DrawingPreferences(defaults: defaults)
        #expect(restoredPreferences.strokeWidth == 8)
        #expect(restoredPreferences.strokeColor == .green)
    }

    @Test func smoothPathEndsAtTheFinalInputPoint() {
        let points = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 20, y: 30),
            CGPoint(x: 50, y: 10),
            CGPoint(x: 80, y: 40)
        ]

        let path = StrokePathBuilder.makePath(points: points)
        #expect(path.currentPoint == points.last)
    }

    private func makeStroke(x: CGFloat) -> Stroke {
        Stroke(
            points: [CGPoint(x: x, y: 0), CGPoint(x: x + 5, y: 5)],
            width: 5,
            color: .red
        )
    }
}
