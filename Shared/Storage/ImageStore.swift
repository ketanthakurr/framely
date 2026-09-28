import UIKit
import ImageIO
import CoreImage
import UniformTypeIdentifiers

/// Stores resized JPEGs in the App Group container and loads them memory-efficiently.
/// Widgets have a ~30 MB memory budget, so we always downsample on load.
enum ImageStore {
    /// Longest edge stored on disk. Large widget ≈ 364×382pt @3x ≈ 1150px.
    static let storedMaxPixel: CGFloat = 1400

    static var directory: URL {
        let url = AppGroup.containerURL.appendingPathComponent("Photos", isDirectory: true)
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        return url
    }

    static func url(for fileName: String) -> URL { directory.appendingPathComponent(fileName) }

    // MARK: Save

    /// Downsamples raw image data, writes a JPEG and returns the new PhotoItem (without capture date).
    static func save(imageData: Data) throws -> PhotoItem {
        guard let cgImage = downsample(data: imageData, maxPixel: storedMaxPixel) else {
            throw ImageStoreError.unreadableImage
        }
        let fileName = UUID().uuidString + ".jpg"
        let destURL = url(for: fileName)
        guard let dest = CGImageDestinationCreateWithURL(destURL as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw ImageStoreError.writeFailed
        }
        CGImageDestinationAddImage(dest, cgImage, [kCGImageDestinationLossyCompressionQuality: 0.86] as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { throw ImageStoreError.writeFailed }

        return PhotoItem(
            fileName: fileName,
            capturedAt: captureDate(from: imageData),
            dominantColorHex: ImageProcessing.averageColorHex(of: cgImage)
        )
    }

    static func delete(_ item: PhotoItem) {
        try? FileManager.default.removeItem(at: url(for: item.fileName))
    }

    /// Removes files no set references anymore (e.g. after a crash mid-import).
    static func removeOrphans(keeping sets: [PhotoSet]) {
        let used = Set(sets.flatMap { $0.photos.map(\.fileName) })
        let files = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        for file in files where !used.contains(file) {
            try? FileManager.default.removeItem(at: url(for: file))
        }
    }

    // MARK: Load

    /// Loads a photo downsampled to `maxPixel` with the given filter applied.
    static func image(for item: PhotoItem, maxPixel: CGFloat, filter: PhotoFilter = .original, lockLook: LockPhotoLook = .natural) -> UIImage? {
        guard let source = CGImageSourceCreateWithURL(url(for: item.fileName) as CFURL, nil),
              let cg = thumbnail(from: source, maxPixel: maxPixel) else { return nil }
        var result = ImageProcessing.apply(filter, to: cg) ?? cg
        result = ImageProcessing.apply(lockLook, to: result) ?? result
        return UIImage(cgImage: result)
    }

    // MARK: Helpers

    static func downsample(data: Data, maxPixel: CGFloat) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary) else { return nil }
        return thumbnail(from: source, maxPixel: maxPixel)
    }

    private static func thumbnail(from source: CGImageSource, maxPixel: CGFloat) -> CGImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,   // respects EXIF orientation
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    private static func captureDate(from data: Data) -> Date? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let exif = props[kCGImagePropertyExifDictionary] as? [CFString: Any],
              let raw = exif[kCGImagePropertyExifDateTimeOriginal] as? String else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        return formatter.date(from: raw)
    }
}

enum ImageStoreError: LocalizedError {
    case unreadableImage, writeFailed
    var errorDescription: String? {
        switch self {
        case .unreadableImage: "This photo couldn't be read."
        case .writeFailed: "Couldn't save the photo. Check your free storage."
        }
    }
}

enum ImageProcessing {
    private static let context = CIContext(options: [.cacheIntermediates: false])

    static func apply(_ filter: PhotoFilter, to image: CGImage) -> CGImage? {
        guard let name = filter.ciFilterName, let ci = CIFilter(name: name) else { return nil }
        ci.setValue(CIImage(cgImage: image), forKey: kCIInputImageKey)
        guard let output = ci.outputImage else { return nil }
        return context.createCGImage(output, from: output.extent)
    }

    /// Lock Screen looks: tuned so photos read well in iOS's tinted (vibrant) rendering.
    static func apply(_ look: LockPhotoLook, to image: CGImage) -> CGImage? {
        let input = CIImage(cgImage: image)
        var output: CIImage?
        switch look {
        case .natural:
            return nil
        case .contrast:
            output = input
                .applyingFilter("CIPhotoEffectNoir")
                .applyingFilter("CIColorControls", parameters: [kCIInputContrastKey: 1.35, kCIInputBrightnessKey: 0.03])
        case .poster:
            output = input
                .applyingFilter("CIPhotoEffectMono")
                .applyingFilter("CIColorControls", parameters: [kCIInputContrastKey: 1.2])
                .applyingFilter("CIColorPosterize", parameters: ["inputLevels": 4])
        case .soft:
            output = input
                .applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0, kCIInputContrastKey: 0.8, kCIInputBrightnessKey: 0.08])
        case .outline:
            output = input
                .applyingFilter("CIPhotoEffectMono")
                .applyingFilter("CIEdges", parameters: [kCIInputIntensityKey: 4.0])
                .applyingFilter("CIColorControls", parameters: [kCIInputBrightnessKey: 0.05, kCIInputContrastKey: 1.6])
        }
        guard let output else { return nil }
        return context.createCGImage(output, from: input.extent)
    }

    /// Average color via CIAreaAverage, slightly boosted so widget glows look lively.
    static func averageColorHex(of image: CGImage) -> String? {
        let input = CIImage(cgImage: image)
        guard let filter = CIFilter(name: "CIAreaAverage", parameters: [
            kCIInputImageKey: input,
            kCIInputExtentKey: CIVector(cgRect: input.extent),
        ]), let output = filter.outputImage else { return nil }

        var pixel = [UInt8](repeating: 0, count: 4)
        context.render(output, toBitmap: &pixel, rowBytes: 4,
                       bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                       format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())

        // Boost saturation a touch.
        let color = UIColor(red: CGFloat(pixel[0]) / 255, green: CGFloat(pixel[1]) / 255, blue: CGFloat(pixel[2]) / 255, alpha: 1)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        let boosted = UIColor(hue: h, saturation: min(1, s * 1.35), brightness: min(0.85, max(0.35, b)), alpha: 1)

        var r: CGFloat = 0, g: CGFloat = 0, bl: CGFloat = 0
        boosted.getRed(&r, green: &g, blue: &bl, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(bl * 255))
    }
}
