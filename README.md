# PicTalk iOS App

A SwiftUI-based iOS application for capturing and processing images and videos.

## Features

### Capture View

- **Camera Integration**: Full camera functionality with live preview
- **Photo Mode**: Capture high-quality photos
- **Video Mode**: Record videos up to 3 seconds
- **Gallery Access**: Select images from photo library
- **Permission Handling**: Proper camera and photo library permission requests

### UI Components

- **Navigation**: Back button to return to home screen
- **Mode Toggle**: Switch between Photo and Video modes
- **Capture Button**: Large circular button with gradient design
- **Gallery Button**: Access to photo library
- **Device Info**: Shows "iPhone M" in bottom corner

## Technical Implementation

### Camera Management

- `CameraManager` class handles all camera operations
- `AVCaptureSession` for camera input/output
- Proper permission handling with user-friendly alerts
- Support for both photo and video capture

### UI Architecture

- SwiftUI-based interface
- Dark theme with black background
- Responsive design for different iPhone sizes
- Custom camera preview using `UIViewRepresentable`

### Permissions

The app requires the following permissions:

- **Camera Access**: For capturing photos and videos
- **Photo Library Access**: For selecting images from gallery

These permissions are configured in the project settings and will prompt the user when first accessing camera or gallery features.

## Usage

1. Launch the app and tap "Start a New PicTalk" on the home screen
2. Grant camera permissions when prompted
3. Use the Photo/Video toggle to switch modes
4. Tap the capture button to take a photo or start/stop video recording
5. Use the gallery button to select existing images
6. Tap the back button to return to the home screen

## Requirements

- iOS 18.0+
- Xcode 15.0+
- Swift 5.0+

## Setup

1. Clone the repository
2. Open `pictospeak-ios.xcodeproj` in Xcode
3. Build and run on a physical device (camera features require a real device)
4. Grant camera and photo library permissions when prompted

## File Structure

```
pictospeak-ios/
├── Views/
│   ├── Capture/
│   │   └── CaptureView.swift      # Main capture interface
│   └── Home/
│       └── HomeView.swift         # Home screen with navigation
├── pictospeak_iosApp.swift        # App entry point
└── ContentView.swift              # Root view controller
```
