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
        XCTAssertTrue(app.staticTexts["За месяц"].waitForExistence(timeout: 5) || app.otherElements.matching(NSPredicate(format: "label CONTAINS %@", "За месяц")).firstMatch.exists)
        app.buttons["settings-button"].tap()
        XCTAssertTrue(app.navigationBars["Настройки"].waitForExistence(timeout: 5))
        app.buttons["Готово"].tap()
    }

    func testLargeTextAndLandscape() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--demo", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Оценки"].waitForExistence(timeout: 15))
        app.tabBars.buttons["Оценки"].tap()
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
