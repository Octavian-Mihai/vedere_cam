# VedereCam

An iOS camera app that shoots RAW, skips the phone's default processing, and bakes a film-style look into the photo at capture time. The original is always kept.

## Features

- **RAW capture:** takes a RAW (DNG) photo, which avoids the system's tone mapping, sharpening and noise reduction. Falls back to a processed photo on devices without RAW support, and says so on screen.
- **Look applied at capture:** the viewfinder shows the chosen look live, and the saved photo is rendered from the RAW data with the same look.
- **Looks:** 13 film-style LUT presets plus Neutral, each with a short description (shown under the preset strip, in the editor, and in Settings → About the looks).
- **Strength slider:** blends the look with the untouched image, 0–100%.
- **Look editor:** Lightness (exposure, contrast, highlights, shadows), Color (saturation, warmth, tint), Mix (hue, saturation and luminance for 8 colors), Effects (sharpness, grain, `.cube` LUT import and intensity).
- **Non-destructive gallery:** the original DNG is never modified. The photo view has a one-tap preset picker that re-renders from the RAW file.
- **Import and export:** import photos or RAW files, export originals or rendered files, and export or import look files (`.look.json`) and `.cube` LUTs.
- **Choose what is saved per shot:** original RAW, rendered HEIC/JPEG, look-settings file, and a copy to the Photos library. Settings shows an estimated size per shot and storage used.
- **Camera options:** rule-of-thirds grid, shutter haptic, remember last look.

## Requirements

- Xcode 27 and iOS 17 or later
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)
- A real iPhone to use the camera. The simulator has no camera, but it runs the UI and the tests.

## Setup

```bash
cp Config/Local.xcconfig.example Config/Local.xcconfig
# edit Config/Local.xcconfig and set DEVELOPMENT_TEAM to your Apple team ID
xcodegen generate
open VedereCam.xcodeproj
```

`Config/Local.xcconfig` is git-ignored, so your team ID stays out of the repo. The Xcode project is generated from `project.yml` and is not committed, so run `xcodegen generate` after pulling changes.

## Project layout

| Path | What it holds |
|---|---|
| `VedereCam/Sources/CaptureService.swift` | Camera session, RAW capture, live preview frames |
| `VedereCam/Sources/LookEngine.swift` | Core Image chain shared by preview and final render |
| `VedereCam/Sources/Look.swift` | Look model, per-color mix, output options |
| `VedereCam/Sources/CubeLUT.swift` | `.cube` LUT parser |
| `VedereCam/Sources/Storage.swift` | Library files, sidecars, re-render, import and export |
| `VedereCam/Sources/*View.swift`, `LookEditor.swift` | SwiftUI screens |
| `VedereCam/Resources/LUTs/` | Bundled `.cube` presets |
| `VedereCam/Tests/` | Unit tests |

Each shot is stored as `IMG_<timestamp>.dng` (optional), `IMG_<timestamp>.heic` or `.jpg` (optional) and `IMG_<timestamp>.look.json` (optional) in the app's `Library` folder, which is visible in the Files app.

## Tests

```bash
xcodebuild test -project VedereCam.xcodeproj -scheme VedereCam \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO
```

## Known limitations

- The live preview is drawn from the normal video stream at about 30 fps through a plain image view, not a Metal view, and it is not computed from RAW. It should be close to the saved photo but is not identical.
- The simulator can't show the camera, so capture and the preview have only been exercised on a device by hand.

## Credits and licensing

The bundled LUTs come from the "No Fusion LUTs" pack. According to the pack's credit note, they are adapted from LUTs by Yahia Angelo, Rossandhisjpegs and Stephen Morais. No license text came with the pack, so confirm you may redistribute them before publishing the app or making the repo public. See `VedereCam/Resources/LUTs/CREDITS.txt`.

Preset names follow the LUT file names, and the descriptions are inspired-by summaries based on measuring each LUT. They are not exact film copies.
