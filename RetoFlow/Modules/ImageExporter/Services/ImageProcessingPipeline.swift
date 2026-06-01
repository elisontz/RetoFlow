import Foundation
import CoreImage
import CoreGraphics
import ImageIO

struct PreparedImageExport {
    let data: Data
    let originalSize: CGSize
    let exportedSize: CGSize
    let compressionQuality: Double
}

struct ImageProcessingPipeline {
    typealias LoadImage = @Sendable (URL) -> CIImage?
    typealias ExtractMetadata = @Sendable (URL) -> [String: Any]?
    typealias CompressImage = @Sendable (CIImage, Double, [String: Any]?, CGColorSpace, CIContext) -> Data?

    private let loadImageImpl: LoadImage
    private let extractMetadataImpl: ExtractMetadata
    private let compressImageImpl: CompressImage

    nonisolated init(
        loadImageImpl: @escaping LoadImage = Self.loadImage,
        extractMetadataImpl: @escaping ExtractMetadata = Self.extractMetadata,
        compressImageImpl: @escaping CompressImage = Self.compressImage
    ) {
        self.loadImageImpl = loadImageImpl
        self.extractMetadataImpl = extractMetadataImpl
        self.compressImageImpl = compressImageImpl
    }

    nonisolated func prepareExport(
        sourceURL: URL,
        configuration: ExportConfiguration,
        ciContext: CIContext
    ) -> PreparedImageExport? {
        guard let ciImage = loadImageImpl(sourceURL) else {
            return nil
        }

        let originalSize = ciImage.extent.size
        let targetSize = calculateTargetSize(
            original: originalSize,
            maxWidth: configuration.maxWidth,
            maxHeight: configuration.maxHeight,
            maxLongEdge: configuration.maxLongEdge,
            maxShortEdge: configuration.maxShortEdge
        )
        let resizedImage = targetSize == originalSize ? ciImage : resizeImage(ciImage, targetSize: targetSize)
        let metadata = configuration.preserveMetadata ? extractMetadataImpl(sourceURL) : nil
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!

        let finalData: Data?
        let quality: Double

        if let maxSize = configuration.maxFileSizeBytes {
            let result = optimizeQuality(
                image: resizedImage,
                maxSizeBytes: maxSize,
                metadata: metadata,
                colorSpace: colorSpace,
                ciContext: ciContext
            )
            finalData = result.data
            quality = result.quality
        } else {
            finalData = compressImageImpl(
                resizedImage,
                0.9,
                metadata,
                colorSpace,
                ciContext
            )
            quality = 0.9
        }

        guard let finalData else {
            return nil
        }

        return PreparedImageExport(
            data: finalData,
            originalSize: originalSize,
            exportedSize: resizedImage.extent.size,
            compressionQuality: quality
        )
    }

    private nonisolated func calculateTargetSize(
        original: CGSize,
        maxWidth: Int?,
        maxHeight: Int?,
        maxLongEdge: Int?,
        maxShortEdge: Int?
    ) -> CGSize {
        var targetSize = original
        guard maxWidth != nil || maxHeight != nil || maxLongEdge != nil || maxShortEdge != nil else {
            return targetSize
        }

        var scale: CGFloat = 1.0
        if let maxW = maxWidth {
            scale = min(scale, CGFloat(maxW) / original.width)
        }
        if let maxH = maxHeight {
            scale = min(scale, CGFloat(maxH) / original.height)
        }
        if let maxLong = maxLongEdge {
            scale = min(scale, CGFloat(maxLong) / max(original.width, original.height))
        }
        if let maxShort = maxShortEdge {
            scale = min(scale, CGFloat(maxShort) / min(original.width, original.height))
        }

        if scale < 1.0 {
            targetSize = CGSize(width: original.width * scale, height: original.height * scale)
        }

        return targetSize
    }

    private nonisolated func resizeImage(_ ciImage: CIImage, targetSize: CGSize) -> CIImage {
        let scale = min(
            targetSize.width / ciImage.extent.width,
            targetSize.height / ciImage.extent.height
        )

        let filter = CIFilter(name: "CILanczosScaleTransform")!
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(scale, forKey: kCIInputScaleKey)
        filter.setValue(1.0, forKey: kCIInputAspectRatioKey)
        return filter.outputImage!
    }

    private nonisolated func optimizeQuality(
        image: CIImage,
        maxSizeBytes: Int,
        metadata: [String: Any]?,
        colorSpace: CGColorSpace,
        ciContext: CIContext
    ) -> (data: Data?, quality: Double) {
        var low: Double = 0.0
        var high: Double = 1.0
        var bestQuality: Double = 0.0
        var bestData: Data? = nil
        var iterations = 0

        while low <= high && iterations < 10 {
            let mid = (low + high) / 2.0
            guard let data = compressImageImpl(image, mid, metadata, colorSpace, ciContext) else {
                break
            }

            if data.count <= maxSizeBytes {
                bestQuality = mid
                bestData = data
                low = mid + 0.01
            } else {
                high = mid - 0.01
            }

            iterations += 1
        }

        return (bestData, bestQuality)
    }

    private nonisolated static func loadImage(from url: URL) -> CIImage? {
        let format = ImageMetadata.ImageFormat.detect(from: url)
        guard format.isSupported else { return nil }
        return CIImage(contentsOf: url)
    }

    private nonisolated static func extractMetadata(from url: URL) -> [String: Any]? {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] else {
            return nil
        }

        var metadata: [String: Any] = [:]
        if let exif = properties[kCGImagePropertyExifDictionary as String] {
            metadata[kCGImagePropertyExifDictionary as String] = exif
        }
        if let tiff = properties[kCGImagePropertyTIFFDictionary as String] {
            metadata[kCGImagePropertyTIFFDictionary as String] = tiff
        }
        if let gps = properties[kCGImagePropertyGPSDictionary as String] {
            metadata[kCGImagePropertyGPSDictionary as String] = gps
        }
        if let iptc = properties[kCGImagePropertyIPTCDictionary as String] {
            metadata[kCGImagePropertyIPTCDictionary as String] = iptc
        }
        if let colorProfile = properties[kCGImagePropertyProfileName as String] {
            metadata[kCGImagePropertyProfileName as String] = colorProfile
        }
        return metadata.isEmpty ? nil : metadata
    }

    private nonisolated static func compressImage(
        _ ciImage: CIImage,
        quality: Double,
        metadata: [String: Any]?,
        colorSpace: CGColorSpace,
        ciContext: CIContext
    ) -> Data? {
        guard let cgImage = ciContext.createCGImage(
            ciImage,
            from: ciImage.extent,
            format: .RGBA8,
            colorSpace: colorSpace
        ) else {
            return nil
        }

        let mutableData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            mutableData,
            "public.jpeg" as CFString,
            1,
            nil
        ) else {
            return nil
        }

        var properties: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: quality
        ]

        if let metadata {
            if let exif = metadata[kCGImagePropertyExifDictionary as String] {
                properties[kCGImagePropertyExifDictionary] = exif
            }
            if let tiff = metadata[kCGImagePropertyTIFFDictionary as String] {
                properties[kCGImagePropertyTIFFDictionary] = tiff
            }
            if let gps = metadata[kCGImagePropertyGPSDictionary as String] {
                properties[kCGImagePropertyGPSDictionary] = gps
            }
            if let iptc = metadata[kCGImagePropertyIPTCDictionary as String] {
                properties[kCGImagePropertyIPTCDictionary] = iptc
            }
        }

        CGImageDestinationAddImage(destination, cgImage, properties as CFDictionary)
        CGImageDestinationFinalize(destination)
        return mutableData as Data
    }
}
