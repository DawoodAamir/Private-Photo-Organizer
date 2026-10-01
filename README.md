# Private Photo Organizer

A native photo reference library for iPhone, iPad, and Mac. Import selected photos, organize collections, and review on-device tag suggestions before saving them.

## What it demonstrates

- SwiftUI navigation adapted to compact and desktop layouts, PhotosPicker, and native file import.
- Local SwiftData metadata, favorites, searchable approved tags, and reversible archiving.
- Actor-isolated image storage with bounded decoding, original-file preservation, SHA-256 duplicate detection, and disposable previews.
- Vision scene classification alongside an original, bundled Core AI palette model. Analysis is cancellable and stale results cannot replace the selected photo's suggestions.
- Swift 6 complete concurrency checking and native workflow tests for import, editing, persistence, and archive/restore.

## Run

Open `Private Photo Organizer.xcodeproj` in Xcode 27 and choose the **Private Photo Organizer** scheme. Deployment targets are iOS/iPadOS 27 and macOS 27. Mac builds use ad-hoc signing; choose your own development team for a physical iPhone or iPad. The bundle ID is `com.dd.privatephotoorganizer`.

Import a still image from Files or the system photo picker. Select **Edit details** to name it and assign a collection. **Suggest tags** analyzes the app's preview locally; **Add tag** saves only the suggestion you choose. Archived images retain their originals and can be restored from the sidebar.

## Models and limitations

Vision supplies scene labels and confidence values. The bundled `Palette.aimodel` computes squared distances between an image's downsampled mean RGB and nine fixed palette centers. It is a small deterministic model authored for this project, **not a trained image captioner or face recognizer**. Palette output is a rough reference aid, especially for multicolored images. A palette failure preserves available Vision suggestions. Xcode 27’s iOS Simulator SDK does not include Core AI; Simulator runs retain Vision and manual tags, with an explicit palette-unavailable notice. Palette inference requires a supported physical device or Apple silicon Mac.

Originals are copied without modification. Previews are orientation-corrected JPEGs up to 2,048 pixels and omit original metadata. Imports are limited to 25 MB and 50 megapixels. This app does not modify the Photos library, sync libraries, identify people, or extract Live Photo video.

## Development

```sh
swift test
swift test -c release
bash Scripts/test-ui.sh
```

The tests include real Core AI inference on macOS 27, image round trips, preview bounds, tag normalization, and invalid input handling. GitHub Actions builds Mac and iOS Simulator release configurations and runs the native Mac workflow, retaining its result bundle. UI automation requires a runner permitted to control apps.

`Sources/Core` owns image services and validation; `Sources/App` owns SwiftData and presentation. Models remain on the main actor; image and inference work cross actor boundaries using values. Original icon artwork is reproducible with `swift Scripts/GenerateIcon.swift "$PWD"`.

To regenerate the palette asset, use an isolated Python environment with Apple's `coreai-core==1.0.0b3` and run `Scripts/GeneratePalette.py`. The checked-in asset is ready to use; Python is not an app dependency. See [Apple's Core AI tools](https://github.com/apple/coreai-models) and [Core AI](https://developer.apple.com/core-ai/).

[Privacy](PRIVACY.md) · [Verification](Docs/Verification.md) · [MIT license](LICENSE)
