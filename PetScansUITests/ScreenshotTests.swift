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
    ///
    /// The float is the rating badge, which carries the number as of 1.4.5. It is the
    /// only thing on this screen that has to survive being shrunk to a search-results
    /// thumbnail, so it is what gets lifted out of the frame.
    func test01_HeroScore() throws {
        launchSeeded()
        // "Merrick" alone is no longer unique — the catalog-depth rows added for shot 5
        // include a Merrick chew scoring 46, and matching on the brand picked that up
        // instead of the hero. Pin to the product.
        openScan(brandOrName: "Texas Beef")
        Thread.sleep(forTimeInterval: 1.0)
        takeScreenshot(named: "01_HeroScore", floats: ["card": floatTarget("hero-rating")])
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

        // First card under "Other Warnings" is the BHA/BHT preservative flag — the
        // one carrying an FDA citation, and the most recognisable of the three.
        takeScreenshot(named: "02_UnsafeIngredients", floats: ["card": warningCard(at: 0)])
    }

    /// Shot 3 — the pet-specific allergen banner, the thing a generic scanner
    /// can't do. Top of the same Milk-Bone result.
    ///
    /// Before 1.4.5 this shot showed a generic "Avoid" badge and nothing else: the
    /// banner was gated on a pet name that a saved scan never carries, so the two
    /// allergens the app had found rendered nowhere. It renders now, and the banner
    /// is expanded here so the float can be the card that actually names the
    /// ingredient and the pet.
    func test03_AllergenAlert() throws {
        launchSeeded()
        openScan(brandOrName: "Milk-Bone")
        Thread.sleep(forTimeInterval: 1.0)

        let banner = floatTarget("allergen-banner")
        XCTAssertTrue(banner.waitForExistence(timeout: 5), "allergen banner missing on a scan with allergen flags")
        banner.tap()
        Thread.sleep(forTimeInterval: 0.6)

        takeScreenshot(named: "03_AllergenAlert", floats: ["card": warningCard(at: 0, in: banner)])
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

    /// Shot 5 — the shelf behind "30,000+ foods built in".
    ///
    /// This used to be three seeded rows under a caption claiming thirty thousand,
    /// which is a picture arguing against its own headline. The seeder now carries
    /// nine real catalog products scoring from 94 down to 0, so the list shows both
    /// depth and a spread rather than a near-empty screen.
    func test05_Library() throws {
        launchSeeded()
        app.tabBars.buttons["History"].tap()

        let historyView = app.collectionViews["history-view"]
        XCTAssertTrue(historyView.waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.6)

        let topRow = app.buttons.containing(
            NSPredicate(format: "label CONTAINS[c] 'ORIJEN'")
        ).firstMatch
        XCTAssertTrue(topRow.waitForExistence(timeout: 5), "catalog rows missing from History")
        takeScreenshot(named: "05_Library", floats: ["card": topRow])
    }

    /// Shot 6 — the independence claim. Yuka spends its last two slots on who it
    /// answers to rather than on what it does; this is the same slot, and the
    /// Scientific References screen is the evidence under it.
    ///
    /// The caption is supplied by the framing step. What this test has to guarantee
    /// is that the named sources are on screen and that one of them can be floated.
    func test06_Sources() throws {
        launchSeeded()
        app.tabBars.buttons["Settings"].tap()

        let references = app.buttons["Scientific References"].firstMatch
        XCTAssertTrue(references.waitForExistence(timeout: 5))
        references.tap()
        Thread.sleep(forTimeInterval: 0.6)

        let aafco = app.buttons.containing(
            NSPredicate(format: "label CONTAINS[c] 'AAFCO'")
        ).firstMatch
        XCTAssertTrue(aafco.waitForExistence(timeout: 5), "AAFCO source row missing")
        takeScreenshot(named: "06_Sources", floats: ["card": aafco])
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

        // Promise → straight into the demo. The flow is demo-first: nothing is asked
        // before the user has seen the app score a real food.
        tapButton("Get Started")

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
        XCTAssertTrue(ahaContinue.waitForExistence(timeout: 12), "demo result page rendered")
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

        // Into the question block, which now sits *after* the payoff rather than in
        // front of it.
        ahaContinue.tap()

        // Pet setup: name (required) + a common allergen, so the re-score on the plan
        // reveal has something to flip. The trailing \n fires the field's Done action,
        // dismissing the keyboard so the allergen chips below become hittable.
        let nameField = app.textFields["pet-name-field"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 6), "pet name field")
        nameField.tap()
        nameField.typeText("Max\n")
        // Chip / row accessibility labels include example text, so match on CONTAINS.
        tapIfExists(containingButton("chicken"))
        takeScreenshot(named: "aha-04-petsetup")
        tapButton("Continue")

        // Watch list (labels carry their example lists).
        tapIfExists(containingButton("Artificial colours"))
        tapIfExists(containingButton("Meat by-products"))
        takeScreenshot(named: "aha-05-groups")
        tapButton("Continue")

        // Plan reveal: the same food, re-scored against Max.
        let personalizedContinue = app.buttons["personalized-continue"]
        XCTAssertTrue(personalizedContinue.waitForExistence(timeout: 15), "personalised result screen rendered")
        takeScreenshot(named: "aha-06-personalized-result")
        personalizedContinue.tap()

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

    /// An element tagged with `accessibilityIdentifier` on a container. SwiftUI
    /// exposes those as `otherElements`, not as any of the leaf types.
    private func floatTarget(_ identifier: String) -> XCUIElement {
        app.otherElements[identifier].firstMatch
    }

    /// The nth `WarningFlagView` inside `container`, or inside the whole screen when
    /// no container is given.
    ///
    /// Scoping matters: an expanded allergen banner and the "Other Warnings" section
    /// both render `WarningFlagView`, and an unscoped query does not reliably return
    /// them in screen order — the first unscoped match on the Milk-Bone result is a
    /// card a full screen below the fold.
    private func warningCard(at index: Int, in container: XCUIElement? = nil) -> XCUIElement {
        let scope: XCUIElement = container ?? app
        return scope.otherElements.matching(identifier: "warning-flag").element(boundBy: index)
    }

    private func takeScreenshot(named name: String, floats: [String: XCUIElement] = [:]) {
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        // Also save to file system for easy access
        saveScreenshotToFile(screenshot: screenshot, name: name)
        saveFloatRects(floats, for: name)
    }

    /// Writes where each floatable card sits, normalised to the window, next to the
    /// PNG it came from.
    ///
    /// The framing step lifts one card out of the device shot and floats it over the
    /// composition — the move every Yuka screenshot makes, and the reason their
    /// screenshots stay readable at the 320x480 thumbnail the store serves in search
    /// results. Cropping happens in `Scripts/compose_marketing_shots.py` rather than
    /// here so that all image work lives in one place; this test only has to say
    /// *where*. Normalising to the window is what lets one set of coordinates serve
    /// every device size.
    private func saveFloatRects(_ floats: [String: XCUIElement], for name: String) {
        guard !floats.isEmpty else { return }

        let window = app.windows.firstMatch.frame
        guard window.width > 0, window.height > 0 else {
            XCTFail("no window frame to normalise \(name) against")
            return
        }

        var payload: [String: [String: CGFloat]] = [:]
        for (key, element) in floats {
            guard element.exists else {
                XCTFail("float target '\(key)' is not on screen for \(name)")
                continue
            }
            let frame = element.frame
            let x = (frame.minX - window.minX) / window.width
            let y = (frame.minY - window.minY) / window.height
            let w = frame.width / window.width
            let h = frame.height / window.height

            // An element that exists is not necessarily on screen — a card below the
            // fold reports a frame in the scroll view's coordinate space, and floating
            // a crop of empty pixels is the kind of thing that ships quietly.
            XCTAssertTrue(
                x >= -0.02 && y >= -0.02 && x + w <= 1.02 && y + h <= 1.02,
                "float target '\(key)' for \(name) is off screen: x=\(x) y=\(y) w=\(w) h=\(h)"
            )

            payload[key] = ["x": x, "y": y, "w": w, "h": h]
        }
        guard !payload.isEmpty else { return }

        let projectDir = ProcessInfo.processInfo.environment["PROJECT_DIR"] ?? FileManager.default.currentDirectoryPath
        let path = "\(projectDir)/Screenshots/\(name).floats.json"
        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]) else {
            XCTFail("could not encode float rects for \(name)")
            return
        }
        try? data.write(to: URL(fileURLWithPath: path))
        print("Float rects saved: \(path)")
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
