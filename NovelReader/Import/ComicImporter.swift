import Foundation
import ZIPFoundation

/// 漫画导入：把 zip / cbz 解到漫画目录，图片统一改名成 p00001.jpg 这样的顺序文件名。
enum ComicImporter {
    static let allowedExtensions: Set<String> = ["jpg", "jpeg", "png", "webp", "gif", "heic", "bmp", "tiff"]

    static func extract(zip url: URL, to id: UUID) throws -> [String] {
        let dir = AppPaths.comicDir(id)
        try AppPaths.fm.createDirectory(at: dir, withIntermediateDirectories: true)

        do {
            try AppPaths.fm.unzipItem(at: url, to: dir)
        } catch {
            AppPaths.remove(dir)
            throw ImportError.unzipFailed(error.localizedDescription)
        }

        let images = collectImages(in: dir)
        guard !images.isEmpty else {
            AppPaths.remove(dir)
            throw ImportError.emptyContent
        }

        let pagesDir = dir.appendingPathComponent("pages", isDirectory: true)
        try AppPaths.fm.createDirectory(at: pagesDir, withIntermediateDirectories: true)

        var names: [String] = []
        for (index, source) in images.enumerated() {
            let ext = source.pathExtension.lowercased()
            let name = "p" + String(format: "%05d", index + 1) + "." + ext
            let destination = pagesDir.appendingPathComponent(name)
            do {
                try AppPaths.fm.moveItem(at: source, to: destination)
            } catch {
                continue
            }
            names.append("pages/" + name)
        }

        guard !names.isEmpty else {
            AppPaths.remove(dir)
            throw ImportError.emptyContent
        }

        let first = dir.appendingPathComponent(names[0])
        ImageTools.writeThumbnail(from: first, to: dir.appendingPathComponent("cover.jpg"))

        return names
    }

    private static func collectImages(in dir: URL) -> [URL] {
        guard let enumerator = AppPaths.fm.enumerator(
            at: dir,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var files: [URL] = []
        for case let url as URL in enumerator {
            let name = url.lastPathComponent
            if name.isEmpty || name.hasPrefix(".") { continue }
            if url.path.contains("__MACOSX") { continue }
            guard allowedExtensions.contains(url.pathExtension.lowercased()) else { continue }
            files.append(url)
        }

        let prefix = dir.path
        return files.sorted { left, right in
            let l = left.path.replacingOccurrences(of: prefix, with: "")
            let r = right.path.replacingOccurrences(of: prefix, with: "")
            return l.localizedStandardCompare(r) == .orderedAscending
        }
    }
}
