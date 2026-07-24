import XCTest

/// UI Tests for capturing App Store screenshots
/// Run with: xcodebuild test -project PetScans.xcodeproj -scheme PetScans -destination "platform=iOS Simulator,name=iPhone 16 Pro Max" -only-testing:PetScansUITests/ScreenshotTests
final class ScreenshotTests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - App Store shot list (1.4.2)
    //
    // Every shot leads with a real, named product from the seeded catalog. The
    // old suite led with three onboarding screens — a welcome page, a benefits
    // page, and an empty form — none of which show the app recognizing anything.
    // Yuka's first shot is a scored product; so is ours now.
    //
    // Captions are supplied by the framing step, not the app. These tests just
    // stage the underlying screens; `Scripts/run_screenshots.sh` runs them
    // across the three device sizes.

    /// Shot 1 — the hero. A recognizable brand scored well, pack shot visible.
    func test01_HeroScore() throws {
        launchSeeded()
        openScan(brandOrName: "Merrick")
        Thread.sleep(forTimeInterval: 1.0)
        takeScreenshot(named: "01_HeroScore")
    }

    /// Shot 2 — the verdict that sells the app: a treat marked Avoid, with the
    /// ingredient warning cards (BHA/BHT, unnamed meat, added color) in frame.
    func test02_UnsafeIngredients() throws {
        launchSeeded()
        openScan(brandOrName: "Milk-Bone")

        // Scroll to the warnings section so the harmful-ingredient cards, not
        // just the score dial, are what the shot leads with.
        let scoreView = app.scrollViews["product-score-view"]
        scoreView.swipeUp()
        Thread.sleep(forTimeInterval: 0.8)
        takeScreenshot(named: "02_UnsafeIngredients")
    }

    /// Shot 3 — the pet-specific allergen banner, the thing a generic scanner
    /// can't do. Top of the same Milk-Bone result, before any scrolling.
    func test03_AllergenAlert() throws {
        launchSeeded()
        openScan(brandOrName: "Milk-Bone")
        Thread.sleep(forTimeInterval: 1.0)
        takeScreenshot(named: "03_AllergenAlert")
    }

    /// Shot 4 — an ingredient explained. Opens the detail sheet from a tappable
    /// ingredient row on the Merrick result.
    func test04_IngredientDetail() throws {
        launchSeeded()
        openScan(brandOrName: "Merrick")

        let scoreView = app.scrollViews["product-score-view"]
        // The ingredients card is below the fold; scroll it into reach.
        scoreView.swipeUp()
        scoreView.swipeUp()
        Thread.sleep(forTimeInterval: 0.5)

        // Ingredient rows are buttons whose label combines the rank and name
        // ("1. Deboned Beef …"), so match on CONTAINS rather than equality. Only
        // rows backed by a real catalog record are enabled, which is why the
        // seeder points these at real ingredient IDs.
        let beef = app.buttons.containing(
            NSPredicate(format: "label CONTAINS[c] 'Deboned Beef'")
        ).firstMatch
        XCTAssertTrue(beef.waitForExistence(timeout: 5))
        beef.tap()

        // IngredientDetailSheet has a Done button — proof the sheet presented.
        let done = app.buttons["Done"].firstMatch
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.6)
        takeScreenshot(named: "04_IngredientDetail")
    }

    /// Shot 5 — the library. The seeded History list stands in for "10,000+
    /// foods built in": three real products, each with a score dial.
    func test05_Library() throws {
        launchSeeded()
        app.tabBars.buttons["History"].tap()

        let historyView = app.collectionViews["history-view"]
        XCTAssertTrue(historyView.waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.6)
        takeScreenshot(named: "05_Library")
    }

    /// Shot 6 — the trust shot, mirroring Yuka's independence screen. The
    /// Scientific References screen lists AAFCO, FDA, ASPCA, Merck.
    func test06_Sources() throws {
        launchSeeded()
        app.tabBars.buttons["Settings"].tap()

        let references = app.buttons["Scientific References"].firstMatch
        XCTAssertTrue(references.waitForExistence(timeout: 5))
        references.tap()
        Thread.sleep(forTimeInterval: 0.6)
        takeScreenshot(named: "06_Sources")
    }

    // MARK: - Navigation Helpers

    private func launchSeeded() {
        app.launchArguments = ["-UITesting", "-SkipOnboarding", "-SeedScreenshotData"]
        app.launch()
    }

    /// Opens a seeded scan from History by matching the product cell's label,
    /// which carries both the product name and the brand. Matching on text
    /// rather than a positional index keeps each shot pinned to a specific
    /// product regardless of how SwiftData happens to order same-timestamp rows.
    private func openScan(brandOrName: String) {
        app.tabBars.buttons["History"].tap()

        let historyView = app.collectionViews["history-view"]
        XCTAssertTrue(historyView.waitForExistence(timeout: 5))

        let cell = app.buttons.containing(
            NSPredicate(format: "label CONTAINS[c] %@", brandOrName)
        ).firstMatch
        XCTAssertTrue(cell.waitForExistence(timeout: 5))
        cell.tap()

        let scoreView = app.scrollViews["product-score-view"]
        XCTAssertTrue(scoreView.waitForExistence(timeout: 10))
    }

    // MARK: - Helper Methods

    private func takeScreenshot(named name: String) {
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        // Also save to file system for easy access
        saveScreenshotToFile(screenshot: screenshot, name: name)
    }

    private func saveScreenshotToFile(screenshot: XCUIScreenshot, name: String) {
        let fileManager = FileManager.default

        // Get the project directory from environment or use a default
        let projectDir = ProcessInfo.processInfo.environment["PROJECT_DIR"] ?? FileManager.default.currentDirectoryPath
        let screenshotDir = "\(projectDir)/Screenshots"

        // Create directory if needed
        try? fileManager.createDirectory(atPath: screenshotDir, withIntermediateDirectories: true)

        // Save screenshot
        let path = "\(screenshotDir)/\(name).png"
        let data = screenshot.pngRepresentation
        try? data.write(to: URL(fileURLWithPath: path))

        print("Screenshot saved: \(path)")
    }
}
