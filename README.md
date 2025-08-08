# Conteng

A macOS screen annotation application that allows you to draw overlays on top of any application using a system-wide hotkey. Conteng runs as a menu bar utility with a transparent overlay window for drawing.

## Features

- **System-wide drawing overlay** - Draw on top of any application
- **Global hotkey activation** - Press Option+Tab to toggle the overlay
- **Multiple drawing tools** - Various stroke widths and colors
- **Menu bar integration** - Easy access through the system menu bar
- **Keyboard shortcuts** - Quick access to common functions

## Keyboard Shortcuts

When the overlay is active:
- **Option+Tab** - Toggle overlay on/off (global)
- **Esc** - Clear all drawings
- **Cmd+Z** - Undo last stroke
- **W** - Decrease stroke width
- **E** - Increase stroke width
- **R** - Rotate through colors (Red → Blue → Green → Black)

## Requirements

- macOS 11.0 or later
- Xcode 13.0 or later (for building from source)

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
   xcodebuild -project Conteng.xcodeproj -scheme Conteng -configuration Release build
   ```

2. The built application will be located at:
   ```
   build/Release/Conteng.app
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

## Dependencies

- **HotKey** - Swift Package Manager dependency for global hotkey registration

## License

[Add your license information here]

## Contributing

[Add contributing guidelines if applicable]