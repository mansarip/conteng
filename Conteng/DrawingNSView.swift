//
//  DrawingNSView.swift
//  Conteng
//
//  Created by Luqman on 11/06/2025.
//
import SwiftUI

class DrawingNSView: NSView {
    var strokes: [[CGPoint]] = []
    var currentStroke: [CGPoint] = []
    var onStrokesChanged: (([[CGPoint]]) -> Void)?

    override func mouseDown(with event: NSEvent) {
        currentStroke = [convert(event.locationInWindow, from: nil)]
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        currentStroke.append(convert(event.locationInWindow, from: nil))
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        if !currentStroke.isEmpty {
            strokes.append(currentStroke)
            onStrokesChanged?(strokes)
            currentStroke = []
            needsDisplay = true
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        NSColor.red.setStroke()

        // Lukis semua stroke lama
        for stroke in strokes {
            drawSmoothPath(stroke)
        }
        // Lukis currentStroke (real-time)
        if !currentStroke.isEmpty {
            drawSmoothPath(currentStroke)
        }
    }
    
    private func drawSmoothPath(_ points: [CGPoint]) {
        guard points.count > 1 else { return }
        let path = NSBezierPath()
        path.move(to: points[0])

        for i in 1..<points.count {
            let prev = points[i - 1]
            let curr = points[i]
            let mid = CGPoint(x: (prev.x + curr.x) / 2, y: (prev.y + curr.y) / 2)
            path.curve(to: mid, controlPoint1: prev, controlPoint2: curr)
        }

        path.lineWidth = 3
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.stroke()
    }
}


struct DrawingView: NSViewRepresentable {
    @Binding var strokes: [[CGPoint]]

    func makeNSView(context: Context) -> DrawingNSView {
        let view = DrawingNSView()
        view.onStrokesChanged = { newStrokes in
            self.strokes = newStrokes
        }
        return view
    }

    func updateNSView(_ nsView: DrawingNSView, context: Context) {
        // Optionally sync from SwiftUI state if needed
    }
}
