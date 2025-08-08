# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Conteng is a macOS screen annotation application built with SwiftUI and AppKit. It allows users to draw overlays on top of any application using a system-wide hotkey (Option+Tab). The app runs as a menu bar utility with a transparent overlay window for drawing.

## Architecture

### Core Components

- **ContengApp.swift** - Main SwiftUI App entry point with NSApplicationDelegateAdaptor
- **AppDelegate.swift** - Handles menu bar icon, hotkey registration (Option+Tab), overlay window management, and system notifications
- **ContentView.swift** - Simple SwiftUI view that wraps the drawing functionality
- **DrawingNSView.swift** - Main drawing canvas (NSView) with stroke rendering, mouse event handling, and keyboard shortcuts
- **OverlayWindow.swift** - Custom NSWindow subclass for the transparent overlay
- **AboutWindow.swift** - About dialog window
- **Notification+Menu.swift** - NotificationCenter extension for menu communication

### Key Design Patterns

1. **Hybrid SwiftUI/AppKit Architecture**: Uses SwiftUI for the app structure but relies heavily on AppKit (NSView, NSWindow) for system-level overlay functionality and precise drawing control.

2. **NotificationCenter Communication**: Menu actions in AppDelegate communicate with DrawingNSView through NotificationCenter notifications (.menuUndo, .menuClear, .menuSetWidth, .menuSetColor).

3. **System Overlay Window**: The drawing window uses `.mainMenu + 1` level, borderless style, and `.canJoinAllSpaces` behavior to appear over all applications.

4. **Event Monitoring**: DrawingNSView uses `NSEvent.addLocalMonitorForEvents` to capture keyboard shortcuts globally while the overlay is active.

## Build and Development

### Building the Project
```bash
# Open in Xcode
open Conteng.xcodeproj

# Build from command line
xcodebuild -project Conteng.xcodeproj -scheme Conteng -configuration Debug build

# Build for release
xcodebuild -project Conteng.xcodeproj -scheme Conteng -configuration Release build
```

### Testing
```bash
# Run unit tests
xcodebuild test -project Conteng.xcodeproj -scheme Conteng -destination 'platform=macOS'

# Run UI tests  
xcodebuild test -project Conteng.xcodeproj -scheme Conteng -destination 'platform=macOS' -only-testing:ContengUITests
```

### Dependencies
- **HotKey** - Swift Package Manager dependency for global hotkey registration

## Key Features and Controls

### Keyboard Shortcuts (when overlay is active)
- **Option+Tab** - Toggle overlay on/off (global)
- **Esc** - Clear all drawings
- **Cmd+Z** - Undo last stroke
- **W** - Decrease stroke width
- **E** - Increase stroke width  
- **R** - Rotate through colors (Red → Blue → Green → Black)

### Drawing System
- Smooth bezier curve rendering in `drawSmoothPath()`
- Real-time cursor indicator showing current color and size
- Stroke data structure stores points, width, and color
- Context menu available via right-click

### Menu Bar Integration
- Status bar icon with dropdown menu
- Menu options mirror keyboard shortcuts
- Hierarchical menus for stroke width and color selection

## Important Implementation Details

### Window Management
- Overlay window spans entire visible screen (`NSScreen.main.visibleFrame`)
- Window ignores mouse events when not drawing to allow interaction with underlying apps
- Window collection behavior allows it to appear on all spaces and in full-screen mode

### Memory Management
- DrawingNSView properly removes event monitors in `deinit`
- NotificationCenter observers are cleaned up on deallocation
- AboutWindow uses `isReleasedWhenClosed = false` for reuse

### Sandboxing
- App uses minimal sandbox entitlements (app-sandbox, read-only file access)
- No special permissions needed for overlay functionality
- HotKey framework handles global shortcut registration within sandbox constraints

## Code Conventions
- Uses standard Swift naming conventions
- Comments in both English and Malay (mixed codebase language)
- Proper MARK: comments for code organization
- SwiftUI views use struct, AppKit components use class
- Notification names use static extension pattern