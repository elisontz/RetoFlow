import Foundation

enum DiffStatus: String, CaseIterable, Identifiable {
    case match = "匹配"
    case mismatch = "不匹配" // 只要两边不一致（一边有一边无）统称为不匹配
    
    var id: String { self.rawValue }
}

struct ImageFile: Identifiable, Hashable, Sendable {
    let id = UUID()
    let filename: String
    let url: URL
    
    // 用于比对的键值，忽略大小写
    nonisolated var compareKey: String {
        filename.lowercased()
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(compareKey)
    }
    
    nonisolated static func == (lhs: ImageFile, rhs: ImageFile) -> Bool {
        return lhs.compareKey == rhs.compareKey
    }
}

struct DiffResult: Identifiable, Sendable {
    let id = UUID()
    let status: DiffStatus
    let checkedFile: ImageFile?   // 左侧：已修的图片
    let originalFile: ImageFile?  // 右侧：原始的图片
    
    // 用于排序和显示的名称
    nonisolated var displayName: String {
        return checkedFile?.filename ?? originalFile?.filename ?? ""
    }
}
