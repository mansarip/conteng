//
//  GuidesWindow.swift
//  Conteng
//
//  Created by Luqman on 11/06/2025.
//

import SwiftUI

struct GuidesWindow: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("How to Use Conteng")
                    .font(.title)
                    .bold()
                    .padding(.bottom, 10)
                
                VStack(alignment: .leading, spacing: 15) {
                    GuideSection(
                        title: "Getting Started",
                        content: "Conteng lets you draw on top of any application on your Mac. Press Option+Tab to start drawing anywhere on your screen."
                    )
                    
                    GuideSection(
                        title: "Drawing",
                        content: "Once the overlay is active, use the floating toolbar to choose Pen, Highlighter, Eraser, or Arrow, then click and drag anywhere on the screen."
                    )
                    
                    GuideSection(
                        title: "Keyboard Shortcuts",
                        content: """
• Option+Tab - Toggle drawing overlay on/off (default)
• Esc - Clear all drawings
• Cmd+Z - Undo last stroke
• Cmd+Shift+Z - Redo
• 1 / 2 / 3 / 4 - Pen / Highlighter / Eraser / Arrow
• W - Make stroke thinner
• E - Make stroke thicker
• R - Change color (Red → Blue → Green → Black)
• Shift+Drag - Draw a straight line
"""
                    )
                    
                    GuideSection(
                        title: "Menu Options",
                        content: "Click the menu bar icon for drawing options, or right-click the canvas for quick access. Open Settings to choose your global shortcut. Tool, width, color, and shortcut selections are remembered between launches."
                    )
                    
                    GuideSection(
                        title: "Tips",
                        content: """
• The overlay works across all connected displays and desktop spaces
• You can draw while in fullscreen mode
• Use different colors and stroke widths for better annotations
• Hiding the overlay keeps your drawings
• If you clear by mistake, press Cmd+Z to restore everything
"""
                    )
                }
                
                Spacer(minLength: 20)
            }
            .padding(30)
        }
        .frame(width: 450, height: 500)
    }
}

struct GuideSection: View {
    let title: String
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(content)
                .font(.body)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
