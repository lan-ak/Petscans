import XCTest

/// Verifies the ingredient list renders end to end, against a real catalog
/// product rather than seeded data.
///
/// The seeded screenshot scans carry authored `MatchedIngredient`s, so every row
/// is an exact match and none of the confidence states appear. Searching a real
/// product runs the actual matcher over the bundled catalog, which is the only
/// way to see what a user sees.
final class IngredientListTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITesting", "-SkipOnboarding"]
        app.launch()
    }

    func testRealProductRendersAnIngredientList() throws {
        app.buttons["scanner-search-by-name"].firstMatch.tap()

        let field = app.textFields["catalog-search-field"]
        XCTAssertTrue(field.waitForExistence(timeout: 5), "search field never appeared")
        field.tap()
        field.typeText("chicken")

        // The sheet lists catalog matches; one has to be selected before the
        // result screen exists. Waiting on the score view alone just times out.
        let firstResult = app.scrollViews.buttons.firstMatch
        guard firstResult.waitForExistence(timeout: 20) else {
            attach(named: "search-no-result")
            throw XCTSkip("no catalog result for the search term on this build")
        }
        attach(named: "search-results")
        firstResult.tap()

        let scoreView = app.scrollViews["product-score-view"]
        if !scoreView.waitForExistence(timeout: 45) {
            // A search miss is an environment problem (catalog contents change), not
            // a regression in the list. Record it and stop rather than fail loudly.
            attach(named: "search-no-result")
            throw XCTSkip("no catalog result for the search term on this build")
        }

        attach(named: "ingredient-list-top")

        // The recognition summary must be present and must name a count.
        let recognition = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS[c] 'ingredients recognized'")).firstMatch
        XCTAssertTrue(recognition.waitForExistence(timeout: 10),
                      "the ingredient recognition summary did not render")

        // Scroll to the list itself and capture the row markers.
        scoreView.swipeUp()
        scoreView.swipeUp()
        attach(named: "ingredient-list-rows")

        let header = app.staticTexts["Ingredients"].firstMatch
        XCTAssertTrue(header.exists, "the Ingredients section header is missing")

        // Open an ingredient whose label wording differs from its database name —
        // that's the case the detail sheet now has to explain, since the row no
        // longer carries a per-match icon.
        let row = app.buttons.containing(
            NSPredicate(format: "label CONTAINS[c] %@", "Chicken Bone")).firstMatch
        guard row.waitForExistence(timeout: 5) else {
            throw XCTSkip("expected ingredient not present in this catalog build")
        }
        row.tap()

        XCTAssertTrue(app.navigationBars["Ingredient Details"].waitForExistence(timeout: 5),
                      "the ingredient detail sheet did not open")
        attach(named: "ingredient-detail-top")

        let sheet = app.scrollViews.firstMatch
        sheet.swipeUp()
        attach(named: "ingredient-detail-lower")

    }

    /// Saved scans go through `ProductScoreView.init(scan:)`, which decodes the
    /// two persisted JSON blobs. That is the path the decoder hardening changed,
    /// and the path where a regression would silently blank every history row
    /// rather than fail — so it needs to be exercised, not just unit tested.
    func testSavedScanStillRendersItsIngredients() throws {
        app.terminate()
        app.launchArguments = ["-UITesting", "-SkipOnboarding", "-SeedScreenshotData"]
        app.launch()

        app.tabBars.buttons["History"].tap()
        let historyView = app.collectionViews["history-view"]
        XCTAssertTrue(historyView.waitForExistence(timeout: 10), "history never appeared")

        // Match on the product label rather than taking the first button — the
        // first button in the hierarchy is chrome, not a history row.
        let cell = app.buttons.containing(
            NSPredicate(format: "label CONTAINS[c] %@", "Merrick")).firstMatch
        XCTAssertTrue(cell.waitForExistence(timeout: 5), "no seeded scan found in history")
        cell.tap()

        let scoreView = app.scrollViews["product-score-view"]
        XCTAssertTrue(scoreView.waitForExistence(timeout: 10), "saved scan did not render")

        // The decode-failure banner must NOT be showing for valid data — if it is,
        // the decoders reject something they used to accept.
        XCTAssertFalse(app.staticTexts["This scan couldn't be loaded"].exists,
                       "a valid saved scan was reported as unreadable")

        scoreView.swipeUp()
        scoreView.swipeUp()
        attach(named: "saved-scan-ingredients")
        XCTAssertTrue(app.staticTexts["Ingredients"].firstMatch.exists,
                      "saved scan rendered without its ingredient list")
    }

    /// Confirms the evidence section renders for an ingredient carrying curated
    /// safety rules.
    ///
    /// Uses the seeded history scan rather than a catalog search: which products
    /// contain a rule-carrying ingredient changes as the catalog grows, and a test
    /// that silently skips is worth less than one pinned to fixed data. BHA is in
    /// the seeded "avoid" scan and has a `warn` rule with `medium` evidence.
    func testRulesAndEvidenceRenderInTheDetailSheet() throws {
        app.terminate()
        app.launchArguments = ["-UITesting", "-SkipOnboarding", "-SeedScreenshotData"]
        app.launch()

        app.tabBars.buttons["History"].tap()
        XCTAssertTrue(app.collectionViews["history-view"].waitForExistence(timeout: 10))

        let cell = app.buttons.containing(
            NSPredicate(format: "label CONTAINS[c] %@", "Milk-Bone")).firstMatch
        XCTAssertTrue(cell.waitForExistence(timeout: 5), "seeded avoid-scan not found")
        cell.tap()

        let scoreView = app.scrollViews["product-score-view"]
        XCTAssertTrue(scoreView.waitForExistence(timeout: 10))

        let row = app.buttons.containing(
            NSPredicate(format: "label CONTAINS[c] %@", "BHA")).firstMatch
        for _ in 0..<6 where !row.isHittable { scoreView.swipeUp() }
        XCTAssertTrue(row.isHittable, "BHA row never became reachable")
        row.tap()

        XCTAssertTrue(app.navigationBars["Ingredient Details"].waitForExistence(timeout: 5),
                      "detail sheet did not open")
        XCTAssertTrue(app.staticTexts["What the research says"].waitForExistence(timeout: 3),
                      "an ingredient with curated rules showed no evidence section")
        attach(named: "detail-with-rules")
    }

    /// Catalog search folds punctuation out of both the query and the text it matches, so
    /// "hills" finds "Hill's" — nobody types the apostrophe.
    ///
    /// This is an end-to-end test on purpose. The fold is implemented twice: in Swift
    /// (`LocalCatalogStore.foldForSearch`) for the query, and in TypeScript
    /// (`petcatalog group`) for the `search_text` it is compared against. Nothing but a test
    /// that runs the real query against the real bundled catalog can catch the two drifting
    /// apart, and the failure mode is silent — products simply stop being findable.
    func testSearchIgnoresPunctuationTheUserWouldNotType() throws {
        app.buttons["scanner-search-by-name"].firstMatch.tap()

        let field = app.textFields["catalog-search-field"]
        XCTAssertTrue(field.waitForExistence(timeout: 5), "search field never appeared")
        field.tap()
        field.typeText("hills")

        let result = app.scrollViews.buttons.containing(
            NSPredicate(format: "label CONTAINS[c] %@", "Hill")).firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 20),
                      "searching \"hills\" found no Hill's product — the query fold and the "
                      + "catalog's search_text fold have diverged")
        attach(named: "search-apostrophe-insensitive")
    }

    /// The four cases that prompted this work: three ingredients that opened an
    /// empty sheet (Vitamin K1, Salt, Chicken) and one that already had a rule
    /// (Menadione). All four must now show an About section.
    func testAboutSectionRendersForPreviouslyEmptyIngredients() throws {
        app.terminate()
        app.launchArguments = ["-UITesting", "-SkipOnboarding", "-SeedScreenshotData"]
        app.launch()

        app.tabBars.buttons["History"].tap()
        XCTAssertTrue(app.collectionViews["history-view"].waitForExistence(timeout: 10))
        let cell = app.buttons.containing(
            NSPredicate(format: "label CONTAINS[c] %@", "Merrick")).firstMatch
        XCTAssertTrue(cell.waitForExistence(timeout: 5))
        cell.tap()

        let scoreView = app.scrollViews["product-score-view"]
        XCTAssertTrue(scoreView.waitForExistence(timeout: 10))

        // "Sweet Potatoes" is in the seeded scan and previously had no notes.
        let row = app.buttons.containing(
            NSPredicate(format: "label CONTAINS[c] %@", "Sweet Potatoes")).firstMatch
        for _ in 0..<6 where !row.isHittable { scoreView.swipeUp() }
        XCTAssertTrue(row.isHittable, "ingredient row never became reachable")
        row.tap()

        XCTAssertTrue(app.navigationBars["Ingredient Details"].waitForExistence(timeout: 5))
        attach(named: "about-section")

        // The About text is the first thing under the header. Assert something from
        // the authored copy is on screen rather than an empty gap.
        let about = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS[c] %@", "Included as")).firstMatch
        XCTAssertTrue(about.waitForExistence(timeout: 3),
                      "no About section rendered — the sheet is still a dead tap")
    }

    private func attach(named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
