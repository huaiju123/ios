import Foundation

/// 短剧导入：把选中的视频拷进剧目录，按文件名排序当集数。
enum VideoImporter {
    static func copy(_ urls: [URL], to dramaID: UUID) throws -> [Episode] {
        let dir = AppPaths.dramaDir(dramaID)
        try AppPaths.fm.createDirectory(at: dir, withIntermediateDirectories: true)

        let sorted = urls.sorted {
            $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
        }

        var episodes: [Episode] = []
        for url in sorted {
            var fileName = url.lastPathComponent
            var destination = dir.appendingPathComponent(fileName)
            var suffix = 1

            while AppPaths.fm.fileExists(atPath: destination.path) {
                let base = url.deletingPathExtension().lastPathComponent
                let ext = url.pathExtension
                fileName = base + "-" + String(suffix) + (ext.isEmpty ? "" : "." + ext)
                destination = dir.appendingPathComponent(fileName)
                suffix += 1
            }

            try AppPaths.fm.copyItem(at: url, to: destination)
            episodes.append(Episode(title: url.deletingPathExtension().lastPathComponent, fileName: fileName))
        }

        return episodes
    }
}
