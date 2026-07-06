# Pocket Closet

Pocket Closet is a local-first native iOS app for managing household clothing inventory.
It is built with SwiftUI and SwiftData and focuses on quickly capturing individual
clothing items, then finding them by owner, type, size, status, location, and search text.

## Project

- `PocketCloset.xcodeproj`: Xcode project
- `PocketCloset/`: SwiftUI app source and assets
- `PocketClosetTests/`: unit tests
- `PocketClosetUITests/`: UI tests
- `PRODUCT.md`: product requirements
- `DESIGN.md`: visual direction

## Requirements

- Xcode 17 or newer
- iOS 17 or newer deployment target

## Build

Open `PocketCloset.xcodeproj` in Xcode and run the `PocketCloset` scheme, or use:

```sh
xcodebuild -project PocketCloset.xcodeproj \
  -scheme PocketCloset \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  build
```

## Test

```sh
xcodebuild test -project PocketCloset.xcodeproj \
  -scheme PocketCloset \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```
