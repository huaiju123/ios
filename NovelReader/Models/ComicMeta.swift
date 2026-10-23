import Foundation

/// 漫画：一个 zip/cbz 解出来的图片序列
struct ComicMeta: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String
    var pageCount: Int = 0
    var lastPage: Int = 0
    var addedAt: Date = Date()
    var lastReadAt: Date?

    var progress: Double {
        guard pageCount > 0 else { return 0 }
        return min(1, Double(lastPage + 1) / Double(pageCount))
    }

    var progressText: String {
        if pageCount == 0 { return "空" }
        if progress >= 0.999 { return "已读完" }
        if lastPage <= 0 { return "\(pageCount) 页" }
        return "\(lastPage + 1)/\(pageCount)"
    }
}
