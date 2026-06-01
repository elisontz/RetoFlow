import XCTest
@testable import RetoFlow

@MainActor
final class ExportConfigurationStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var store: ExportConfigurationStore!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: #file)
        defaults.removePersistentDomain(forName: #file)
        store = ExportConfigurationStore(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: #file)
        defaults = nil
        store = nil
        super.tearDown()
    }

    func testLoadReturnsDefaultExportConfigurationWhenNothingPersisted() {
        let outputDirectory = URL(fileURLWithPath: "/tmp/export-output", isDirectory: true)

        let configuration = store.load(defaultOutputDirectory: outputDirectory)

        XCTAssertNil(configuration.maxWidth)
        XCTAssertNil(configuration.maxHeight)
        XCTAssertNil(configuration.maxLongEdge)
        XCTAssertEqual(configuration.maxShortEdge, 2500)
        XCTAssertEqual(configuration.maxFileSizeBytes, 5 * 1024 * 1024)
        XCTAssertEqual(configuration.outputDirectory, outputDirectory)
        XCTAssertFalse(configuration.overwriteExisting)
        XCTAssertTrue(configuration.preserveMetadata)
        XCTAssertTrue(configuration.createSubfolder)
        XCTAssertEqual(configuration.subfolderSuffix, "_小图")
    }

    func testSaveAndLoadPersistExportParametersButNotOutputDirectory() {
        let savedConfiguration = ExportConfiguration(
            maxWidth: 1600,
            maxHeight: nil,
            maxLongEdge: nil,
            maxShortEdge: nil,
            maxFileSizeBytes: 2 * 1024 * 1024,
            outputDirectory: URL(fileURLWithPath: "/tmp/should-not-persist", isDirectory: true),
            overwriteExisting: true,
            preserveMetadata: false,
            createSubfolder: false,
            subfolderSuffix: "_导出"
        )
        let loadedOutputDirectory = URL(fileURLWithPath: "/tmp/runtime-default", isDirectory: true)

        store.save(savedConfiguration)
        let loadedConfiguration = store.load(defaultOutputDirectory: loadedOutputDirectory)

        XCTAssertEqual(loadedConfiguration.maxWidth, 1600)
        XCTAssertNil(loadedConfiguration.maxHeight)
        XCTAssertNil(loadedConfiguration.maxLongEdge)
        XCTAssertNil(loadedConfiguration.maxShortEdge)
        XCTAssertEqual(loadedConfiguration.maxFileSizeBytes, 2 * 1024 * 1024)
        XCTAssertEqual(loadedConfiguration.outputDirectory, loadedOutputDirectory)
        XCTAssertTrue(loadedConfiguration.overwriteExisting)
        XCTAssertFalse(loadedConfiguration.preserveMetadata)
        XCTAssertFalse(loadedConfiguration.createSubfolder)
        XCTAssertEqual(loadedConfiguration.subfolderSuffix, "_导出")
    }

    func testLoadNormalizesPersistedDimensionLimitsToSingleSelection() {
        defaults.set(1600, forKey: "imageExporter.maxWidth")
        defaults.set(1200, forKey: "imageExporter.maxHeight")
        defaults.set(2000, forKey: "imageExporter.maxLongEdge")
        defaults.set(1000, forKey: "imageExporter.maxShortEdge")

        let configuration = store.load(defaultOutputDirectory: URL(fileURLWithPath: "/tmp/output", isDirectory: true))

        XCTAssertEqual(configuration.maxWidth, 1600)
        XCTAssertNil(configuration.maxHeight)
        XCTAssertNil(configuration.maxLongEdge)
        XCTAssertNil(configuration.maxShortEdge)
    }
}
