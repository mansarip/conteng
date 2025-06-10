//
//  OverlayWindow.swift
//  Conteng
//
//  Created by Luqman on 11/06/2025.
//
import Cocoa

class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    
    init(contentRect: NSRect, contentView: NSView) {
        super.init(contentRect: contentRect, styleMask: .borderless, backing: .buffered, defer: false)
        self.backgroundColor = .clear
        self.isOpaque = false
        self.level = .mainMenu + 1 // always-on-top
        self.ignoresMouseEvents = false
        self.hasShadow = false
        self.contentView = contentView
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }
}
