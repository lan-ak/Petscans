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

    // MARK: - Onboarding Screenshots

    func test01_WelcomeScreenshot() throws {
        app.launchArguments = ["-UITesting", "-ShowOnboarding"]
        app.launch()

        // Wait for welcome page to appear
        let welcomeView = app.otherElements["onboarding-welcome"]
        XCTAssertTrue(welcomeView.waitForExistence(timeout: 5))

        // Allow animations to complete
        Thread.sleep(forTimeInterval: 0.5)

        takeScreenshot(named: "01_Welcome")
    }

    func test02_PetSetupScreenshot() throws {
        app.launchArguments = ["-UITesting", "-ShowOnboarding"]
        app.launch()

        // Navigate through onboarding pages to pet setup (page 4)
        // Page 0: Welcome -> tap "Get Started"
        let getStartedButton = app.buttons["Get Started"]
        XCTAssertTrue(getStartedButton.waitForExistence(timeout: 5))
        getStartedButton.tap()

        // Page 1: Benefits 1 -> tap "Continue"
        Thread.sleep(forTimeInterval: 0.3)
        let continueButton1 = app.buttons["Continue"]
        XCTAssertTrue(continueButton1.waitForExistence(timeout: 5))
        continueButton1.tap()

        // Page 2: Benefits 2 -> tap "Continue"
        Thread.sleep(forTimeInterval: 0.3)
        let continueButton2 = app.buttons["Continue"]
        XCTAssertTrue(continueButton2.waitForExistence(timeout: 5))
        continueButton2.tap()

        // Page 3: Pet Setup
        Thread.sleep(forTimeInterval: 0.3)
        let petSetupView = app.otherElements["onboarding-pet-setup"]
        XCTAssertTrue(petSetupView.waitForExistence(timeout: 5))

        // Fill in pet name for a realistic screenshot
        let petNameField = app.textFields["Pet Name"]
        if petNameField.waitForExistence(timeout: 2) {
            petNameField.tap()
            petNameField.typeText("Max")
        }

        // Dismiss keyboard
        app.tap()
        Thread.sleep(forTimeInterval: 0.3)

        // Select some allergens for visual interest
        let chickenButton = app.buttons["Chicken"]
        if chickenButton.waitForExistence(timeout: 2) {
            chickenButton.tap()
        }

        let wheatButton = app.buttons["Wheat"]
        if wheatButton.waitForExistence(timeout: 2) {
            wheatButton.tap()
        }

        Thread.sleep(forTimeInterval: 0.3)
        takeScreenshot(named: "02_PetSetup")
    }

    // MARK: - Main App Screenshots

    func test03_ScannerScreenshot() throws {
        app.launchArguments = ["-UITesting", "-SkipOnboarding", "-MockScanner"]
        app.launch()

        // Scanner is the first tab, should be visible immediately
        let scannerView = app.otherElements["scanner-view"]
        XCTAssertTrue(scannerView.waitForExistence(timeout: 5))

        Thread.sleep(forTimeInterval: 0.5)
        takeScreenshot(named: "03_Scanner")
    }

    func test04_HistoryScreenshot() throws {
        app.launchArguments = ["-UITesting", "-SkipOnboarding", "-SeedScreenshotData"]
        app.launch()

        // Navigate to History tab
        let historyTab = app.tabBars.buttons["History"]
        XCTAssertTrue(historyTab.waitForExistence(timeout: 5))
        historyTab.tap()

        // Wait for history view to load with data
        let historyView = app.otherElements["history-view"]
        XCTAssertTrue(historyView.waitForExistence(timeout: 5))

        Thread.sleep(forTimeInterval: 0.5)
        takeScreenshot(named: "04_History")
    }

    func test05_ResultsScreenshot() throws {
        app.launchArguments = ["-UITesting", "-SkipOnboarding", "-SeedScreenshotData"]
        app.launch()

        // Navigate to History tab
        let historyTab = app.tabBars.buttons["History"]
        XCTAssertTrue(historyTab.waitForExistence(timeout: 5))
        historyTab.tap()

        Thread.sleep(forTimeInterval: 0.5)

        // Tap on the first scan to view details (shows ProductScoreView)
        let firstCell = app.cells.firstMatch
        if firstCell.waitForExistence(timeout: 5) {
            firstCell.tap()

            // Wait for product score view
            let scoreView = app.otherElements["product-score-view"]
            XCTAssertTrue(scoreView.waitForExistence(timeout: 5))

            Thread.sleep(forTimeInterval: 0.5)
            takeScreenshot(named: "05_Results")
        }
    }

    func test06_SettingsScreenshot() throws {
        app.launchArguments = ["-UITesting", "-SkipOnboarding", "-SeedScreenshotData"]
        app.launch()

        // Navigate to Settings tab
        let settingsTab = app.tabBars.buttons["Settings"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 5))
        settingsTab.tap()

        // Wait for settings view
        let settingsView = app.otherElements["settings-view"]
        XCTAssertTrue(settingsView.waitForExistence(timeout: 5))

        Thread.sleep(forTimeInterval: 0.3)
        takeScreenshot(named: "06_Settings")
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
