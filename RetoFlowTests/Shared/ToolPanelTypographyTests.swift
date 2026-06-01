import XCTest
@testable import RetoFlow

@MainActor
final class ToolPanelTypographyTests: XCTestCase {
    func testPanelTitleSizeIsCorrect() {
        XCTAssertEqual(ToolPanelTypography.panelTitleSize, 16)
    }

    func testSupportingTextSizeIsCorrect() {
        XCTAssertEqual(ToolPanelTypography.supportingTextSize, 11)
    }

    func testCompactSupportingTextSizeIsCorrect() {
        XCTAssertEqual(ToolPanelTypography.compactSupportingTextSize, 11)
    }

    func testDropZoneIconSizeIsCorrect() {
        XCTAssertEqual(ToolPanelTypography.dropZoneIconSize, 32)
    }

    func testComposedFontsAreNotNil() {
        // Verify composed Font properties exist and are constructible.
        _ = ToolPanelTypography.panelTitle
        _ = ToolPanelTypography.panelBody
        _ = ToolPanelTypography.supporting
        _ = ToolPanelTypography.compactSupporting
    }
}
