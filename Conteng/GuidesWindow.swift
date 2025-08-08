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
                        content: "Once the overlay is active, simply click and drag to draw. Your strokes will appear over any application windows."
                    )
                    
                    GuideSection(
                        title: "Keyboard Shortcuts",
                        content: """
• Option+Tab - Toggle drawing overlay on/off
• Esc - Clear all drawings
• Cmd+Z - Undo last stroke
• W - Make stroke thinner
• E - Make stroke thicker
• R - Change color (Red → Blue → Green → Black)
"""
                    )
                    
                    GuideSection(
                        title: "Menu Options",
                        content: "Right-click on the menu bar icon to access all drawing options including stroke width and color settings."
                    )
                    
                    GuideSection(
                        title: "Tips",
                        content: """
• The overlay works across all your desktop spaces
• You can draw while in fullscreen mode
• Use different colors and stroke widths for better annotations
• Clear drawings before starting a new annotation session
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