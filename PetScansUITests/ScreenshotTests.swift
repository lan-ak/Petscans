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

    /// Shot 4 — an ingredient explained. Opens the detail sheet from the BHA/BHT
    /// row on the Milk-Bone result.
    ///
    /// It used to open "Deboned Beef" on the Merrick result, which is rated safe
    /// for both species and carries only a function and an origin — so the sheet
    /// rendered a name, a green Safe badge and two lines, leaving most of the shot
    /// blank under a caption reading "Every ingredient, explained". BHA is rated
    /// caution for both species and its record carries notes, rules and a source,
    /// so the sheet actually fills with the per-ingredient content 1.4.4 added.
    func test04_IngredientDetail() throws {
        launchSeeded()
        openScan(brandOrName: "Milk-Bone")

        let scoreView = app.scrollViews["product-score-view"]
        // The ingredients card is below the fold; scroll it into reach.
        scoreView.swipeUp()
        scoreView.swipeUp()
        Thread.sleep(forTimeInterval: 0.5)

        // Ingredient rows are buttons whose label combines the rank and name
        // ("5. BHA/BHT …"), so match on CONTAINS rather than equality. Only rows
        // backed by a real catalog record are enabled, which is why the seeder
        // points these at real ingredient IDs.
        let bha = app.buttons.containing(
            NSPredicate(format: "label CONTAINS[c] 'BHA'")
        ).firstMatch
        XCTAssertTrue(bha.waitForExistence(timeout: 5))
        bha.tap()

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

    /// Smoke — Settings → My Pets → Luna → Add Ingredient → tap a chip → Done.
    /// Guards the "add ingredient to avoid" flow against crashing.
    func test99_AddIngredientToAvoid() throws {
        launchSeeded()

        app.tabBars.buttons["Settings"].tap()

        let myPets = app.buttons.containing(
            NSPredicate(format: "label CONTAINS[c] 'My Pets'")
        ).firstMatch
        XCTAssertTrue(myPets.waitForExistence(timeout: 5), "My Pets row missing")
        myPets.tap()

        let luna = app.buttons.containing(
            NSPredicate(format: "label CONTAINS[c] 'Luna'")
        ).firstMatch
        XCTAssertTrue(luna.waitForExistence(timeout: 5), "Luna row missing")
        luna.tap()

        let addIngredient = app.buttons["Add Ingredient"].firstMatch
        XCTAssertTrue(addIngredient.waitForExistence(timeout: 5), "Add Ingredient button missing")
        addIngredient.tap()

        // The search sheet now opens directly (no intermediate chips sheet), and
        // where the old `.searchable` crashed with "search text field already
        // borrowed". Its inline search field must render.
        let searchField = app.textFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 5), "Search field missing — sheet did not present (crash?)")

        // The common quick-pick chips live in this sheet now.
        let beefChip = app.buttons["Beef"].firstMatch
        XCTAssertTrue(beefChip.waitForExistence(timeout: 5), "Beef quick-pick chip missing")
        beefChip.tap()

        let done = app.buttons.containing(
            NSPredicate(format: "label BEGINSWITH 'Done'")
        ).firstMatch
        XCTAssertTrue(done.waitForExistence(timeout: 5), "Done missing")
        done.tap()

        // Back on pet detail without the app dying.
        XCTAssertTrue(app.buttons["Add Ingredient"].waitForExistence(timeout: 5),
                      "Did not return to pet detail — likely crashed")
    }

    // MARK: - AHA Onboarding Flow

    /// Walks the full onboarding → "check your food" AHA moment and captures a
    /// screenshot at each key step. Not part of the App Store shot list — this is
    /// a verification/iteration harness for the onboarding AHA feature.
    func testAHA_OnboardingFlow() throws {
        // -ResetOnboarding (not -ShowOnboarding) so onboarding shows AND can be
        // completed into the main app, letting us verify the History auto-save.
        app.launchArguments = ["-UITesting", "-ResetOnboarding"]
        app.launch()

        // Welcome → two benefit pages.
        tapButton("Get Started")
        tapButton("Continue")
        tapButton("Continue")

        // Pet setup: name (required) + a common allergen so the result flags it.
        // The trailing \n fires the field's Done action, dismissing the keyboard so
        // the allergen chips below it become hittable.
        let nameField = app.textFields["pet-name-field"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5), "pet name field")
        nameField.tap()
        nameField.typeText("Max\n")
        // Chip / row accessibility labels include example text, so match on CONTAINS.
        tapIfExists(containingButton("chicken"))
        takeScreenshot(named: "aha-00-petsetup")
        tapButton("Continue")

        // Avoidance groups: pick a couple (labels carry their example lists).
        tapIfExists(containingButton("Artificial colours"))
        tapIfExists(containingButton("Meat by-products"))
        takeScreenshot(named: "aha-01-groups")
        tapButton("Continue")

        // Search page (shared ProductCatalogSearchView). Multi-term query exercises
        // the fuzzy brand+protein matching.
        let searchField = app.textFields["catalog-search-field"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5), "search field")
        searchField.tap()
        searchField.typeText("purina chicken")
        takeScreenshot(named: "aha-02-search")

        // First result → result page.
        let firstResult = app.buttons.containing(
            NSPredicate(format: "label CONTAINS[c] %@", "chicken")
        ).firstMatch
        XCTAssertTrue(firstResult.waitForExistence(timeout: 8), "a search result")
        firstResult.tap()

        // Result page. This used to wait on a coach-mark tour's "tour-next" button, but no
        // such button exists — `OnboardingFoodResultView` documents that the reveal is
        // "deliberately left to land on its own — no coach-mark tour". The tour was dropped
        // from the design and the assertion was never updated, so this test has failed at
        // this line since it was written, taking the whole flow below it with it.
        //
        // Arrival is now asserted on the result screen's own CTA, which is what actually
        // ships.
        let ahaContinue = app.buttons["aha-continue"]
        XCTAssertTrue(ahaContinue.waitForExistence(timeout: 12), "AHA result page rendered")
        takeScreenshot(named: "aha-03-result-full")

        // Tap an ingredient to open its detail sheet.
        let infoRow = app.buttons.containing(
            NSPredicate(format: "label CONTAINS[c] %@", "chicken")
        ).firstMatch
        if infoRow.waitForExistence(timeout: 3) {
            infoRow.tap()
            Thread.sleep(forTimeInterval: 1.0)
            takeScreenshot(named: "aha-07-ingredient-detail")
            // Dismiss the ingredient detail sheet.
            let sheetDone = app.buttons["Done"].firstMatch
            if sheetDone.waitForExistence(timeout: 2) { sheetDone.tap() }
        }

        // Finish onboarding (top-bar Skip always visible), then confirm the searched
        // food was auto-saved to History.
        let resultSkip = app.buttons["aha-result-skip"].firstMatch
        XCTAssertTrue(resultSkip.waitForExistence(timeout: 3), "result skip")
        resultSkip.tap()

        let historyTab = app.tabBars.buttons["History"]
        XCTAssertTrue(historyTab.waitForExistence(timeout: 10), "reached main app after onboarding")
        historyTab.tap()
        XCTAssertTrue(app.collectionViews["history-view"].waitForExistence(timeout: 5), "history view")
        let savedScan = app.buttons.containing(
            NSPredicate(format: "label CONTAINS[c] %@", "purina")
        ).firstMatch
        XCTAssertTrue(savedScan.waitForExistence(timeout: 5), "searched food auto-saved to history")
        takeScreenshot(named: "aha-08-history-saved")
    }

    /// The catalog text-search reached from the camera / Identify Product view:
    /// tap the search entry, run a fuzzy brand+protein query, pick a result, and
    /// confirm it lands on the normal results screen (same path as a barcode scan).
    func testScannerCatalogSearch() throws {
        launchSeeded()
        app.tabBars.buttons["Search"].firstMatch.tap()   // scanner ("Identify Product") tab

        let searchEntry = app.buttons["scanner-search-by-name"]
        XCTAssertTrue(searchEntry.waitForExistence(timeout: 5), "camera-view search entry missing")
        searchEntry.tap()

        let field = app.textFields["catalog-search-field"]
        XCTAssertTrue(field.waitForExistence(timeout: 5), "catalog search field missing")
        field.tap()
        field.typeText("purina chicken")

        let result = app.buttons.containing(
            NSPredicate(format: "label CONTAINS[c] %@", "purina")
        ).firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 8), "fuzzy search returned no result")
        takeScreenshot(named: "scanner-search-results")
        result.tap()

        let score = app.scrollViews["product-score-view"]
        XCTAssertTrue(score.waitForExistence(timeout: 10), "search did not route to results screen")
        takeScreenshot(named: "scanner-search-scored")
    }

    private func tapButton(_ label: String) {
        let button = app.buttons[label].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 6), "button '\(label)'")
        button.tap()
        Thread.sleep(forTimeInterval: 0.5)
    }

    private func tapIfExists(_ element: XCUIElement) {
        if element.waitForExistence(timeout: 2) {
            element.tap()
        }
    }

    /// First button whose accessibility label contains `text` (case-insensitive).
    /// Chips and group rows compose their label from title + example text, so exact
    /// matching misses them.
    private func containingButton(_ text: String) -> XCUIElement {
        app.buttons.containing(
            NSPredicate(format: "label CONTAINS[c] %@", text)
        ).firstMatch
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
