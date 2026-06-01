import XCTest
@testable import RetoFlow

final class SafeOperationReleaseCopyTests: XCTestCase {
    func testDestructiveModulesMentionTrashOrSkipDefaults() {
        XCTAssertTrue(SafeOperationReleaseCopy.rawFinderSafetyNotice.contains("默认跳过"))
        XCTAssertTrue(SafeOperationReleaseCopy.rawFinderConfirmationMessage.contains("废纸篓"))
        XCTAssertTrue(SafeOperationReleaseCopy.organizerSafetyNotice.contains("默认跳过"))
        XCTAssertTrue(SafeOperationReleaseCopy.renamerSafetyNotice.contains("先预览后执行"))
    }

    func testExporterRequiresOutputDirectoryAndNoOverwriteByDefault() {
        XCTAssertEqual(
            SafeOperationReleaseCopy.exporterSafetyNotice,
            "导出前请先选择输出位置；默认不会覆盖同名文件。"
        )
    }

    func testReleaseCopyMentionsPerTaskSummary() {
        XCTAssertTrue(SafeOperationReleaseCopy.sharedTaskSummaryNotice.contains("任务摘要"))
        XCTAssertTrue(SafeOperationReleaseCopy.aboutSafetyOverview.contains("任务摘要"))
    }
}
