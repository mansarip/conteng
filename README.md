# Conteng

A macOS screen annotation application that allows you to draw overlays on top of any application using a system-wide hotkey. Conteng runs as a menu bar utility with a transparent overlay window for drawing.

**Current version:** 1.4

## Features

- **System-wide drawing overlay** - Draw on top of any application
- **Multi-monitor support** - Draw independently across every connected display
- **Global hotkey activation** - Press Option+Tab to toggle the overlay
- **Multiple drawing tools** - Various stroke widths and colors
- **Productivity tools** - Pen, translucent highlighter, stroke eraser, and arrows
- **Floating toolbar** - Switch tools, colors, and widths without leaving the overlay
- **Custom global shortcut** - Choose the activation key and modifier combination
- **Safe editing history** - Undo and redo strokes, including clearing the canvas
- **Menu bar integration** - Easy access through the system menu bar
- **Keyboard shortcuts** - Quick access to common functions

## What's New in 1.4

- Floating toolbar available on every connected display
- Pen, translucent highlighter, stroke eraser, and arrow tools
- Tool shortcuts using the number keys `1` through `4`
- Configurable global activation shortcut with persistent settings
- Improved toolbar hit targets and stroke-width controls
- Eraser gestures participate in the shared undo/redo history as a single action

Version 1.3 introduced multi-monitor overlays, persistent drawings when the overlay is hidden, safe undo/redo after clearing, improved stroke smoothing, and shared drawing preferences.

## Keyboard Shortcuts

When the overlay is active:
- **Option+Tab** - Toggle overlay on/off (default; customizable in Settings)
- **Esc** - Clear all drawings
- **Cmd+Z** - Undo last stroke
- **Cmd+Shift+Z** - Redo
- **1 / 2 / 3 / 4** - Pen / Highlighter / Eraser / Arrow
- **W** - Decrease stroke width
- **E** - Increase stroke width
- **R** - Rotate through colors (Red → Blue → Green → Black)
- **Shift+Drag** - Draw a straight line

## Requirements

- macOS 11.5 or later
- Xcode 16.3 or later (for building from source)

## Building from Source

### Prerequisites
1. Install Xcode from the Mac App Store
2. Clone this repository

### Build Instructions

#### Using Xcode (Recommended)
1. Open the project:
   ```bash
   open Conteng.xcodeproj
   ```
2. Select the "Conteng" scheme
3. Choose Product → Build (Cmd+B) to build
4. Choose Product → Run (Cmd+R) to run the application

#### Using Command Line
1. Build the project:
   ```bash
   xcodebuild -project Conteng.xcodeproj -scheme Conteng -configuration Release -derivedDataPath ./build build
   ```

2. The built application will be located at:
   ```
   build/Build/Products/Release/Conteng.app
   ```

#### Creating a Distributable App
To create an executable app that can be distributed:

1. Build for release:
   ```bash
   xcodebuild -project Conteng.xcodeproj -scheme Conteng -configuration Release -derivedDataPath ./build
   ```

2. The app will be built to:
   ```
   ./build/Build/Products/Release/Conteng.app
   ```

3. Copy the app to your Applications folder or distribute as needed:
   ```bash
   cp -r ./build/Build/Products/Release/Conteng.app /Applications/
   ```

## Running Tests

Run unit tests:
```bash
xcodebuild test -project Conteng.xcodeproj -scheme Conteng -destination 'platform=macOS'
```

Run UI tests:
```bash
xcodebuild test -project Conteng.xcodeproj -scheme Conteng -destination 'platform=macOS' -only-testing:ContengUITests
```

## Installation

1. Download or build the Conteng.app
2. Move it to your Applications folder
3. Launch the app - it will appear in your menu bar
4. Use Option+Tab to activate the drawing overlay

## Architecture

Conteng is built using:
- **SwiftUI** for the app structure
- **AppKit** for system-level overlay functionality
- **HotKey framework** for global hotkey registration

The app uses a hybrid SwiftUI/AppKit architecture to provide system-wide overlay capabilities while maintaining a modern Swift codebase.

`DrawingDocument` owns a shared undo/redo history across display-specific overlay windows. `DrawingPreferences` provides one persisted source of truth for tool, stroke width, and color. `GlobalShortcutPreferences` persists and applies the configurable activation shortcut.

## Dependencies

- **HotKey 0.2.1** - Swift Package Manager dependency for global hotkey registration

## Roadmap

### 1.5 — Capture & Sharing

- Copy the annotated screen directly to the clipboard
- Save annotations as PNG
- Capture the active monitor or a selected region
- Automatically hide the toolbar from exported captures

### 1.6 — Presentation Mode

- Temporary laser pointer
- Auto-fading strokes
- Presentation-focused controls

## License

[Add your license information here]

## Contributing

[Add contributing guidelines if applicable]
