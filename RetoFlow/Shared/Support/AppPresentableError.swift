import Foundation

/// 统一的错误展示协议，所有模块级错误类型均可遵循。
/// 提供一致的用户可见描述和可选的调试摘要。
nonisolated protocol AppPresentableError: LocalizedError {
    /// 展示给用户的描述性消息。
    var userMessage: String { get }
}

extension AppPresentableError {
    /// 默认实现：复用 `LocalizedError.errorDescription`。
    nonisolated var userMessage: String {
        errorDescription ?? String(localized: "操作失败")
    }
}
