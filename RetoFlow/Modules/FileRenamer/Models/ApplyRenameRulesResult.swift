import Foundation

struct ApplyRenameRulesResult: Sendable {
    let updatedFiles: [RenamableFile]
    let successCount: Int
    let failureCount: Int
    let skippedCount: Int
    let records: [OperationRecord]

    var message: String {
        var message = String(localized: "重命名操作已完成。")
        if successCount > 0 {
            message += "\n" + String(localized: "✅ 成功修改: \(successCount) 个文件")
        }
        if failureCount > 0 {
            message += "\n" + String(localized: "❌ 失败: \(failureCount) 个文件")
        }
        if successCount == 0 && failureCount == 0 {
            message += "\n" + String(localized: "没有文件需要重命名。")
        }
        return message
    }
}
