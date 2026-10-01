import CoreGraphics
import CryptoKit
import Foundation
import ImageIO
import Vision

#if canImport(CoreAI)
  import CoreAI
#endif

public enum PhotoError: Error, LocalizedError {
  case invalidImage, tooLarge, modelUnavailable
  public var errorDescription: String? {
    switch self {
    case .invalidImage: "Choose a supported still image."
    case .tooLarge: "Use images up to 25 MB and 50 megapixels."
    case .modelUnavailable:
      "The palette model couldn't run on this device. You can still review scene tags or add your own."
    }
  }
}
public struct ImportedPhoto: Sendable {
  public let key: UUID
  public let hash: String
  public let width: Int
  public let height: Int
}
public struct SuggestedTag: Identifiable, Sendable, Equatable {
  public var id: String { label }
  public let label: String
  public let confidence: Float?
  public let source: String
}
public enum PhotoRules {
  public static func tags(_ text: String) -> [String] {
    var found = Set<String>()
    return text.split(separator: ",").compactMap { value in
      let label = String(value.trimmingCharacters(in: .whitespacesAndNewlines).prefix(60))
        .lowercased()
      guard !label.isEmpty, found.insert(label).inserted else { return nil }
      return label
    }.prefix(15).map { $0 }
  }
}
public actor PhotoAssets {
  public nonisolated let root: URL
  public init(root: URL) { self.root = root }
  public nonisolated func original(_ key: UUID) -> URL {
    root.appendingPathComponent(key.uuidString + ".original")
  }
  public nonisolated func preview(_ key: UUID) -> URL {
    root.appendingPathComponent(key.uuidString + ".jpg")
  }
  public func importURL(_ url: URL) throws -> ImportedPhoto {
    let scoped = url.startAccessingSecurityScopedResource()
    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
    guard (try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) <= 25_000_000 else {
      throw PhotoError.tooLarge
    }
    return try importData(Data(contentsOf: url))
  }
  public func importData(_ data: Data) throws -> ImportedPhoto {
    guard data.count <= 25_000_000 else { throw PhotoError.tooLarge }
    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
      let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
      let width = properties[kCGImagePropertyPixelWidth] as? Int,
      let height = properties[kCGImagePropertyPixelHeight] as? Int, width > 0, height > 0
    else { throw PhotoError.invalidImage }
    guard Int64(width) * Int64(height) <= 50_000_000 else { throw PhotoError.tooLarge }
    guard
      let image = CGImageSourceCreateThumbnailAtIndex(
        source, 0,
        [
          kCGImageSourceCreateThumbnailFromImageAlways: true,
          kCGImageSourceThumbnailMaxPixelSize: 2048,
          kCGImageSourceCreateThumbnailWithTransform: true,
        ] as CFDictionary)
    else { throw PhotoError.invalidImage }
    let key = UUID()
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let original = original(key)
    let preview = preview(key)
    do {
      try data.write(to: original, options: .atomic)
      let output = NSMutableData()
      guard
        let destination = CGImageDestinationCreateWithData(
          output, "public.jpeg" as CFString, 1, nil)
      else { throw PhotoError.invalidImage }
      CGImageDestinationAddImage(
        destination, image, [kCGImageDestinationLossyCompressionQuality: 0.85] as CFDictionary)
      guard CGImageDestinationFinalize(destination) else { throw PhotoError.invalidImage }
      try (output as Data).write(to: preview, options: .atomic)
    } catch {
      try? FileManager.default.removeItem(at: original)
      try? FileManager.default.removeItem(at: preview)
      throw error
    }
    return ImportedPhoto(
      key: key, hash: SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined(),
      width: width, height: height)
  }
  public func discardImport(_ key: UUID) {
    try? FileManager.default.removeItem(at: original(key))
    try? FileManager.default.removeItem(at: preview(key))
  }
}
public struct PhotoAnalysis: Sendable {
  public let tags: [SuggestedTag]
  public let notice: String?
}
public actor PhotoAnalyzer {
  private let modelURL: URL
  #if canImport(CoreAI)
    private var model: AIModel?
  #endif
  public init(modelURL: URL) { self.modelURL = modelURL }
  public func suggestions(preview: URL) async throws -> PhotoAnalysis {
    let request = ClassifyImageRequest()
    let observations = try await request.perform(on: preview)
    try Task.checkCancellation()
    var tags = observations.filter { $0.confidence >= 0.15 }.prefix(5).map {
      SuggestedTag(label: $0.identifier, confidence: $0.confidence, source: "Vision")
    }
    do {
      let rgb = try Self.averageRGB(preview)
      let palette = try await palette(rgb: rgb)
      try Task.checkCancellation()
      tags.append(
        SuggestedTag(
          label: "palette: " + palette, confidence: nil,
          source: "Core AI · mean colour"))
      return PhotoAnalysis(tags: tags, notice: nil)
    } catch {
      try Task.checkCancellation()
      return PhotoAnalysis(tags: tags, notice: PhotoError.modelUnavailable.localizedDescription)
    }
  }
  public func palette(rgb: [Float]) async throws -> String {
    guard rgb.count == 3, rgb.allSatisfy({ $0.isFinite && $0 >= 0 && $0 <= 1 }) else {
      throw PhotoError.invalidImage
    }
    #if canImport(CoreAI)
      if model == nil { model = try await AIModel(contentsOf: modelURL) }
      try Task.checkCancellation()
      guard let function = try model?.loadFunction(named: "main") else {
        throw PhotoError.modelUnavailable
      }
      let input = NDArray(scalars: rgb, shape: [1, 3])
      var output = try await function.run(inputs: ["rgb": input])
      guard let value = output.remove("distances"), let array = value.ndArray, array.shape == [9]
      else { throw PhotoError.modelUnavailable }
      let view = array.view(as: Float.self)
      var winner = 0
      var best = Float.infinity
      for index in 0..<9 {
        let distance = view[scalarAt: [index]]
        guard distance.isFinite else { throw PhotoError.modelUnavailable }
        if distance < best {
          best = distance
          winner = index
        }
      }
      return ["dark", "light", "neutral", "red", "green", "blue", "gold", "purple", "brown"][winner]
    #else
      throw PhotoError.modelUnavailable
    #endif
  }
  private static func averageRGB(_ url: URL) throws -> [Float] {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
      let space = CGColorSpace(name: CGColorSpace.sRGB)
    else { throw PhotoError.invalidImage }
    var pixel: [UInt8] = [0, 0, 0, 0]
    let rendered = pixel.withUnsafeMutableBytes { buffer -> Bool in
      guard
        let context = CGContext(
          data: buffer.baseAddress, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
          space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
      else { return false }
      context.interpolationQuality = .high
      context.draw(image, in: CGRect(x: 0, y: 0, width: 1, height: 1))
      return true
    }
    guard rendered else { throw PhotoError.invalidImage }
    return pixel.prefix(3).map { Float($0) / 255 }
  }
}
