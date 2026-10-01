import Foundation
import SwiftData

#if SWIFT_PACKAGE
  import PhotoCore
#endif

@Model final class PhotoRecord {
  @Attribute(.unique) var id: UUID
  var title: String
  var contentHash: String
  var width: Int
  var height: Int
  var imported: Date
  var collection: String
  var tags: [String]
  var favorite = false
  var archived = false
  init(imported: ImportedPhoto, title: String) {
    id = imported.key
    contentHash = imported.hash
    width = imported.width
    height = imported.height
    self.title = String(title.prefix(200))
    self.imported = Date()
    collection = ""
    tags = []
  }
}
