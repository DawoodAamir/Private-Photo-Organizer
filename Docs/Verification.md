# Verification

## Automated coverage

Core tests run real palette inference, normalize and bound reviewed tags, reject invalid imports without creating assets, preserve original PNG bytes, constrain preview dimensions, and remove only the staged duplicate copy.

The native Mac workflow imports an original generated image through the standard open panel, edits its title and collection, favorites it, relaunches, verifies persistence, and archives/restores it. A screenshot is retained in the result bundle.

## Verification status

- macOS 27 Debug core tests: four passed locally on October 2, 2026.
- Release core tests: four passed locally on October 2, 2026.
- Mac, iOS Simulator, and unsigned iOS device Release builds: passed.
- Native workflow target: compiled locally; hosted execution pending.
- Physical-device photo picker, VoiceOver, and large-library performance: not yet verified.

## Manual review

Check compact navigation on iPhone and split layouts on iPad/Mac, larger text, keyboard operation, and VoiceOver labels. Try a cancelled file picker, corrupt image, oversized image, duplicate import, archived duplicate, inference cancellation, switching photos during analysis, and a missing model. Confirm that suggestions remain separate from approved tags and archive/restore preserves the original.
