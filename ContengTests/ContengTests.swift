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
        preferences.setSelectedTool(.highlighter)

        let restoredPreferences = DrawingPreferences(defaults: defaults)
        #expect(restoredPreferences.strokeWidth == 8)
        #expect(restoredPreferences.strokeColor == .green)
        #expect(restoredPreferences.selectedTool == .highlighter)
    }

    @Test func strokeWidthButtonsMoveThroughEveryAvailableWidth() {
        let suiteName = "ContengWidthTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let preferences = DrawingPreferences(defaults: defaults)
        preferences.setStrokeWidth(10)
        #expect(preferences.canDecreaseStrokeWidth)
        #expect(!preferences.canIncreaseStrokeWidth)

        preferences.decreaseStrokeWidth()
        #expect(preferences.strokeWidth == 8)

        while preferences.canDecreaseStrokeWidth {
            preferences.decreaseStrokeWidth()
        }
        #expect(preferences.strokeWidth == 2)
        #expect(!preferences.canDecreaseStrokeWidth)

        preferences.increaseStrokeWidth()
        #expect(preferences.strokeWidth == 4)
    }

    @Test func eraserGestureIsUndoneAndRedoneAsOneAction() {
        let document = DrawingDocument()
        let erasedStroke = Stroke(
            points: [CGPoint(x: 0, y: 0), CGPoint(x: 30, y: 0)],
            width: 5,
            color: .red
        )
        let retainedStroke = Stroke(
            points: [CGPoint(x: 0, y: 100), CGPoint(x: 30, y: 100)],
            width: 5,
            color: .blue
        )
        document.add(erasedStroke, to: 1)
        document.add(retainedStroke, to: 1)

        let snapshot = document.snapshot()
        #expect(document.erase(at: CGPoint(x: 15, y: 2), radius: 8, on: 1))
        document.commitErasure(from: snapshot)
        #expect(document.strokes(for: 1) == [retainedStroke])

        document.undo()
        #expect(document.strokes(for: 1) == [erasedStroke, retainedStroke])

        document.redo()
        #expect(document.strokes(for: 1) == [retainedStroke])
    }

    @Test func highlighterUsesItsRenderedWidthForEraserHitTesting() {
        let highlighter = Stroke(
            points: [CGPoint(x: 0, y: 0), CGPoint(x: 30, y: 0)],
            width: 4,
            color: .green,
            tool: .highlighter
        )

        #expect(StrokeHitTester.contains(CGPoint(x: 15, y: 8), radius: 3, in: highlighter))
        #expect(!StrokeHitTester.contains(CGPoint(x: 15, y: 20), radius: 3, in: highlighter))
    }

    @Test func globalShortcutPersistsAndRequiresAModifier() {
        let suiteName = "ContengShortcutTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let preferences = GlobalShortcutPreferences(defaults: defaults)
        preferences.setKey(.k)
        preferences.setModifiers([.control, .shift])

        let restoredPreferences = GlobalShortcutPreferences(defaults: defaults)
        #expect(restoredPreferences.shortcut.key == .k)
        #expect(restoredPreferences.shortcut.modifiers == [.control, .shift])

        restoredPreferences.setModifier(.control, enabled: false)
        restoredPreferences.setModifier(.shift, enabled: false)
        #expect(restoredPreferences.shortcut.modifiers == .shift)
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
