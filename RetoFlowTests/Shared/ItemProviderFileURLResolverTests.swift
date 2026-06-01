import XCTest
import UniformTypeIdentifiers
@testable import RetoFlow

final class ItemProviderFileURLResolverTests: XCTestCase {
    func testResolveReturnsURLWhenProviderLoadsFileURLProvider() async throws {
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        guard let provider = NSItemProvider(contentsOf: fileURL) else {
            XCTFail("Failed to create item provider")
            return
        }

        let resolver = ItemProviderFileURLResolver()

        let resolvedURL = await resolver.resolve(from: provider)

        XCTAssertEqual(resolvedURL, fileURL)
    }

    func testResolveReturnsURLWhenProviderLoadsDataRepresentation() async throws {
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let provider = NSItemProvider()
        provider.registerDataRepresentation(
            forTypeIdentifier: UTType.fileURL.identifier,
            visibility: .all
        ) { completion in
            completion(fileURL.dataRepresentation, nil)
            return nil
        }

        let resolver = ItemProviderFileURLResolver()

        let resolvedURL = await resolver.resolve(from: provider)

        XCTAssertEqual(resolvedURL, fileURL)
    }

    func testResolveRegistersResolvedURLForSessionAccess() async throws {
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let provider = NSItemProvider()
        provider.registerDataRepresentation(
            forTypeIdentifier: UTType.fileURL.identifier,
            visibility: .all
        ) { completion in
            completion(fileURL.dataRepresentation, nil)
            return nil
        }
        let accessSpy = TestSecurityScopedAccessSpy()
        let resolver = ItemProviderFileURLResolver(accessCoordinator: accessSpy)

        let resolvedURL = await resolver.resolve(from: provider)

        XCTAssertEqual(resolvedURL, fileURL)
        XCTAssertEqual(accessSpy.registeredURLs, [fileURL.standardizedFileURL])
    }

    func testResolveReturnsNilWhenProviderHasNoFileURLRepresentation() async throws {
        let provider = NSItemProvider()

        let resolver = ItemProviderFileURLResolver()

        let resolvedURL = await resolver.resolve(from: provider)

        XCTAssertNil(resolvedURL)
    }
}
