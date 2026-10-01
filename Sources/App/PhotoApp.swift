import ImageIO
import PhotosUI
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

@main struct PhotoApp: App {
  private let container: ModelContainer?
  private let storageError: String?
  init() {
    do {
      let name =
        ProcessInfo.processInfo.environment["PHOTO_TEST_STORE"].map { "WorkflowTests-" + $0 }
        ?? "Private Photo Organizer"
      let folder = URL.applicationSupportDirectory.appendingPathComponent(name, isDirectory: true)
      try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
      let config = ModelConfiguration(
        url: folder.appendingPathComponent("Library.store"), cloudKitDatabase: .none)
      container = try ModelContainer(for: PhotoRecord.self, configurations: config)
      storageError = nil
    } catch {
      container = nil
      storageError = error.localizedDescription
    }
  }
  var body: some Scene {
    WindowGroup {
      if let container {
        OrganizerView().modelContainer(container)
      } else {
        ContentUnavailableView(
          "Library couldn't open", systemImage: "externaldrive.badge.exclamationmark",
          description: Text(
            (storageError ?? "Unknown storage error") + " Your existing files were preserved.")
        ).padding()
      }
    }
  }
}
struct OrganizerView: View {
  @Environment(\.modelContext) private var context
  @Query(sort: \PhotoRecord.imported, order: .reverse) private var photos: [PhotoRecord]
  @State private var search = ""
  @State private var selection: UUID?
  @State private var compactColumn: NavigationSplitViewColumn = .content
  @State private var collection: String?
  @State private var onlyFavorites = false
  @State private var showArchived = false
  @State private var pickerItem: PhotosPickerItem?
  @State private var importing = false
  @State private var editing: PhotoRecord?
  @State private var busy = false
  @State private var suggestions: [SuggestedTag] = []
  @State private var analysisNotice: String?
  @State private var error: String?
  @State private var task: Task<Void, Never>?
  @State private var requestID: UUID?
  @State private var assets: PhotoAssets
  @State private var analyzer: PhotoAnalyzer
  init() {
    let name =
      ProcessInfo.processInfo.environment["PHOTO_TEST_STORE"].map { "WorkflowTests-" + $0 }
      ?? "Private Photo Organizer"
    let folder = URL.applicationSupportDirectory.appendingPathComponent(name, isDirectory: true)
    _assets = State(
      initialValue: PhotoAssets(root: folder.appendingPathComponent("Photos", isDirectory: true)))
    _analyzer = State(
      initialValue: PhotoAnalyzer(
        modelURL: Bundle.main.url(forResource: "Palette", withExtension: "aimodel")
          ?? folder.appendingPathComponent("Missing Model")))
  }
  private var visible: [PhotoRecord] {
    photos.filter {
      $0.archived == showArchived && (!onlyFavorites || $0.favorite)
        && (collection == nil || $0.collection == collection)
        && (search.isEmpty
          || ($0.title + " " + $0.tags.joined(separator: " ")).localizedCaseInsensitiveContains(
            search))
    }
  }
  private var selected: PhotoRecord? { photos.first { $0.id == selection } }
  var body: some View {
    NavigationSplitView(preferredCompactColumn: $compactColumn) {
      List {
        Section("Library") {
          Button("All photos", systemImage: "photo.on.rectangle") {
            collection = nil
            onlyFavorites = false
            showArchived = false
            compactColumn = .content
          }
          Button("Favorites", systemImage: "star") {
            collection = nil
            onlyFavorites = true
            showArchived = false
            compactColumn = .content
          }
          Button("Archived", systemImage: "archivebox") {
            collection = nil
            onlyFavorites = false
            showArchived = true
            compactColumn = .content
          }
        }
        Section("Collections") {
          ForEach(Array(Set(photos.map(\.collection).filter { !$0.isEmpty })).sorted(), id: \.self)
          { name in
            Button(name, systemImage: "folder") {
              collection = name
              onlyFavorites = false
              showArchived = false
              compactColumn = .content
            }
          }
        }
        Section {
          Text("Photos stay in this app. Suggested tags need your review.").font(.caption)
            .foregroundStyle(.secondary)
        }
      }.navigationTitle("Photo Organizer")
        .navigationSplitViewColumnWidth(min: 200, ideal: 230)
    } content: {
      ScrollView {
        if busy {
          HStack {
            ProgressView()
            Text("Working…")
            Button("Stop") { cancel() }
          }.padding()
        }
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140, maximum: 220))], spacing: 16) {
          ForEach(visible) { photo in
            Button {
              selection = photo.id
              compactColumn = .detail
            } label: {
              VStack(alignment: .leading, spacing: 8) {
                LocalImage(url: assets.preview(photo.id)).aspectRatio(1, contentMode: .fit)
                  .clipShape(RoundedRectangle(cornerRadius: 8))
                HStack {
                  Text(photo.title).lineLimit(1)
                  Spacer()
                  if photo.favorite { Image(systemName: "star.fill").foregroundStyle(.secondary) }
                }
                .font(.subheadline)
              }.padding(8).background(
                selection == photo.id ? Color.accentColor.opacity(0.12) : Color.clear,
                in: RoundedRectangle(cornerRadius: 12))
            }.buttonStyle(.plain).accessibilityLabel(photo.title)
          }
        }.padding()
        if visible.isEmpty {
          ContentUnavailableView(
            "No photos here", systemImage: "photo",
            description: Text("Import a photo, or choose another collection."))
        }
      }.navigationTitle(
        showArchived ? "Archived" : onlyFavorites ? "Favorites" : collection ?? "All photos"
      )
      .searchable(text: $search, prompt: "Titles and approved tags")
      .toolbar {
        PhotosPicker(selection: $pickerItem, matching: .images) {
          Label("Choose photo", systemImage: "photo.badge.plus")
        }.disabled(busy)
        Button("Import file", systemImage: "square.and.arrow.down") { importing = true }.disabled(
          busy)
      }
    } detail: {
      if let selected {
        ScrollView {
          VStack(alignment: .leading, spacing: 20) {
            LocalImage(url: assets.preview(selected.id)).aspectRatio(contentMode: .fit).frame(
              maxHeight: 460)
            HStack {
              Text(selected.title).font(.title2.bold())
              Spacer()
              Button(
                selected.favorite ? "Remove favorite" : "Favorite",
                systemImage: selected.favorite ? "star.fill" : "star"
              ) { mutate { selected.favorite.toggle() } }
            }
            LabeledContent("Original dimensions", value: "\(selected.width) × \(selected.height)")
            if !selected.collection.isEmpty {
              LabeledContent("Collection", value: selected.collection)
            }
            Text(selected.tags.isEmpty ? "No approved tags" : selected.tags.joined(separator: ", "))
              .foregroundStyle(.secondary).textSelection(.enabled)
            HStack {
              Button("Edit details", systemImage: "pencil") { editing = selected }
              Button("Suggest tags", systemImage: "viewfinder") { analyze(selected.id) }.disabled(
                busy)
              if busy {
                ProgressView()
                Button("Stop") { cancel() }
              }
            }
            if let analysisNotice {
              Text(analysisNotice).font(.callout).foregroundStyle(.secondary)
            }
            if !suggestions.isEmpty {
              VStack(alignment: .leading, spacing: 12) {
                Text("Suggestions · review before adding").font(.headline)
                ForEach(suggestions) { tag in
                  HStack {
                    VStack(alignment: .leading) {
                      Text(tag.label)
                      Text(tag.confidence.map { "\(tag.source) · \(Int($0 * 100))%" } ?? tag.source)
                        .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Add tag") {
                      mutate {
                        selected.tags = PhotoRules.tags(
                          (selected.tags + [tag.label]).joined(separator: ","))
                      }
                    }.accessibilityIdentifier("approve-" + tag.label).disabled(
                      selected.tags.contains(tag.label.lowercased()) || selected.tags.count >= 15)
                  }
                }
                Text(
                  "Scene labels come from Vision. Palette uses an original Core AI mean-colour scorer; it cannot describe objects or people."
                ).font(.caption).foregroundStyle(.secondary)
              }
            }
            Button(selected.archived ? "Restore photo" : "Archive photo") {
              mutate { selected.archived.toggle() }
              selection = nil
              compactColumn = .content
            }
          }.padding(24)
        }.navigationTitle(selected.title)
      } else {
        ContentUnavailableView(
          "Choose a photo", systemImage: "photo.on.rectangle",
          description: Text("Review local tags, organize collections, and keep favorites."))
      }
    }
    .onChange(of: selection) { _, _ in
      cancel()
      suggestions = []
      analysisNotice = nil
    }
    .onChange(of: pickerItem) { _, item in
      guard let item else { return }
      cancel()
      busy = true
      let token = UUID()
      requestID = token
      task = Task {
        defer {
          if requestID == token {
            busy = false
            pickerItem = nil
            requestID = nil
          }
        }
        do {
          guard let data = try await item.loadTransferable(type: Data.self) else {
            throw PhotoError.invalidImage
          }
          try Task.checkCancellation()
          try await accept(assets.importData(data), title: "Imported photo")
        } catch { if !Task.isCancelled { self.error = error.localizedDescription } }
      }
    }
    .fileImporter(isPresented: $importing, allowedContentTypes: [.image]) { result in
      cancel()
      busy = true
      let token = UUID()
      requestID = token
      task = Task {
        defer {
          if requestID == token {
            busy = false
            requestID = nil
          }
        }
        do {
          let url = try result.get()
          try await accept(
            assets.importURL(url), title: url.deletingPathExtension().lastPathComponent)
        } catch { if !Task.isCancelled { self.error = error.localizedDescription } }
      }
    }
    .sheet(item: $editing) { photo in PhotoEditor(photo: photo) }
    .onDisappear { cancel() }
    .alert(
      "Couldn't finish",
      isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })
    ) {
      Button("OK") { error = nil }
    } message: {
      Text(error ?? "")
    }
  }
  private func accept(_ pending: ImportedPhoto, title: String) async throws {
    if Task.isCancelled {
      await assets.discardImport(pending.key)
      return
    }
    if let existing = photos.first(where: { $0.contentHash == pending.hash }) {
      await assets.discardImport(pending.key)
      selection = existing.id
      compactColumn = .detail
      error = "This photo is already in your library. Archived copies can be restored."
      return
    }
    let record = PhotoRecord(imported: pending, title: title)
    context.insert(record)
    do {
      try context.save()
      selection = record.id
      compactColumn = .detail
    } catch {
      context.rollback()
      await assets.discardImport(pending.key)
      throw error
    }
  }
  private func mutate(_ change: () -> Void) {
    change()
    do { try context.save() } catch {
      context.rollback()
      self.error = error.localizedDescription
    }
  }
  private func cancel() {
    task?.cancel()
    task = nil
    requestID = nil
    busy = false
  }
  private func analyze(_ id: UUID) {
    cancel()
    busy = true
    suggestions = []
    analysisNotice = nil
    let token = UUID()
    requestID = token
    task = Task {
      do {
        let result = try await analyzer.suggestions(preview: assets.preview(id))
        guard requestID == token, selection == id, !Task.isCancelled else { return }
        suggestions = result.tags
        analysisNotice = result.notice
      } catch {
        if requestID == token && !Task.isCancelled { self.error = error.localizedDescription }
      }
      if requestID == token {
        busy = false
        task = nil
      }
    }
  }
}
struct LocalImage: View {
  let url: URL
  @State private var image: CGImage?
  var body: some View {
    Group {
      if let image {
        Image(decorative: image, scale: 1).resizable()
      } else {
        Rectangle().fill(.quaternary).overlay {
          Image(systemName: "photo").foregroundStyle(.secondary)
        }
      }
    }.task(id: url) {
      image = await Self.load(url)
    }
  }
  @concurrent private static func load(_ url: URL) async -> CGImage? {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
    return CGImageSourceCreateThumbnailAtIndex(
      source, 0,
      [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceThumbnailMaxPixelSize: 1600,
      ] as CFDictionary)
  }
}
struct PhotoEditor: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var context
  let photo: PhotoRecord
  @State private var title = ""
  @State private var collection = ""
  @State private var tags = ""
  @State private var error: String?
  var body: some View {
    NavigationStack {
      Form {
        TextField("Title", text: $title).accessibilityIdentifier("photo-title")
        TextField("Collection", text: $collection).accessibilityIdentifier("photo-collection")
        TextField("Tags, separated by commas", text: $tags, axis: .vertical).lineLimit(2...5)
          .accessibilityIdentifier("photo-tags")
        Text("Up to 15 tags. Suggestions are never saved automatically.").font(.caption)
          .foregroundStyle(.secondary)
        if let error { Text(error).foregroundStyle(.red) }
      }.formStyle(.grouped).navigationTitle("Photo details")
        .toolbar {
          ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
          ToolbarItem(placement: .confirmationAction) {
            Button("Save") {
              photo.title = String(
                title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(200))
              photo.collection = String(
                collection.trimmingCharacters(in: .whitespacesAndNewlines).prefix(100))
              photo.tags = PhotoRules.tags(tags)
              do {
                try context.save()
                dismiss()
              } catch {
                context.rollback()
                self.error = error.localizedDescription
              }
            }.disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
          }
        }
    }.frame(minWidth: 360, minHeight: 300)
      .onAppear {
        title = photo.title
        collection = photo.collection
        tags = photo.tags.joined(separator: ", ")
      }
  }
}
