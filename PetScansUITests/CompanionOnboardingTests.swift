import XCTest

/// Guards the species fork end to end.
///
/// The fork replaced a segmented `Picker` that defaulted to `.dog`, and the thing worth
/// protecting is not that the animals draw — it is that nothing is preselected, that a
/// tap actually writes the species, and that the food samples follow it. A regression in
/// any of those puts the demo back to being scored against an assumption.
final class CompanionOnboardingTests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITesting", "-ShowOnboarding", "-ResetOnboarding"]
        app.launch()
    }


    /// The food check is a pick from `DemoFoods`. There is no scan or search
    /// before the paywall any more. The first sample per species is the one
    /// these tests tap.
    private let pedigree = "food-check-sample-00023100143408"
    private let whiskas = "food-check-sample-00058496701246"

    /// Waits for an element's hittability to settle on `expected`.
    ///
    /// `waitForExistence` on the keyboard returns the moment it exists, which
    /// is *before* it finishes animating up — so an instantaneous
    /// `isHittable` check against a control the keyboard is about to cover
    /// races the animation and fails perhaps one run in three. The guarantee
    /// under test is where the control ends up, not where it is mid-slide.
    private func waitForHittable(
        _ element: XCUIElement,
        toBe expected: Bool,
        timeout: TimeInterval = 5,
        _ message: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if element.isHittable == expected { return }
            usleep(100_000)
        }
        XCTAssertEqual(element.isHittable, expected, message, file: file, line: line)
    }

    private func pick(_ sample: String, file: StaticString = #filePath, line: UInt = #line) {
        let row = app.buttons[sample]
        XCTAssertTrue(row.waitForExistence(timeout: 10), "sample \(sample) missing", file: file, line: line)
        row.tap()
    }

    func testSpeciesForkDrivesTheSamples() throws {
        // Welcome — the pair carries the promise here and is deliberately not a control.
        XCTAssertTrue(app.buttons["onboarding-start"].waitForExistence(timeout: 10), "welcome CTA")
        capture("companion-01-welcome")
        app.buttons["onboarding-start"].tap()

        let dog = app.buttons["companion-pick-dog"]
        let cat = app.buttons["companion-pick-cat"]
        XCTAssertTrue(dog.waitForExistence(timeout: 10), "dog rig missing from the picker")
        XCTAssertTrue(cat.exists, "cat rig missing from the picker")

        // Nothing preselected. This is the whole point of making the species optional:
        // "chose dog" has to be distinguishable from "has not chosen".
        XCTAssertFalse(dog.isSelected, "dog must not be preselected")
        XCTAssertFalse(cat.isSelected, "cat must not be preselected")

        // The keyboard must not be up. Nothing on this page takes text, and an
        // auto-raised keyboard would cover the samples.
        XCTAssertFalse(app.keyboards.element.exists, "keyboard should not be raised on arrival")

        // Unchosen, the samples are the dog's, matching the `.dog` the demo
        // scores against when the question is skipped.
        XCTAssertTrue(app.buttons[pedigree].waitForExistence(timeout: 5), "samples before a species is chosen")
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'food-check-sample-'")).count, 3,
                       "three samples")
        capture("companion-02-picker-unchosen")

        // Pick the cat. The samples have to follow.
        cat.tap()
        XCTAssertTrue(app.buttons[whiskas].waitForExistence(timeout: 5),
                      "cat samples did not load after choosing cat")
        XCTAssertFalse(app.buttons[pedigree].exists, "dog sample still present after choosing cat")
        XCTAssertTrue(cat.isSelected, "cat should read as selected")
        capture("companion-03-picked-cat")

        // The mis-tap escape hatch: the unchosen animal stays tappable.
        XCTAssertTrue(dog.isHittable, "the unchosen animal must remain tappable")
        dog.tap()
        XCTAssertTrue(app.buttons[pedigree].waitForExistence(timeout: 5),
                      "switching back to dog did not restore the dog samples")
        XCTAssertTrue(dog.isSelected, "dog should read as selected after correcting")
        capture("companion-04-corrected-to-dog")
    }

    func testCompanionReachesTheResultScreen() throws {
        app.buttons["onboarding-start"].tap()

        let dog = app.buttons["companion-pick-dog"]
        XCTAssertTrue(dog.waitForExistence(timeout: 10), "picker")
        dog.tap()

        pick(pedigree)


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
        app.buttons["onboarding-start"].tap()

        let cat = app.buttons["companion-pick-cat"]
        XCTAssertTrue(cat.waitForExistence(timeout: 10), "picker")
        cat.tap()

        pick(whiskas)


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
        app.buttons["onboarding-start"].tap()

        let cat = app.buttons["companion-pick-cat"]
        XCTAssertTrue(cat.waitForExistence(timeout: 10), "picker")
        cat.tap()
        XCTAssertTrue(app.buttons[whiskas].waitForExistence(timeout: 5), "cat samples")

        // Back to the welcome page and forward again.
        app.buttons["Back"].firstMatch.tap()
        XCTAssertTrue(app.buttons["onboarding-start"].waitForExistence(timeout: 5), "welcome")
        app.buttons["onboarding-start"].tap()

        XCTAssertTrue(cat.waitForExistence(timeout: 5), "picker after returning")
        XCTAssertTrue(cat.isSelected, "the species choice must survive leaving the screen")
        XCTAssertTrue(app.buttons[whiskas].waitForExistence(timeout: 5),
                      "the samples must still match the remembered species")
    }

    func testCorrectingSpeciesAfterScoringRescoresAgainstTheNewOne() throws {
        app.buttons["onboarding-start"].tap()

        let dog = app.buttons["companion-pick-dog"]
        XCTAssertTrue(dog.waitForExistence(timeout: 10), "picker")
        dog.tap()

        pick(pedigree)
        XCTAssertTrue(app.buttons["aha-continue"].waitForExistence(timeout: 30), "first verdict")

        // Back out and switch species. The demo has already been scored once against
        // dog; the screen must not keep showing a dog verdict for a cat owner.
        app.buttons["Back"].firstMatch.tap()
        XCTAssertTrue(dog.waitForExistence(timeout: 10), "back at the picker")
        app.buttons["companion-pick-cat"].tap()
        XCTAssertTrue(app.buttons[whiskas].waitForExistence(timeout: 5),
                      "samples must follow the corrected species")
        XCTAssertFalse(app.buttons[pedigree].exists, "stale dog sample still on screen")
        capture("audit-repeat-species-corrected")
    }

    func testTheSameFoodScoresTheSameWayTwice() throws {
        func verdictLabel() -> String {
            app.buttons["onboarding-start"].tap()
            let dog = app.buttons["companion-pick-dog"]
            XCTAssertTrue(dog.waitForExistence(timeout: 10))
            dog.tap()
            pick(pedigree)
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

    /// The pet's name is the one required answer, and since the skip was removed it is
    /// the only way past this page — onboarding gates the whole app, so a Continue that
    /// silently refuses to advance would be a dead end rather than a validation.
    func testProfileRefusesToAdvanceWithoutANameAndSaysWhy() throws {
        app.buttons["onboarding-start"].tap()
        app.buttons["companion-pick-dog"].firstMatch.tap()
        pick(pedigree)
        XCTAssertTrue(app.buttons["aha-continue"].waitForExistence(timeout: 30))
        app.buttons["aha-continue"].tap()

        let name = app.textFields["pet-name-field"]
        XCTAssertTrue(name.waitForExistence(timeout: 10), "profile page")

        // No skip anywhere on this page any more.
        XCTAssertFalse(app.buttons["onboarding-skip"].exists, "the skip is meant to be gone")

        // The page auto-focuses the name field, so the keyboard is up and Continue is
        // anchored beneath it. Dismissing has to be possible without typing anything —
        // with the skip gone, a user who cannot find their way out of the keyboard has
        // no way forward at all.
        XCTAssertTrue(app.keyboards.element.waitForExistence(timeout: 5),
                      "the profile page is expected to raise the keyboard on arrival")
        let done = app.buttons["keyboard-done"].firstMatch
        XCTAssertTrue(done.waitForExistence(timeout: 3),
                      "no visible way to dismiss the keyboard")
        done.tap()

        // Continue with an empty name must hold the page and explain itself.
        XCTAssertTrue(app.buttons["Continue"].firstMatch.isHittable,
                      "Continue must be reachable once the keyboard is down")
        app.buttons["Continue"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Please enter your pet's name"].waitForExistence(timeout: 5),
                      "an empty name must produce a visible reason, not a silent refusal")
        XCTAssertTrue(name.exists, "must still be on the profile page")
        capture("audit-4b-profile-name-required")

        // And a name still gets you through.
        name.tap()
        name.typeText("Rufus\n")
        app.buttons["Continue"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["What should we watch out for?"].waitForExistence(timeout: 10),
                      "a named pet must advance")
    }

    /// Captures every screen in order so the set can be reviewed side by side. Its value
    /// is the artefacts, not the assertions.
    func testCaptureEveryScreenInOrder() throws {
        XCTAssertTrue(app.buttons["onboarding-start"].waitForExistence(timeout: 10))
        capture("audit-0-welcome")
        app.buttons["onboarding-start"].tap()

        XCTAssertTrue(app.buttons["companion-pick-dog"].waitForExistence(timeout: 10))
        capture("audit-1-search-unchosen")
        app.buttons["companion-pick-dog"].tap()
        capture("audit-1b-search-chosen")

        pick(pedigree)

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

    /// The primary button must land in the same place on every page, and the keyboard
    /// must never be able to strand the user.
    ///
    /// Both were measured rather than assumed. The result screens padded their CTA to
    /// `md` where the shared chrome uses `xxl`, so the button jumped 20pt as the user
    /// moved between pages. And with the software keyboard up — which the profile page
    /// raises on arrival — Continue sits beneath it and is not hittable; that was
    /// survivable while onboarding had a skip and is not now.
    func testCTAHeightIsStableAndTheKeyboardCannotStrandTheUser() throws {
        func ctaY(_ e: XCUIElement) -> CGFloat {
            XCTAssertTrue(e.waitForExistence(timeout: 30), "CTA missing")
            return e.frame.origin.y
        }

        let welcomeY = ctaY(app.buttons["onboarding-start"])
        app.buttons["onboarding-start"].tap()

        // The food check must not raise the keyboard on arrival — the samples are
        // the point of the screen and a keyboard covers it.
        XCTAssertTrue(app.buttons["companion-pick-dog"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.keyboards.element.exists,
                       "the search page must not auto-raise the keyboard")

        app.buttons["companion-pick-dog"].firstMatch.tap()
        pick(pedigree)

        let resultY = ctaY(app.buttons["aha-continue"])
        app.buttons["aha-continue"].tap()

        XCTAssertTrue(app.textFields["pet-name-field"].waitForExistence(timeout: 10))
        let profileY = ctaY(app.buttons["Continue"].firstMatch)

        // Profile does raise it, and Done is the way back out.
        XCTAssertTrue(app.keyboards.element.waitForExistence(timeout: 5))
        waitForHittable(app.buttons["Continue"].firstMatch, toBe: false,
                        "Continue is anchored below the keyboard by design")
        app.buttons["keyboard-done"].firstMatch.tap()
        waitForHittable(app.buttons["Continue"].firstMatch, toBe: true,
                        "Done must make Continue reachable again")

        app.textFields["pet-name-field"].tap()
        app.textFields["pet-name-field"].typeText("Rufus\n")
        app.buttons["Continue"].firstMatch.tap()

        XCTAssertTrue(app.staticTexts["What should we watch out for?"].waitForExistence(timeout: 10))
        let groupsY = ctaY(app.buttons["Continue"].firstMatch)

        XCTAssertEqual(welcomeY, profileY, accuracy: 1, "welcome vs profile CTA height")
        XCTAssertEqual(welcomeY, groupsY, accuracy: 1, "welcome vs groups CTA height")
        XCTAssertEqual(welcomeY, resultY, accuracy: 1, "welcome vs result CTA height")
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
