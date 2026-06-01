import Foundation

/// 导出配置数据模型，封装用户设置的所有参数
struct ExportConfiguration: Sendable {
    var maxWidth: Int?           // 最大宽度（像素），nil 表示无限制
    var maxHeight: Int?          // 最大高度（像素），nil 表示无限制
    var maxLongEdge: Int?        // 最大边（像素），限制长边，nil 表示无限制
    var maxShortEdge: Int?       // 最小边（像素），限制短边，nil 表示无限制
    var maxFileSizeBytes: Int?   // 最大文件大小（字节），nil 表示无限制
    var outputDirectory: URL     // 输出目录
    var overwriteExisting: Bool  // 是否覆盖已存在的文件
    var preserveMetadata: Bool   // 是否保留原始图片的元数据
    var createSubfolder: Bool    // 是否在原文件夹下创建子文件夹
    var subfolderSuffix: String  // 子文件夹后缀名

    enum DimensionLimitKind: CaseIterable, Sendable {
        case width
        case height
        case longEdge
        case shortEdge
    }

    nonisolated var hasExplicitOutputTarget: Bool {
        createSubfolder || outputDirectory != FileManager.default.temporaryDirectory
    }

    nonisolated var activeDimensionLimitKind: DimensionLimitKind? {
        if maxWidth != nil { return .width }
        if maxHeight != nil { return .height }
        if maxLongEdge != nil { return .longEdge }
        if maxShortEdge != nil { return .shortEdge }
        return nil
    }

    nonisolated mutating func selectDimensionLimit(_ kind: DimensionLimitKind?, value: Int?) {
        maxWidth = nil
        maxHeight = nil
        maxLongEdge = nil
        maxShortEdge = nil

        guard let kind else { return }

        switch kind {
        case .width:
            maxWidth = value
        case .height:
            maxHeight = value
        case .longEdge:
            maxLongEdge = value
        case .shortEdge:
            maxShortEdge = value
        }
    }

    nonisolated func normalizedDimensionLimits() -> ExportConfiguration {
        var normalized = self
        let activeKind = activeDimensionLimitKind
        let activeValue: Int? = switch activeKind {
        case .width:
            maxWidth
        case .height:
            maxHeight
        case .longEdge:
            maxLongEdge
        case .shortEdge:
            maxShortEdge
        case nil:
            nil
        }
        normalized.selectDimensionLimit(activeKind, value: activeValue)
        return normalized
    }
    
    /// 验证配置参数的有效性（包含文件系统检查，应在后台线程调用）
    func validate() -> ValidationResult {
        let quick = validateWithoutIO()
        guard quick.isValid else { return quick }

        var isDirectory: ObjCBool = false
        if !FileManager.default.fileExists(atPath: outputDirectory.path, isDirectory: &isDirectory) {
            return .invalid(String(localized: "输出目录不存在"))
        }

        if !isDirectory.boolValue {
            return .invalid(String(localized: "输出路径不是目录"))
        }

        return .valid
    }

    /// 纯内存验证，不访问文件系统，可在主线程安全调用
    func validateWithoutIO() -> ValidationResult {
        // 宽度验证
        if let width = maxWidth, width <= 0 {
            return .invalid(String(localized: "宽度必须大于 0"))
        }

        // 高度验证
        if let height = maxHeight, height <= 0 {
            return .invalid(String(localized: "高度必须大于 0"))
        }

        // 最大边验证
        if let longEdge = maxLongEdge, longEdge <= 0 {
            return .invalid(String(localized: "最大边必须大于 0"))
        }

        // 最小边验证
        if let shortEdge = maxShortEdge, shortEdge <= 0 {
            return .invalid(String(localized: "最小边必须大于 0"))
        }

        // 文件大小验证
        if let size = maxFileSizeBytes, size <= 0 {
            return .invalid(String(localized: "文件大小限制必须大于 0"))
        }

        // 输出目录验证
        if !hasExplicitOutputTarget {
            return .invalid(String(localized: "请选择输出目录"))
        }

        return .valid
    }
}

/// 配置验证结果
enum ValidationResult: Sendable {
    case valid
    case invalid(String)  // 包含错误消息
    
    nonisolated var isValid: Bool {
        if case .valid = self {
            return true
        }
        return false
    }
    
    nonisolated var errorMessage: String? {
        if case .invalid(let message) = self {
            return message
        }
        return nil
    }
}
