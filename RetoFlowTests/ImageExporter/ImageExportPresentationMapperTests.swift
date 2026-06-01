import XCTest
@testable import RetoFlow

@MainActor
final class ImageExportPresentationMapperTests: XCTestCase {
    func testValidationFailurePresentationUsesValidationMessage() {
        let mapper = ImageExportPresentationMapper()

        let presentation = mapper.makeValidationFailurePresentation(.invalid("输出目录不存在"))

        XCTAssertEqual(presentation.message, "输出目录不存在")
    }

    func testEmptySelectionPresentationUsesExpectedMessage() {
        let mapper = ImageExportPresentationMapper()

        let presentation = mapper.makeEmptySelectionPresentation()

        XCTAssertEqual(presentation.message, "请先选择要导出的图片")
    }

    func testCompletedPresentationFormatsSuccessSummary() {
        let mapper = ImageExportPresentationMapper()
        let summary = ExportBatchSummary(
            totalCount: 4,
            successCount: 4,
            failureCount: 0,
            targetConcurrency: 6,
            concurrencyReason: "test",
            wasCancelled: false
        )

        let presentation = mapper.makeCompletionPresentation(summary: summary, unfinishedCount: 0)

        XCTAssertEqual(presentation.alertMessage, "导出完成！\n成功: 4 个文件")
        XCTAssertEqual(presentation.debugSummary, "导出结束: success=4, fail=0")
    }

    func testCompletedPresentationFormatsMixedSummary() {
        let mapper = ImageExportPresentationMapper()
        let summary = ExportBatchSummary(
            totalCount: 5,
            successCount: 3,
            failureCount: 2,
            targetConcurrency: 6,
            concurrencyReason: "test",
            wasCancelled: false
        )

        let presentation = mapper.makeCompletionPresentation(summary: summary, unfinishedCount: 0)

        XCTAssertEqual(presentation.alertMessage, "导出完成。\n成功: 3 个\n失败: 2 个")
        XCTAssertEqual(presentation.debugSummary, "导出结束: success=3, fail=2")
    }

    func testCompletedPresentationFormatsCancelledSummary() {
        let mapper = ImageExportPresentationMapper()
        let summary = ExportBatchSummary(
            totalCount: 5,
            successCount: 2,
            failureCount: 1,
            targetConcurrency: 6,
            concurrencyReason: "test",
            wasCancelled: true
        )

        let presentation = mapper.makeCompletionPresentation(summary: summary, unfinishedCount: 2)

        XCTAssertEqual(presentation.alertMessage, "导出已取消。\n成功: 2 个\n失败: 1 个\n未完成: 2 个")
        XCTAssertEqual(presentation.debugSummary, "导出取消: success=2, fail=1, unfinished=2")
    }
}
