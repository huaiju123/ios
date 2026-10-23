import Foundation

/// 沙盒目录。所有内容都放在 Documents/MoDu 下。
enum AppPaths {
    static let fm = FileManager.default

    static var root: URL {
        let base = fm.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        return base.appendingPathComponent("MoDu", isDirectory: true)
    }

    static var booksFolder: URL { folder("Books") }
    static var comicsFolder: URL { folder("Comics") }
    static var dramasFolder: URL { folder("Dramas") }
    static var cacheFolder: URL { folder("Cache") }

    static func folder(_ name: String) -> URL {
        let url = root.appendingPathComponent(name, isDirectory: true)
        try? fm.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func bookDir(_ id: UUID) -> URL { booksFolder.appendingPathComponent(id.uuidString, isDirectory: true) }
    static func comicDir(_ id: UUID) -> URL { comicsFolder.appendingPathComponent(id.uuidString, isDirectory: true) }
    static func dramaDir(_ id: UUID) -> URL { dramasFolder.appendingPathComponent(id.uuidString, isDirectory: true) }

    static func file(_ name: String, in root: URL) -> URL { root.appendingPathComponent(name) }

    /// 把文档目录里的相对路径还原成绝对路径；远程 URL 原样返回
    static func resolve(_ path: String, base: URL) -> URL {
        if path.hasPrefix("http://") || path.hasPrefix("https://") {
            return URL(string: path) ?? base
        }
        return base.appendingPathComponent(path)
    }

    static func remove(_ url: URL) {
        try? fm.removeItem(at: url)
    }

    static func size(of url: URL) -> Int64 {
        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
            if values?.isRegularFile == true {
                total += Int64(values?.fileSize ?? 0)
            }
        }
        return total
    }

    static func formatSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useMB, .useKB, .useGB]
        return formatter.string(fromByteCount: bytes)
    }
}
