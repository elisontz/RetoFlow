import Foundation
import CoreGraphics
import SwiftUI

/// 可导出的图片文件，包含导出状态
struct ExportableImage: Identifiable, Sendable {
    let id = UUID()
    let url: URL
    var status: ExportStatus = .pending
    var exportedSize: CGSize?
    var fileSizeBytes: Int?
    var compressionQuality: Double?
    var error: String?
    
    enum ExportStatus: Sendable {
        case pending      // 等待导出
        case exporting    // 正在导出
        case success      // 导出成功
        case failed       // 导出失败
        
        var icon: String {
            switch self {
            case .pending: return "circle"
            case .exporting: return "arrow.down.circle"
            case .success: return "checkmark.circle.fill"
            case .failed: return "xmark.circle.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .pending: return .secondary
            case .exporting: return .blue
            case .success: return .green
            case .failed: return .red
            }
        }
    }
    
    var fileName: String {
        url.lastPathComponent
    }
    
    var folderPath: String {
        url.deletingLastPathComponent().path
    }
    
    var formattedFileSize: String? {
        guard let bytes = fileSizeBytes else { return nil }
        return ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }
    
    var formattedQuality: String? {
        guard let quality = compressionQuality else { return nil }
        return String(format: "%.2f", quality)
    }
}
