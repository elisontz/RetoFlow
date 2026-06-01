import Foundation
import CoreGraphics
import ImageIO

/// 图片元数据信息
struct ImageMetadata {
    let url: URL
    let format: ImageFormat
    let size: CGSize
    let fileSizeBytes: Int
    
    /// 图片格式枚举
    enum ImageFormat: String {
        case jpeg = "jpg"
        case png = "png"
        case tiff = "tif"
        case psd = "psd"
        case unsupported = "unsupported"
        
        /// 从 UTI 类型标识符检测格式
        nonisolated static func detect(from url: URL) -> ImageFormat {
            guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let type = CGImageSourceGetType(imageSource) as String? else {
                return .unsupported
            }
            
            switch type {
            case "public.jpeg":
                return .jpeg
            case "public.png":
                return .png
            case "public.tiff":
                return .tiff
            case "com.adobe.photoshop-image":
                return .psd
            default:
                return .unsupported
            }
        }
        
        /// 是否为支持的格式
        nonisolated var isSupported: Bool {
            return self != .unsupported
        }
    }
    
    /// 从 URL 创建元数据
    static func from(url: URL) -> ImageMetadata? {
        let format = ImageFormat.detect(from: url)
        
        guard format.isSupported else {
            return nil
        }
        
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any],
              let width = properties[kCGImagePropertyPixelWidth as String] as? CGFloat,
              let height = properties[kCGImagePropertyPixelHeight as String] as? CGFloat else {
            return nil
        }
        
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
        
        return ImageMetadata(
            url: url,
            format: format,
            size: CGSize(width: width, height: height),
            fileSizeBytes: fileSize
        )
    }
}
