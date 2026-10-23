import SwiftUI

/// 发现：按书源搜索，加入书架
struct DiscoverView: View {
    @EnvironmentObject private var sources: SourceStore
    @EnvironmentObject private var library: LibraryStore
    @Environment(\.dismiss) private var dismiss

    @State private var keyword = ""
    @State private var selectedSourceID: UUID?
    @State private var results: [RemoteBook] = []
    @State private var isSearching = false
    @State private var message: String?
    @State private var added: Set<UUID> = []

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("发现")
                .navigationBarTitleDisplayMode(.inline)
                .searchable(text: $keyword, prompt: "书名或作者")
                .onSubmit(of: .search) { runSearch() }
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("关闭") { dismiss() }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        sourceMenu
                    }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if sources.enabledSources.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "antenna.radiowaves.left.and.right.slash")
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(.tertiary)
                Text("还没有可用的书源")
                    .font(.system(size: 15, weight: .medium))
                Text("去「我的 → 书源」粘贴一个书源 JSON，然后再回来搜索。")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        } else if isSearching {
            ProgressView("搜索中…")
        } else if results.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 34, weight: .light))
                    .foregroundStyle(.tertiary)
                Text(message ?? "输入书名，回车搜索")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        } else {
            List(results) { book in
                row(book)
            }
            .listStyle(.plain)
        }
    }

    private func row(_ book: RemoteBook) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(book.name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.primary)
                Text(book.author.isEmpty ? book.sourceName : "\(book.author) · \(book.sourceName)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                if !book.intro.isEmpty {
                    Text(book.intro)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 8)

            Button {
                addToShelf(book)
            } label: {
                Text(added.contains(book.id) ? "已加入" : "加入")
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        added.contains(book.id) ? Color.secondary.opacity(0.15) : Color.accentColor,
                        in: Capsule()
                    )
                    .foregroundStyle(added.contains(book.id) ? Color.secondary : Color.white)
            }
            .buttonStyle(.plain)
            .disabled(added.contains(book.id))
        }
        .padding(.vertical, 2)
    }

    private var sourceMenu: some View {
        Menu {
            Button("全部书源") { selectedSourceID = nil }
            ForEach(sources.enabledSources) { source in
                Button(source.name) { selectedSourceID = source.id }
            }
        } label: {
            Image(systemName: "slider.horizontal.3")
        }
    }

    private func runSearch() {
        let text = keyword.trimmed
        guard !text.isEmpty else { return }

        let pool: [BookSource]
        if let id = selectedSourceID {
            pool = sources.enabledSources.filter { $0.id == id }
        } else {
            pool = sources.enabledSources
        }
        guard !pool.isEmpty else { return }

        results = []
        message = nil
        isSearching = true

        Task {
            var found: [RemoteBook] = []
            var lastError: String?

            for source in pool {
                do {
                    let list = try await SourceEngine.shared.search(source: source, keyword: text)
                    found.append(contentsOf: list)
                } catch {
                    lastError = error.localizedDescription
                }
            }

            await MainActor.run {
                isSearching = false
                results = found
                if found.isEmpty {
                    message = lastError ?? "没有搜到结果，换个关键词或书源试试。"
                }
            }
        }
    }

    private func addToShelf(_ book: RemoteBook) {
        let meta = library.add(
            title: book.name,
            author: book.author,
            format: .online,
            chapters: [],
            intro: book.intro,
            sourceID: book.sourceID,
            sourceName: book.sourceName,
            bookURL: book.bookURL,
            coverURL: book.coverURL
        )
        if meta != nil {
            added.insert(book.id)
        }
    }
}
