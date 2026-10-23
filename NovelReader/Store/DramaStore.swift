import Foundation
import Combine

/// 短剧库
final class DramaStore: ObservableObject {
    @Published private(set) var dramas: [DramaMeta] = []

    private let fm = FileManager.default
    private var jsonURL: URL { AppPaths.root.appendingPathComponent("dramas.json") }

    init() {
        load()
    }

    func drama(id: UUID) -> DramaMeta? {
        dramas.first { $0.id == id }
    }

    /// 某一集的播放地址：本地文件或远程 URL
    func url(for episode: Episode, in drama: DramaMeta) -> URL? {
        if let fileName = episode.fileName {
            let url = AppPaths.dramaDir(drama.id).appendingPathComponent(fileName)
            return fm.fileExists(atPath: url.path) ? url : nil
        }
        if let remote = episode.remoteURL {
            return URL.lenient(remote)
        }
        return nil
    }

    @discardableResult
    func add(title: String, episodes: [Episode], id: UUID = UUID()) -> DramaMeta? {
        guard !episodes.isEmpty else { return nil }
        do {
            try AppPaths.fm.createDirectory(at: AppPaths.dramaDir(id), withIntermediateDirectories: true)
        } catch {
            return nil
        }

        var meta = DramaMeta(title: title.trimmed.isEmpty ? "未命名" : title.trimmed)
        meta.id = id
        meta.episodes = episodes
        dramas.insert(meta, at: 0)
        save()
        return meta
    }

    func append(_ episodes: [Episode], to id: UUID) {
        guard let index = dramas.firstIndex(where: { $0.id == id }) else { return }
        dramas[index].episodes.append(contentsOf: episodes)
        save()
    }

    func updateEpisode(_ index: Int, for id: UUID) {
        guard let position = dramas.firstIndex(where: { $0.id == id }) else { return }
        guard !dramas[position].episodes.isEmpty else { return }
        dramas[position].lastEpisode = min(max(index, 0), dramas[position].episodes.count - 1)
        dramas[position].lastReadAt = Date()
        save()
    }

    func delete(_ id: UUID) {
        dramas.removeAll { $0.id == id }
        AppPaths.remove(AppPaths.dramaDir(id))
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: jsonURL) else { return }
        guard let decoded = try? JSONDecoder().decode([DramaMeta].self, from: data) else {
            try? fm.removeItem(at: jsonURL)
            return
        }
        dramas = decoded.sorted { ($0.lastReadAt ?? $0.addedAt) > ($1.lastReadAt ?? $1.addedAt) }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(dramas) else { return }
        try? data.write(to: jsonURL, options: .atomic)
    }
}
