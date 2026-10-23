import Foundation

enum BookFormat: String, Codable, CaseIterable {
    case txt
    case epub
    case online

    var label: String {
        switch self {
        case .txt: return "TXT"
        case .epub: return "EPUB"
        case .online: return "在线"
        }
    }
}

/// 书架上的一本书。只存元数据，正文在 Books/<id>/chapters.json。
struct BookMeta: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String
    var author: String = ""
    var format: BookFormat = .txt

    var addedAt: Date = Date()
    var lastReadAt: Date?

    /// 上次读到的章节序号
    var chapterIndex: Int = 0
    /// 上次读到的位置（章节内字符偏移）
    var offset: Int = 0

    var coverSeed: Int = Int.random(in: 0..<64)
    var charCount: Int = 0
    var progress: Double = 0
    var intro: String = ""

    // 在线书
    var sourceID: UUID? = nil
    var sourceName: String = ""
    var bookURL: String? = nil
    var coverURL: String? = nil

    var progressText: String {
        if progress <= 0.001 { return "未读" }
        if progress >= 0.999 { return "已读完" }
        return "已读 \(Int((progress * 100).rounded()))%"
    }

    var authorText: String {
        author.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "佚名" : author
    }

    var subtitle: String {
        format == .online ? "\(format.label) · \(sourceName)" : "\(format.label) · \(progressText)"
    }
}
