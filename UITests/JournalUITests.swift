import XCTest

@MainActor
final class JournalUITests: XCTestCase {
    func testCoreScreensAndGradeSave() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--demo"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Расписание"].waitForExistence(timeout: 15))
        capture("01-schedule", app)
        app.tabBars.buttons["Оценки"].tap()
        XCTAssertTrue(app.buttons["add-grade"].waitForExistence(timeout: 5))
        capture("02-grades", app)
        app.buttons["add-grade"].tap()
        let save = app.buttons["grade-save"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        XCTAssertTrue(save.isEnabled)
        save.tap()
        XCTAssertTrue(app.buttons["Отменить"].waitForExistence(timeout: 5))
        app.buttons["Отменить"].tap()
        app.tabBars.buttons["Пропуски"].tap()
        XCTAssertTrue(app.navigationBars["Пропуски"].waitForExistence(timeout: 5))
        capture("03-absences", app)
        let month = app.descendants(matching: .any).matching(identifier: "month-limit").firstMatch
        if !month.waitForExistence(timeout: 5) { print(app.debugDescription) }
        XCTAssertTrue(month.exists)
        app.buttons["settings-button"].tap()
        XCTAssertTrue(app.navigationBars["Настройки"].waitForExistence(timeout: 5))
        app.buttons["Готово"].tap()
    }

    func testLargeTextAndLandscape() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--demo", "--dark", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Оценки"].waitForExistence(timeout: 15))
        app.tabBars.buttons["Оценки"].tap()
        capture("dark-large-text", app)
        app.buttons["add-grade"].tap()
        XCTAssertTrue(app.buttons["grade-save"].waitForExistence(timeout: 5))
        app.buttons["Отмена"].tap()
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(app.tabBars.buttons["Расписание"].exists)
        XCUIDevice.shared.orientation = .portrait
    }

    private func capture(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
