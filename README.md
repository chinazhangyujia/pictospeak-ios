# PicTalk iOS App

A SwiftUI-based iOS application for capturing and processing images and videos.

## Features

### Capture View

- **Camera Integration**: Full camera functionality with live preview
- **Photo Mode**: Capture high-quality photos
- **Video Mode**: Record videos up to 3 seconds
- **Gallery Access**: Select images from photo library
- **Permission Handling**: Proper camera and photo library permission requests

### Subscription System

- **Apple In-App Purchases**: Full StoreKit 2 integration
- **Free Trial**: 7-day free trial for new users
- **Multiple Plans**: Monthly and yearly subscription options
- **Restore Purchases**: Seamlessly restore subscriptions across devices
- **Sandbox Testing**: Complete testing environment for development

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

### Testing In-App Purchases

For testing subscriptions:

**Quick Start (Local Testing)**:

1. Edit Scheme: **Product** > **Scheme** > **Edit Scheme...**
2. Go to **Run** > **Options**
3. Set **StoreKit Configuration** to `pictospeak-ios.storekit`
4. Run the app and test purchases without any setup!

**For detailed testing instructions**, see:

- **Quick Start**: `QUICK_START_IAP_TESTING.md` - Fast setup for immediate testing
- **Complete Guide**: `SANDBOX_TESTING_GUIDE.md` - Comprehensive testing documentation

## File Structure

```
pictospeak-ios/
├── Views/
│   ├── Capture/
│   │   └── CaptureView.swift              # Main capture interface
│   ├── Subscription/
│   │   └── SubscriptionView.swift         # Subscription and payment UI
│   └── Home/
│       └── HomeView.swift                 # Home screen with navigation
├── Services/
│   ├── StoreKitManager.swift              # Apple IAP management
│   ├── SubscriptionService.swift          # Backend subscription API
│   └── ...
├── Models/
│   ├── SubscriptionModels.swift           # Subscription data models
│   └── ...
├── pictospeak-ios.storekit                # StoreKit configuration for testing
├── pictospeak_iosApp.swift                # App entry point
└── ContentView.swift                      # Root view controller
```

## Key Components

### StoreKit Integration

- **StoreKitManager**: Handles all Apple IAP operations

  - Product loading and caching
  - Purchase processing with free trial support
  - Transaction verification
  - Subscription restoration
  - Backend synchronization

- **SubscriptionView**: Modern UI for subscription plans
  - Monthly and yearly pricing cards
  - Feature comparison
  - Free trial callout
  - Restore purchases functionality

### Backend Integration

- **SubscriptionService**: Communicates with backend API
  - Fetches subscription policy
  - Verifies purchases server-side
  - Syncs subscription status
