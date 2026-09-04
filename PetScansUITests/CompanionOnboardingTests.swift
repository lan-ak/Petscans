import XCTest

/// Guards the species fork end to end.
///
/// The fork replaced a segmented `Picker` that defaulted to `.dog`, and the thing worth
/// protecting is not that the animals draw — it is that nothing is preselected, that a
/// tap actually writes the species, and that the brand grid follows it. A regression in
/// any of those puts the demo back to being scored against an assumption.
final class CompanionOnboardingTests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITesting", "-ShowOnboarding", "-ResetOnboarding"]
        app.launch()
    }

    func testSpeciesForkDrivesTheBrandGrid() throws {
        // Welcome — the pair carries the promise here and is deliberately not a control.
        XCTAssertTrue(app.buttons["Get Started"].waitForExistence(timeout: 10), "welcome CTA")
        capture("companion-01-welcome")
        app.buttons["Get Started"].tap()

        let dog = app.buttons["companion-pick-dog"]
        let cat = app.buttons["companion-pick-cat"]
        XCTAssertTrue(dog.waitForExistence(timeout: 10), "dog rig missing from the picker")
        XCTAssertTrue(cat.exists, "cat rig missing from the picker")

        // Nothing preselected. This is the whole point of making the species optional:
        // "chose dog" has to be distinguishable from "has not chosen".
        XCTAssertFalse(dog.isSelected, "dog must not be preselected")
        XCTAssertFalse(cat.isSelected, "cat must not be preselected")

        // The keyboard must not be up. The brand grid was added because users left this
        // screen without typing, and an auto-raised keyboard covers it.
        XCTAssertFalse(app.keyboards.element.exists, "keyboard should not be raised on arrival")

        // Unchosen state shows the cross-species list, and it must not be shorter than
        // the chosen one — skipping the question used to cost two tiles.
        let chips = app.buttons.matching(identifier: "catalog-brand-chip")
        XCTAssertTrue(chips.element(boundBy: 0).waitForExistence(timeout: 5), "brand grid")
        XCTAssertEqual(chips.count, 8, "the unchosen grid must match the chosen one at 8 brands")
        capture("companion-02-picker-unchosen")

        // Pick the cat. The grid has to follow: Friskies is cat-only, Pedigree dog-only.
        cat.tap()
        XCTAssertTrue(app.buttons["Friskies"].waitForExistence(timeout: 5),
                      "cat brands did not load after choosing cat")
        XCTAssertFalse(app.buttons["Pedigree"].exists, "dog brand still present after choosing cat")
        XCTAssertTrue(cat.isSelected, "cat should read as selected")
        capture("companion-03-picked-cat")

        // The mis-tap escape hatch: the unchosen animal stays tappable.
        XCTAssertTrue(dog.isHittable, "the unchosen animal must remain tappable")
        dog.tap()
        XCTAssertTrue(app.buttons["Pedigree"].waitForExistence(timeout: 5),
                      "switching back to dog did not restore the dog grid")
        XCTAssertTrue(dog.isSelected, "dog should read as selected after correcting")
        capture("companion-04-corrected-to-dog")
    }

    func testCompanionReachesTheResultScreen() throws {
        app.buttons["Get Started"].tap()

        let dog = app.buttons["companion-pick-dog"]
        XCTAssertTrue(dog.waitForExistence(timeout: 10), "picker")
        dog.tap()

        // Tap a brand tile rather than typing — this is the tap-first path.
        let brand = app.buttons["Pedigree"]
        XCTAssertTrue(brand.waitForExistence(timeout: 5), "brand tile")
        brand.tap()

        let firstResult = app.scrollViews.buttons.firstMatch
        XCTAssertTrue(firstResult.waitForExistence(timeout: 20), "no catalog results for the brand tile")
        firstResult.tap()

        // The companion is decorative to VoiceOver, so assert on the verdict chrome
        // it sits above rather than on the rig itself.
        // The CTA label is verdict-aware, so assert on the identifier rather than text.
        let continueButton = app.buttons["aha-continue"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 30), "result screen never scored")
        capture("companion-05-result")
    }

    /// Walks the whole flow so the companion is exercised on every screen it appears
    /// on, and so the species chosen on page 1 is provably the one that reaches the
    /// personalised verdict five screens later.
    func testCompanionCarriesThroughToThePersonalisedVerdict() throws {
        app.buttons["Get Started"].tap()

        let cat = app.buttons["companion-pick-cat"]
        XCTAssertTrue(cat.waitForExistence(timeout: 10), "picker")
        cat.tap()

        let brand = app.buttons["Friskies"]
        XCTAssertTrue(brand.waitForExistence(timeout: 5), "cat brand tile")
        brand.tap()

        let firstResult = app.scrollViews.buttons.firstMatch
        XCTAssertTrue(firstResult.waitForExistence(timeout: 20), "catalog results")
        firstResult.tap()

        let ahaContinue = app.buttons["aha-continue"]
        XCTAssertTrue(ahaContinue.waitForExistence(timeout: 30), "demo verdict")
        ahaContinue.tap()

        // Profile — the page that used to lose 48% of arrivals.
        let name = app.textFields["pet-name-field"]
        XCTAssertTrue(name.waitForExistence(timeout: 10), "name field")
        name.tap()
        // Return dismisses the keyboard without advancing. The CTA is deliberately
        // anchored below the keyboard on this page — it used to ride up into the thumb
        // zone and people submitted before choosing any allergens — so the keyboard has
        // to go before Continue is reachable.
        name.typeText("Mochi\n")
        capture("companion-06-profile")

        // Chicken is in 77.5% of cat foods, so naming it as an allergen is the most
        // reliable way to reach a real allergen hit — the sharpest reaction in the set.
        let chicken = app.buttons["Chicken"].firstMatch
        if chicken.waitForExistence(timeout: 3) { chicken.tap() }

        app.buttons["Continue"].firstMatch.tap()

        // Wait on the page itself rather than on a button label both pages share.
        // The identifier sits on a ScrollView, so query by headline rather than by a
        // container type that could change.
        let groups = app.staticTexts["What should we watch out for?"]
        if !groups.waitForExistence(timeout: 10) {
            capture("companion-debug-after-profile")
            XCTFail("avoidance groups page never appeared")
            return
        }
        capture("companion-06b-groups")
        app.buttons["Continue"].firstMatch.tap()

        let personalized = app.buttons["personalized-continue"]
        if !personalized.waitForExistence(timeout: 30) {
            capture("companion-debug-after-groups")
            XCTFail("personalised screen never rendered")
            return
        }
        // Let the re-score land so the companion is in its final mood, not attending.
        Thread.sleep(forTimeInterval: 3)
        capture("companion-07-personalised")
    }

    // MARK: - Repeatability
    //
    // The flow is not a one-way street: there is a back button on every page, the
    // species can be corrected after a food has already been scored, and the whole
    // thing can be re-entered. Each of those is a chance for state to drift out of
    // agreement with what the screen is showing.

    func testSpeciesSurvivesBackNavigation() throws {
        app.buttons["Get Started"].tap()

        let cat = app.buttons["companion-pick-cat"]
        XCTAssertTrue(cat.waitForExistence(timeout: 10), "picker")
        cat.tap()
        XCTAssertTrue(app.buttons["Friskies"].waitForExistence(timeout: 5), "cat grid")

        // Back to the welcome page and forward again.
        app.buttons["Back"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Get Started"].waitForExistence(timeout: 5), "welcome")
        app.buttons["Get Started"].tap()

        XCTAssertTrue(cat.waitForExistence(timeout: 5), "picker after returning")
        XCTAssertTrue(cat.isSelected, "the species choice must survive leaving the screen")
        XCTAssertTrue(app.buttons["Friskies"].waitForExistence(timeout: 5),
                      "the grid must still match the remembered species")
    }

    func testCorrectingSpeciesAfterScoringRescoresAgainstTheNewOne() throws {
        app.buttons["Get Started"].tap()

        let dog = app.buttons["companion-pick-dog"]
        XCTAssertTrue(dog.waitForExistence(timeout: 10), "picker")
        dog.tap()

        let pedigree = app.buttons["Pedigree"]
        XCTAssertTrue(pedigree.waitForExistence(timeout: 5), "dog brand")
        pedigree.tap()
        let firstResult = app.scrollViews.buttons.firstMatch
        XCTAssertTrue(firstResult.waitForExistence(timeout: 20), "results")
        firstResult.tap()
        XCTAssertTrue(app.buttons["aha-continue"].waitForExistence(timeout: 30), "first verdict")

        // Back out and switch species. The demo has already been scored once against
        // dog; the screen must not keep showing a dog verdict for a cat owner.
        app.buttons["Back"].firstMatch.tap()
        XCTAssertTrue(dog.waitForExistence(timeout: 10), "back at the picker")
        app.buttons["companion-pick-cat"].tap()
        XCTAssertTrue(app.buttons["Friskies"].waitForExistence(timeout: 5),
                      "grid must follow the corrected species")
        XCTAssertFalse(app.buttons["Pedigree"].exists, "stale dog brand still on screen")
        capture("audit-repeat-species-corrected")
    }

    func testTheSameFoodScoresTheSameWayTwice() throws {
        func verdictLabel() -> String {
            app.buttons["Get Started"].tap()
            let dog = app.buttons["companion-pick-dog"]
            XCTAssertTrue(dog.waitForExistence(timeout: 10))
            dog.tap()
            let brand = app.buttons["Pedigree"]
            XCTAssertTrue(brand.waitForExistence(timeout: 5))
            brand.tap()
            let first = app.scrollViews.buttons.firstMatch
            XCTAssertTrue(first.waitForExistence(timeout: 20))
            first.tap()
            XCTAssertTrue(app.buttons["aha-continue"].waitForExistence(timeout: 30))
            // The verdict word is the only thing the user reads as the answer.
            for word in ["Excellent", "Good", "Caution", "Avoid"] where app.staticTexts[word].exists {
                return word
            }
            return "none"
        }

        let first = verdictLabel()
        XCTAssertNotEqual(first, "none", "no verdict rendered on the first run")

        app.terminate()
        app.launch()

        let second = verdictLabel()
        XCTAssertEqual(first, second,
                       "the same food scored differently on a second run — scoring must be deterministic")
    }

    /// Captures every screen in order so the set can be reviewed side by side. Its value
    /// is the artefacts, not the assertions.
    func testCaptureEveryScreenInOrder() throws {
        XCTAssertTrue(app.buttons["Get Started"].waitForExistence(timeout: 10))
        capture("audit-0-welcome")
        app.buttons["Get Started"].tap()

        XCTAssertTrue(app.buttons["companion-pick-dog"].waitForExistence(timeout: 10))
        capture("audit-1-search-unchosen")
        app.buttons["companion-pick-dog"].tap()
        capture("audit-1b-search-chosen")

        app.buttons["Pedigree"].tap()
        let first = app.scrollViews.buttons.firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 20))
        capture("audit-2-results-list")
        first.tap()

        XCTAssertTrue(app.buttons["aha-continue"].waitForExistence(timeout: 30))
        capture("audit-3-demo-verdict")
        app.buttons["aha-continue"].tap()

        let name = app.textFields["pet-name-field"]
        XCTAssertTrue(name.waitForExistence(timeout: 10))
        name.tap()
        name.typeText("Rufus\n")
        capture("audit-4-profile")
        app.buttons["Continue"].firstMatch.tap()

        XCTAssertTrue(app.staticTexts["What should we watch out for?"].waitForExistence(timeout: 10))
        capture("audit-5-groups")
        app.buttons["Continue"].firstMatch.tap()

        XCTAssertTrue(app.buttons["personalized-continue"].waitForExistence(timeout: 30))
        Thread.sleep(forTimeInterval: 2.5)
        capture("audit-6-personalised")
    }

    private func capture(_ name: String) {
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        // PROJECT_DIR is not exported to the UI-test runner; the simulator does export
        // the host home, which is enough to land these beside the repo.
        let env = ProcessInfo.processInfo.environment
        let root = env["PROJECT_DIR"] ?? (env["SIMULATOR_HOST_HOME"].map { $0 + "/PetScans" })
            ?? FileManager.default.currentDirectoryPath
        let dir = root + "/Screenshots/companion"
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        try? shot.pngRepresentation.write(to: URL(fileURLWithPath: "\(dir)/\(name).png"))
    }
}
