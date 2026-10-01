import Foundation
import SwiftData
import Testing

@testable import PhotoCore
@testable import PhotoPersistence

@Test @MainActor func importedMetadataRoundTripsThroughSwiftData() throws {
  let folder = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: folder) }
  let config = ModelConfiguration(
    url: folder.appendingPathComponent("Library.store"), cloudKitDatabase: .none)
  let container = try ModelContainer(for: PhotoRecord.self, configurations: config)
  let context = ModelContext(container)
  let imported = ImportedPhoto(
    key: UUID(), hash: String(repeating: "ab", count: 32), width: 720, height: 480)
  let photo = PhotoRecord(imported: imported, title: "Original reference")
  photo.tags = ["studio"]
  photo.favorite = true
  context.insert(photo)
  try context.save()
  let reopened = try ModelContainer(for: PhotoRecord.self, configurations: config)
  let restored = try #require(ModelContext(reopened).fetch(FetchDescriptor<PhotoRecord>()).first)
  #expect(restored.contentHash == imported.hash)
  #expect(restored.tags == ["studio"])
  #expect(restored.favorite)
  #expect(restored.width == 720)
}
