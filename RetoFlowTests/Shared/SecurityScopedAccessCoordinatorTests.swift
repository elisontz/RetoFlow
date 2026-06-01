import XCTest
@testable import RetoFlow

private final class AccessRecorder: @unchecked Sendable {
    var started: [URL] = []
    var stopped: [URL] = []
}

final class SecurityScopedAccessCoordinatorTests: XCTestCase {
    func testWithAccessUsesNearestRegisteredAncestorForDescendantURL() {
        let selectedFolder = URL(fileURLWithPath: "/tmp/library", isDirectory: true)
        let nestedFile = selectedFolder.appendingPathComponent("nested/photo.jpg")
        let recorder = AccessRecorder()
        let coordinator = SecurityScopedAccessCoordinator(
            startAccessing: { url in
                recorder.started.append(url)
                return true
            },
            stopAccessing: { url in
                recorder.stopped.append(url)
            }
        )

        coordinator.register(url: selectedFolder)

        let result = coordinator.withAccess(to: nestedFile) {
            "ok"
        }

        XCTAssertEqual(result, "ok")
        XCTAssertEqual(recorder.started, [selectedFolder.standardizedFileURL])
        XCTAssertEqual(recorder.stopped, [selectedFolder.standardizedFileURL])
    }

    func testWithAccessDeduplicatesRootsAcrossMultipleDescendants() {
        let selectedFolder = URL(fileURLWithPath: "/tmp/library", isDirectory: true)
        let imageURL = selectedFolder.appendingPathComponent("nested/photo.jpg")
        let outputURL = selectedFolder.appendingPathComponent("nested/output/photo.jpg")
        let recorder = AccessRecorder()
        let coordinator = SecurityScopedAccessCoordinator(
            startAccessing: { url in
                recorder.started.append(url)
                return true
            },
            stopAccessing: { url in
                recorder.stopped.append(url)
            }
        )

        coordinator.register(url: selectedFolder)

        coordinator.withAccess(to: [imageURL, outputURL]) {}

        XCTAssertEqual(recorder.started, [selectedFolder.standardizedFileURL])
        XCTAssertEqual(recorder.stopped, [selectedFolder.standardizedFileURL])
    }
}
