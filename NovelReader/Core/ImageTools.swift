import UIKit
import ImageIO
import Foundation

enum ImageTools {
    static func thumbnail(path: URL, maxPixel: CGFloat) -> UIImage? {
        guard let source = CGImageSourceCreateWithURL(path as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: image)
    }

    @discardableResult
    static func writeThumbnail(from source: URL, to destination: URL, maxPixel: CGFloat = 600) -> Bool {
        guard let image = thumbnail(path: source, maxPixel: maxPixel),
              let data = image.jpegData(compressionQuality: 0.82) else {
            return false
        }
        AppPaths.remove(destination)
        do {
            try data.write(to: destination, options: .atomic)
            return true
        } catch {
            return false
        }
    }

    /// 缩略图缓存，避免滚动时反复解码
    private static let cache = NSCache<NSString, UIImage>()

    static func cachedImage(path: URL, maxPixel: CGFloat = 600) -> UIImage? {
        let key = (path.path + "#" + String(Int(maxPixel))) as NSString
        if let hit = cache.object(forKey: key) { return hit }
        guard let image = thumbnail(path: path, maxPixel: maxPixel) else { return nil }
        cache.setObject(image, forKey: key)
        return image
    }
}
