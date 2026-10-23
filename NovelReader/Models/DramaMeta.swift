import Foundation

struct Episode: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String
    /// 本地文件名（相对剧目录）
    var fileName: String? = nil
    /// 或者一个远程地址（mp4 / m3u8）
    var remoteURL: String? = nil
}

struct DramaMeta: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String
    var episodes: [Episode] = []
    var lastEpisode: Int = 0
    var addedAt: Date = Date()
    var lastReadAt: Date?

    var countText: String {
        episodes.isEmpty ? "空" : "\(episodes.count) 集"
    }

    var progressText: String {
        guard !episodes.isEmpty else { return "空" }
        if lastEpisode >= episodes.count - 1 { return "已看完" }
        return "第 \(lastEpisode + 1) 集"
    }
}
