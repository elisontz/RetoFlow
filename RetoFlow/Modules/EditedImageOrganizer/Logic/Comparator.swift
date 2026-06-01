import Foundation

enum Comparator {
    nonisolated static func compare(checked: [ImageFile], original: [ImageFile]) -> [DiffResult] {
        var results: [DiffResult] = []
            
            // 建立查找表，以文件名为 key (lowercased)
            let checkedMap = Dictionary(grouping: checked, by: { $0.compareKey }).compactMapValues { $0.first }
            let originalMap = Dictionary(grouping: original, by: { $0.compareKey }).compactMapValues { $0.first }
            
            let checkedKeys = Set(checkedMap.keys)
            let originalKeys = Set(originalMap.keys)
            
            // 1. 匹配 (Intersection)
            let commonKeys = checkedKeys.intersection(originalKeys)
            for key in commonKeys {
                if let checkedFile = checkedMap[key], let originalFile = originalMap[key] {
                    results.append(DiffResult(status: .match, checkedFile: checkedFile, originalFile: originalFile))
                }
            }
            
            // 2. 缺失 (Missing) - 在 Original 中有，但 Checked 中没有
            let missingKeys = originalKeys.subtracting(checkedKeys)
            for key in missingKeys {
                if let originalFile = originalMap[key] {
                    // 左侧(Checked)为空，右侧(Original)有值
                    results.append(DiffResult(status: .mismatch, checkedFile: nil, originalFile: originalFile))
                }
            }
            
            // 3. 多余 (Extra) - 在 Checked 中有，但 Original 中没有
            let extraKeys = checkedKeys.subtracting(originalKeys)
            for key in extraKeys {
                if let checkedFile = checkedMap[key] {
                    // 左侧(Checked)有值，右侧(Original)为空
                    results.append(DiffResult(status: .mismatch, checkedFile: checkedFile, originalFile: nil))
                }
            }
            
            // 排序：先按状态排序 (不匹配 > 匹配)，再按文件名排序
        return results.sorted { (lhs, rhs) -> Bool in
            if lhs.status != rhs.status {
                let order: [DiffStatus: Int] = [.mismatch: 0, .match: 1]
                return (order[lhs.status] ?? 2) < (order[rhs.status] ?? 2)
            }
            return lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
        }
    }
}
