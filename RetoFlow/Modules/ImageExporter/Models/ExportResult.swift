import Foundation
import CoreGraphics

/// 单个图片导出操作的结果
struct ExportResult: Identifiable, Sendable {
    let id = UUID()
    let sourceURL: URL
    let outputURL: URL?
    let success: Bool
    let error: String?
    let originalSize: CGSize
    let exportedSize: CGSize?
    let fileSizeBytes: Int?
    let compressionQuality: Double?
    
    /// 创建成功的导出结果
    nonisolated static func success(
        sourceURL: URL,
        outputURL: URL,
        originalSize: CGSize,
        exportedSize: CGSize,
        fileSizeBytes: Int,
        compressionQuality: Double
    ) -> ExportResult {
        return ExportResult(
            sourceURL: sourceURL,
            outputURL: outputURL,
            success: true,
            error: nil,
            originalSize: originalSize,
            exportedSize: exportedSize,
            fileSizeBytes: fileSizeBytes,
            compressionQuality: compressionQuality
        )
    }
    
    /// 创建失败的导出结果
    nonisolated static func failure(
        sourceURL: URL,
        originalSize: CGSize,
        error: String
    ) -> ExportResult {
        return ExportResult(
            sourceURL: sourceURL,
            outputURL: nil,
            success: false,
            error: error,
            originalSize: originalSize,
            exportedSize: nil,
            fileSizeBytes: nil,
            compressionQuality: nil
        )
    }
    
    /// 源文件名
    var sourceFileName: String {
        sourceURL.lastPathComponent
    }
    
    /// 输出文件名
    var outputFileName: String? {
        outputURL?.lastPathComponent
    }
    
    /// 格式化的文件大小
    var formattedFileSize: String? {
        guard let bytes = fileSizeBytes else { return nil }
        return ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }
    
    /// 格式化的压缩质量
    var formattedQuality: String? {
        guard let quality = compressionQuality else { return nil }
        return String(format: "%.2f", quality)
    }
}
