import UIKit
import ImageIO
import PlainDomain

/// Photos decoded at screen size rather than the stored 2048px original.
/// Shared by the editor, the reading view and the PDF, so a photo placed in
/// a note is decoded once however many times it is drawn.
@MainActor
final class PhotoCache {
    static let shared = PhotoCache()

    /// Tall portraits are cropped to this, so one photo cannot swallow a page.
    static let minimumAspect: CGFloat = 0.75

    private let cache = NSCache<NSUUID, UIImage>()

    private init() {
        cache.countLimit = 24
    }

    /// Falls back to the thumbnail while the full bytes are unavailable.
    func image(for photo: NotePhoto, data: (UUID) -> Data?) -> UIImage? {
        if let cached = cache.object(forKey: photo.id as NSUUID) { return cached }
        guard let bytes = data(photo.id), let decoded = Self.downsample(bytes, maxPixel: 1_400) else {
            return UIImage(data: photo.thumbnail)
        }
        cache.setObject(decoded, forKey: photo.id as NSUUID)
        return decoded
    }

    /// Width over height, clamped the way inline photos are drawn.
    static func displayAspect(of photo: NotePhoto) -> CGFloat {
        guard photo.pixelWidth > 0, photo.pixelHeight > 0 else { return 4 / 3 }
        return max(CGFloat(photo.pixelWidth) / CGFloat(photo.pixelHeight), minimumAspect)
    }

    private static func downsample(_ data: Data, maxPixel: Int) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                  kCGImageSourceCreateThumbnailFromImageAlways: true,
                  kCGImageSourceCreateThumbnailWithTransform: true,
                  kCGImageSourceThumbnailMaxPixelSize: maxPixel,
                  kCGImageSourceShouldCacheImmediately: true
              ] as CFDictionary) else { return nil }
        return UIImage(cgImage: image)
    }
}
