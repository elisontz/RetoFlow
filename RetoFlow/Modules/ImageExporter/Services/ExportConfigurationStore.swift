import Foundation

struct ExportConfigurationStore: Sendable {
    private enum Key {
        nonisolated static let maxWidth = "imageExporter.maxWidth"
        nonisolated static let maxHeight = "imageExporter.maxHeight"
        nonisolated static let maxLongEdge = "imageExporter.maxLongEdge"
        nonisolated static let maxShortEdge = "imageExporter.maxShortEdge"
        nonisolated static let maxFileSizeBytes = "imageExporter.maxFileSizeBytes"
        nonisolated static let overwriteExisting = "imageExporter.overwriteExisting"
        nonisolated static let preserveMetadata = "imageExporter.preserveMetadata"
        nonisolated static let createSubfolder = "imageExporter.createSubfolder"
        nonisolated static let subfolderSuffix = "imageExporter.subfolderSuffix"
    }

    // UserDefaults 本身是线程安全的（文档明确说明），因此在 nonisolated 上下文中访问是安全的。
    // nonisolated(unsafe) 仅用于满足 Swift 并发检查器的要求，不代表实际存在数据竞争风险。
    nonisolated(unsafe) private let defaults: UserDefaults

    nonisolated init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    nonisolated func load(defaultOutputDirectory: URL) -> ExportConfiguration {
        ExportConfiguration(
            maxWidth: integer(forKey: Key.maxWidth),
            maxHeight: integer(forKey: Key.maxHeight),
            maxLongEdge: integer(forKey: Key.maxLongEdge),
            maxShortEdge: integer(forKey: Key.maxShortEdge) ?? 2500,
            maxFileSizeBytes: integer(forKey: Key.maxFileSizeBytes) ?? 5 * 1024 * 1024,
            outputDirectory: defaultOutputDirectory,
            overwriteExisting: bool(forKey: Key.overwriteExisting, defaultValue: false),
            preserveMetadata: bool(forKey: Key.preserveMetadata, defaultValue: true),
            createSubfolder: bool(forKey: Key.createSubfolder, defaultValue: true),
            subfolderSuffix: string(forKey: Key.subfolderSuffix, defaultValue: "_小图")
        ).normalizedDimensionLimits()
    }

    nonisolated func save(_ configuration: ExportConfiguration) {
        let normalized = configuration.normalizedDimensionLimits()
        set(normalized.maxWidth, forKey: Key.maxWidth)
        set(normalized.maxHeight, forKey: Key.maxHeight)
        set(normalized.maxLongEdge, forKey: Key.maxLongEdge)
        set(normalized.maxShortEdge, forKey: Key.maxShortEdge)
        set(configuration.maxFileSizeBytes, forKey: Key.maxFileSizeBytes)
        defaults.set(configuration.overwriteExisting, forKey: Key.overwriteExisting)
        defaults.set(configuration.preserveMetadata, forKey: Key.preserveMetadata)
        defaults.set(configuration.createSubfolder, forKey: Key.createSubfolder)
        defaults.set(configuration.subfolderSuffix, forKey: Key.subfolderSuffix)
    }

    private nonisolated func integer(forKey key: String) -> Int? {
        defaults.object(forKey: key) as? Int
    }

    private nonisolated func bool(forKey key: String, defaultValue: Bool) -> Bool {
        guard defaults.object(forKey: key) != nil else {
            return defaultValue
        }

        return defaults.bool(forKey: key)
    }

    private nonisolated func string(forKey key: String, defaultValue: String) -> String {
        defaults.string(forKey: key) ?? defaultValue
    }

    private nonisolated func set(_ value: Int?, forKey key: String) {
        if let value {
            defaults.set(value, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }
}
