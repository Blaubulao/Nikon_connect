import AVFoundation
import Foundation
import ImageIO
import UIKit

actor AssetThumbnailService {
    private var cachedThumbnailData: [String: Data] = [:]
    private var inFlightTasks: [String: Task<Data?, Never>] = [:]
    private var unavailableIdentifiers = Set<String>()
    private var cachedPreviewData: [String: Data] = [:]
    private var previewTasks: [String: Task<Data?, Never>] = [:]
    private var unavailablePreviewIdentifiers = Set<String>()

    func clear() {
        cachedThumbnailData.removeAll()
        inFlightTasks.removeAll()
        unavailableIdentifiers.removeAll()
        cachedPreviewData.removeAll()
        previewTasks.removeAll()
        unavailablePreviewIdentifiers.removeAll()
    }

    func thumbnailData(
        for asset: PhotoAsset,
        using transport: any CameraTransport,
        session: CameraSession
    ) async -> Data? {
        if let cached = cachedThumbnailData[asset.remoteIdentifier] {
            return cached
        }

        if unavailableIdentifiers.contains(asset.remoteIdentifier) {
            return nil
        }

        if let existingTask = inFlightTasks[asset.remoteIdentifier] {
            return await existingTask.value
        }

        let task = Task<Data?, Never> {
            if let previewData = try? await transport.downloadThumbnail(asset, from: session),
               let normalizedPreview = Self.normalizePreviewData(previewData, maxPixelSize: 420) {
                return normalizedPreview
            }

            guard let originalData = try? await transport.downloadAsset(asset, from: session) else {
                return nil
            }

            return Self.makeThumbnailData(
                from: originalData,
                fileName: asset.fileName,
                kind: asset.kind,
                maxPixelSize: 420
            )
        }

        inFlightTasks[asset.remoteIdentifier] = task
        let result = await task.value
        inFlightTasks[asset.remoteIdentifier] = nil

        if let result {
            cachedThumbnailData[asset.remoteIdentifier] = result
        } else {
            unavailableIdentifiers.insert(asset.remoteIdentifier)
        }

        return result
    }

    func previewData(
        for asset: PhotoAsset,
        using transport: any CameraTransport,
        session: CameraSession
    ) async -> Data? {
        if let cached = cachedPreviewData[asset.remoteIdentifier] {
            return cached
        }

        if unavailablePreviewIdentifiers.contains(asset.remoteIdentifier) {
            return nil
        }

        if let existingTask = previewTasks[asset.remoteIdentifier] {
            return await existingTask.value
        }

        let task = Task<Data?, Never> {
            if let originalData = try? await transport.downloadAsset(asset, from: session),
               let preview = Self.makePreviewData(
                   from: originalData,
                   fileName: asset.fileName,
                   kind: asset.kind,
                   maxPixelSize: 4096
               ) {
                return preview
            }

            if let previewData = try? await transport.downloadThumbnail(asset, from: session) {
                return Self.normalizePreviewData(previewData, maxPixelSize: 2048)
            }

            return nil
        }

        previewTasks[asset.remoteIdentifier] = task
        let result = await task.value
        previewTasks[asset.remoteIdentifier] = nil

        if let result {
            cachedPreviewData[asset.remoteIdentifier] = result
        } else {
            unavailablePreviewIdentifiers.insert(asset.remoteIdentifier)
        }

        return result
    }

    private static func normalizePreviewData(_ data: Data, maxPixelSize: Int) -> Data? {
        if let normalized = generateImageThumbnailData(
            from: data,
            maxPixelSize: maxPixelSize,
            cropBlackBorders: true,
            compressionQuality: 0.82
        ) {
            return normalized
        }

        return UIImage(data: data) != nil ? data : nil
    }

    private static func makeThumbnailData(
        from originalData: Data,
        fileName: String,
        kind: PhotoAssetKind,
        maxPixelSize: Int
    ) -> Data? {
        switch kind {
        case .movie:
            return generateMovieThumbnailData(
                from: originalData,
                fileName: fileName,
                maxPixelSize: maxPixelSize,
                cropBlackBorders: true,
                compressionQuality: 0.82
            )

        case .jpeg, .png, .raw:
            return generateImageThumbnailData(
                from: originalData,
                maxPixelSize: maxPixelSize,
                cropBlackBorders: true,
                compressionQuality: 0.82
            )
        }
    }

    private static func makePreviewData(
        from originalData: Data,
        fileName: String,
        kind: PhotoAssetKind,
        maxPixelSize: Int
    ) -> Data? {
        switch kind {
        case .movie:
            return generateMovieThumbnailData(
                from: originalData,
                fileName: fileName,
                maxPixelSize: maxPixelSize,
                cropBlackBorders: false,
                compressionQuality: 0.9
            )

        case .jpeg, .png, .raw:
            return generateImageThumbnailData(
                from: originalData,
                maxPixelSize: maxPixelSize,
                cropBlackBorders: false,
                compressionQuality: 0.9
            )
        }
    }

    private static func generateImageThumbnailData(
        from originalData: Data,
        maxPixelSize: Int,
        cropBlackBorders: Bool,
        compressionQuality: CGFloat
    ) -> Data? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]

        guard
            let source = CGImageSourceCreateWithData(originalData as CFData, nil),
            let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
        else {
            return nil
        }

        return jpegData(
            from: cgImage,
            compressionQuality: compressionQuality,
            cropBlackBorders: cropBlackBorders
        )
    }

    private static func generateMovieThumbnailData(
        from originalData: Data,
        fileName: String,
        maxPixelSize: Int,
        cropBlackBorders: Bool,
        compressionQuality: CGFloat
    ) -> Data? {
        let fileExtension = URL(fileURLWithPath: fileName).pathExtension
        let temporaryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(fileExtension.isEmpty ? "mov" : fileExtension)

        do {
            try originalData.write(to: temporaryURL, options: .atomic)
        } catch {
            return nil
        }

        defer {
            try? FileManager.default.removeItem(at: temporaryURL)
        }

        let asset = AVURLAsset(url: temporaryURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: maxPixelSize, height: maxPixelSize)

        guard
            let cgImage = try? generator.copyCGImage(
                at: CMTime(seconds: 0.0, preferredTimescale: 600),
                actualTime: nil
            )
        else {
            return nil
        }

        return jpegData(
            from: cgImage,
            compressionQuality: compressionQuality,
            cropBlackBorders: cropBlackBorders
        )
    }

    private static func jpegData(
        from cgImage: CGImage,
        compressionQuality: CGFloat,
        cropBlackBorders: Bool
    ) -> Data? {
        let renderedImage = cropBlackBorders ? (cropBlackBordersIfNeeded(from: cgImage) ?? cgImage) : cgImage
        return UIImage(cgImage: renderedImage).jpegData(compressionQuality: compressionQuality)
    }

    private static func cropBlackBordersIfNeeded(from cgImage: CGImage) -> CGImage? {
        let width = cgImage.width
        let height = cgImage.height

        guard width >= 40, height >= 40 else {
            return nil
        }

        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var rgba = [UInt8](repeating: 0, count: bytesPerRow * height)

        guard
            let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
            let context = CGContext(
                data: &rgba,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        else {
            return nil
        }

        context.interpolationQuality = .none
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        let rowStep = max(1, width / 48)
        let columnStep = max(1, height / 48)
        let darkThreshold: UInt8 = 20
        let requiredDarkRatio = 0.98

        func pixelIsDark(x: Int, y: Int) -> Bool {
            let index = (y * bytesPerRow) + (x * bytesPerPixel)
            let red = rgba[index]
            let green = rgba[index + 1]
            let blue = rgba[index + 2]
            return red <= darkThreshold && green <= darkThreshold && blue <= darkThreshold
        }

        func rowIsBlack(_ y: Int) -> Bool {
            var samples = 0
            var darkSamples = 0

            for x in stride(from: 0, to: width, by: rowStep) {
                samples += 1
                if pixelIsDark(x: x, y: y) {
                    darkSamples += 1
                }
            }

            return samples > 0 && Double(darkSamples) / Double(samples) >= requiredDarkRatio
        }

        func columnIsBlack(_ x: Int) -> Bool {
            var samples = 0
            var darkSamples = 0

            for y in stride(from: 0, to: height, by: columnStep) {
                samples += 1
                if pixelIsDark(x: x, y: y) {
                    darkSamples += 1
                }
            }

            return samples > 0 && Double(darkSamples) / Double(samples) >= requiredDarkRatio
        }

        let maxVerticalCrop = height / 3
        let maxHorizontalCrop = width / 6

        var top = 0
        while top < maxVerticalCrop, rowIsBlack(top) {
            top += 1
        }

        var bottom = 0
        while bottom < maxVerticalCrop, rowIsBlack(height - 1 - bottom) {
            bottom += 1
        }

        var left = 0
        while left < maxHorizontalCrop, columnIsBlack(left) {
            left += 1
        }

        var right = 0
        while right < maxHorizontalCrop, columnIsBlack(width - 1 - right) {
            right += 1
        }

        guard top > 4 || bottom > 4 || left > 4 || right > 4 else {
            return nil
        }

        let croppedWidth = width - left - right
        let croppedHeight = height - top - bottom

        guard croppedWidth > width / 2, croppedHeight > height / 2 else {
            return nil
        }

        return cgImage.cropping(to: CGRect(x: left, y: top, width: croppedWidth, height: croppedHeight))
    }
}
