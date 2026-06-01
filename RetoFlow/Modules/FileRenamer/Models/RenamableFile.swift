import Foundation

enum RenameRuleType: String, CaseIterable, Identifiable, Sendable {
    case replace = "替换文本"
    case regex = "正则表达式"
    case remove = "移除文本"
    case prefix = "添加前缀"
    case suffix = "添加后缀"
    case sequence = "序列号"
    case caseChange = "大小写转换"
    case extensionChange = "修改扩展名"

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .replace: String(localized: "替换文本")
        case .regex: String(localized: "正则表达式")
        case .remove: String(localized: "移除文本")
        case .prefix: String(localized: "添加前缀")
        case .suffix: String(localized: "添加后缀")
        case .sequence: String(localized: "序列号")
        case .caseChange: String(localized: "大小写转换")
        case .extensionChange: String(localized: "修改扩展名")
        }
    }
}

enum RemoveType: String, CaseIterable, Identifiable, Sendable {
    case range = "指定区域"
    case wildcard = "通配符匹配"
    case after = "特定字符后"
    case before = "特定字符前"
    case filename = "当前文件名"

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .range: String(localized: "指定区域")
        case .wildcard: String(localized: "通配符匹配")
        case .after: String(localized: "特定字符后")
        case .before: String(localized: "特定字符前")
        case .filename: String(localized: "当前文件名")
        }
    }
}

enum CaseConversionType: String, CaseIterable, Identifiable, Sendable {
    case lowercase = "全小写"
    case uppercase = "全大写"
    case titleCase = "首字母大写"

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .lowercase: String(localized: "全小写")
        case .uppercase: String(localized: "全大写")
        case .titleCase: String(localized: "首字母大写")
        }
    }
}

enum SequencePosition: String, CaseIterable, Identifiable, Sendable {
    case start = "文件名开头"
    case end = "文件名结尾"

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .start: String(localized: "文件名开头")
        case .end: String(localized: "文件名结尾")
        }
    }
}

struct RenameRule: Identifiable, Equatable, Sendable {
    let id = UUID()
    var type: RenameRuleType
    var isEnabled: Bool = true
    
    // Parameters
    var findText: String = ""
    var replaceText: String = ""
    var regexPattern: String = ""
    var removeType: RemoveType = .wildcard
    var removeText: String = ""
    var removeStart: Int = 1
    var removeLength: Int = 1
    var prefixText: String = ""
    var suffixText: String = ""
    var sequenceStart: Int = 1
    var sequencePadding: Int = 3
    var sequencePosition: SequencePosition = .end
    var newExtension: String = ""
    var caseConversion: CaseConversionType = .lowercase
    
    static func defaultRule(_ type: RenameRuleType) -> RenameRule {
        return RenameRule(type: type)
    }
}

struct RenamableFile: Identifiable, Equatable, Sendable {
    let id = UUID()
    let originalURL: URL
    var newFilename: String
    var error: String?
    
    var originalFilename: String {
        originalURL.lastPathComponent
    }
    
    var statusIcon: String {
        if let _ = error { return "exclamationmark.triangle.fill" }
        if newFilename != originalFilename { return "pencil" }
        return "doc"
    }
}

