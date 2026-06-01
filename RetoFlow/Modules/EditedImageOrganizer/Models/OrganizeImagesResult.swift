import Foundation

struct OrganizeImagesResult: Equatable, Sendable {
    let movedCount: Int
    let skippedCount: Int
    let failedCount: Int
    let failures: [String]
    let records: [OperationRecord]

    var message: String {
        if failedCount == 0 {
            return String(localized: "整理完成！\n成功移动: \(movedCount) 个文件\n跳过(已存在): \(skippedCount) 个文件")
        }

        return String(localized: "整理完成，但有错误发生。\n成功移动: \(movedCount) 个\n失败: \(failedCount) 个\n跳过: \(skippedCount) 个")
    }
}
