import AppKit
import XCTest

@MainActor final class WorkflowTests: XCTestCase {
  override func setUpWithError() throws { continueAfterFailure = false }
  override func tearDown() async throws { await MainActor.run { XCUIApplication().terminate() } }
  private func screenshot(_ app: XCUIApplication, _ name: String) {
    let attachment = XCTAttachment(screenshot: app.windows.firstMatch.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
  func testImportEditFavoriteAndArchivePersistence() throws {
    let folder = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    let image = NSImage(size: NSSize(width: 720, height: 480), flipped: false) { rect in
      NSColor(calibratedRed: 0.88, green: 0.85, blue: 0.77, alpha: 1).setFill()
      rect.fill()
      NSColor(calibratedRed: 0.18, green: 0.35, blue: 0.42, alpha: 1).setFill()
      NSBezierPath(
        roundedRect: NSRect(x: 210, y: 80, width: 300, height: 320), xRadius: 100, yRadius: 100
      ).fill()
      return true
    }
    let rep = try XCTUnwrap(NSBitmapImageRep(data: try XCTUnwrap(image.tiffRepresentation)))
    let fixture = folder.appendingPathComponent("fixture.png")
    try XCTUnwrap(rep.representation(using: .png, properties: [:])).write(to: fixture)
    let app = XCUIApplication()
    app.launchEnvironment["PHOTO_TEST_STORE"] = UUID().uuidString
    app.launch()
    app.activate()
    XCTAssertTrue(app.buttons["Import file"].waitForExistence(timeout: 15), app.debugDescription)
    app.buttons["Import file"].click()
    app.typeKey("g", modifierFlags: [.command, .shift])
    let path = app.textFields["PathTextField"]
    XCTAssertTrue(path.waitForExistence(timeout: 5), app.debugDescription)
    path.click()
    path.typeText(fixture.path)
    app.typeKey(.return, modifierFlags: [])
    let open = app.sheets["open-panel"].buttons["OKButton"]
    XCTAssertTrue(open.waitForExistence(timeout: 5), app.debugDescription)
    open.click()
    XCTAssertTrue(app.staticTexts["720 × 480"].waitForExistence(timeout: 15), app.debugDescription)
    app.buttons["Edit details"].click()
    let title = app.textFields["photo-title"]
    XCTAssertTrue(title.waitForExistence(timeout: 5), app.debugDescription)
    title.click()
    title.typeKey("a", modifierFlags: .command)
    title.typeText("Studio reference")
    app.textFields["photo-collection"].click()
    app.textFields["photo-collection"].typeText("Design")
    app.buttons["Save"].click()
    XCTAssertTrue(app.buttons["Favorite"].waitForExistence(timeout: 5), app.debugDescription)
    app.buttons["Favorite"].click()
    screenshot(app, "Photo library")
    app.terminate()
    app.launch()
    app.activate()
    let photo = app.buttons["Studio reference"]
    XCTAssertTrue(photo.waitForExistence(timeout: 15), app.debugDescription)
    photo.click()
    XCTAssertTrue(
      app.buttons["Remove favorite"].waitForExistence(timeout: 10), app.debugDescription)
    app.buttons["Archive photo"].click()
    XCTAssertTrue(photo.waitForNonExistence(timeout: 10), app.debugDescription)
    app.buttons["Archived"].click()
    XCTAssertTrue(photo.waitForExistence(timeout: 10), app.debugDescription)
    photo.click()
    XCTAssertTrue(app.buttons["Restore photo"].waitForExistence(timeout: 5), app.debugDescription)
    app.buttons["Restore photo"].click()
  }
}
