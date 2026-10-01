import CoreGraphics
import Foundation
import ImageIO
import Testing

@testable import PhotoCore

@Test func reviewedTagsHaveStableBounds() {
  #expect(PhotoRules.tags(" Cat, cat, , BEACH ") == ["cat", "beach"])
  #expect(PhotoRules.tags((0..<30).map { "tag\($0)" }.joined(separator: ",")).count == 15)
  #expect(PhotoRules.tags(String(repeating: "a", count: 80))[0].count == 60)
}
@Test func invalidImagesLeaveNoAssets() async throws {
  let root = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  let assets = PhotoAssets(root: root)
  await #expect(throws: PhotoError.invalidImage) {
    _ = try await assets.importData(Data("not a photo".utf8))
  }
  #expect(!FileManager.default.fileExists(atPath: root.path))
}
@Test func actualCoreAIPaletteInference() async throws {
  let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent()
  let analyzer = PhotoAnalyzer(modelURL: root.appendingPathComponent("Resources/Palette.aimodel"))
  #expect(try await analyzer.palette(rgb: [0.85, 0.15, 0.15]) == "red")
  #expect(try await analyzer.palette(rgb: [0.15, 0.3, 0.85]) == "blue")
  #expect(try await analyzer.palette(rgb: [0.1, 0.1, 0.1]) == "dark")
}

@Test func importPreservesOriginalAndBoundsPreview() async throws {
  let root = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  defer { try? FileManager.default.removeItem(at: root) }
  let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
  let context = try #require(
    CGContext(
      data: nil, width: 2400, height: 1200,
      bitsPerComponent: 8, bytesPerRow: 0, space: space,
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
  context.setFillColor(CGColor(red: 0.2, green: 0.5, blue: 0.4, alpha: 1))
  context.fill(CGRect(x: 0, y: 0, width: 2400, height: 1200))
  let image = try #require(context.makeImage())
  let bytes = NSMutableData()
  let destination = try #require(
    CGImageDestinationCreateWithData(bytes, "public.png" as CFString, 1, nil))
  CGImageDestinationAddImage(destination, image, nil)
  #expect(CGImageDestinationFinalize(destination))
  let assets = PhotoAssets(root: root)
  let first = try await assets.importData(bytes as Data)
  let second = try await assets.importData(bytes as Data)
  #expect(first.hash == second.hash)
  #expect(first.key != second.key)
  #expect(first.width == 2400 && first.height == 1200)
  #expect(try Data(contentsOf: assets.original(first.key)) == bytes as Data)
  let source = try #require(CGImageSourceCreateWithURL(assets.preview(first.key) as CFURL, nil))
  let preview = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
  #expect(preview.width == 2048 && preview.height == 1024)
  await assets.discardImport(second.key)
  #expect(FileManager.default.fileExists(atPath: assets.original(first.key).path))
  #expect(!FileManager.default.fileExists(atPath: assets.original(second.key).path))
}
