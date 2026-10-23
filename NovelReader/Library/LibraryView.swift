import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    @EnvironmentObject private var store: LibraryStore
    @EnvironmentObject private var sources: SourceStore
    @EnvironmentObject private var settings: ReaderSettings

    @State private var showImporter = false
    @State private var showPaste = false
    @State private var showDiscover = false
    @State private var pendingDelete: BookMeta?
    @State private var errorMessage: String?
    @State private var importing = false

    private let columns = [
        GridItem(.adaptive(minimum: 104, maximum: 150), spacing: 18, alignment: .top)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                if store.books.isEmpty {
                    emptyState
                } else {
                    shelf
                }

                if importing {
                    ProgressView("导入中…")
                        .padding(20)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
            .navigationTitle("书架")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showDiscover = true
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                    .accessibilityLabel("搜索书源")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    addMenu
                }
            }
            .navigationDestination(for: BookMeta.self) { book in
                ReaderView(book: book, library: store, sources: sources, settings: settings)
            }
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: importTypes,
            allowsMultipleSelection: true
        ) { result in
            handleImport(result)
        }
        .sheet(isPresented: $showPaste) {
            PasteImportView()
        }
        .sheet(isPresented: $showDiscover) {
            DiscoverView()
        }
        .confirmationDialog("删除这本书？", isPresented: deleteBinding, titleVisibility: .visible) {
            Button("删除", role: .destructive) {
                if let book = pendingDelete {
                    store.delete(book.id)
                }
                pendingDelete = nil
            }
            Button("取消", role: .cancel) { pendingDelete = nil }
        } message: {
            Text(pendingDelete?.title ?? "")
        }
        .alert("导入失败", isPresented: errorBinding) {
            Button("好", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - 书架

    private var shelf: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 22) {
                ForEach(store.books) { book in
                    NavigationLink(value: book) {
                        BookCard(book: book, coverURL: store.coverFile(for: book))
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(role: .destructive) {
                            pendingDelete = book
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "books.vertical")
                .font(.system(size: 46, weight: .light))
                .foregroundStyle(.tertiary)
            Text("书架是空的")
                .font(.system(size: 16, weight: .medium))
            Text("导入 TXT / EPUB，或者用书源搜一本")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            HStack(spacing: 12) {
                Button {
                    showImporter = true
                } label: {
                    Text("导入文件")
                        .font(.system(size: 14, weight: .medium))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.accentColor, in: Capsule())
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)

                Button {
                    showDiscover = true
                } label: {
                    Text("找书")
                        .font(.system(size: 14, weight: .medium))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.secondary.opacity(0.15), in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 4)
        }
        .padding(32)
    }

    private var addMenu: some View {
        Menu {
            Button {
                showImporter = true
            } label: {
                Label("导入 TXT / EPUB", systemImage: "doc.badge.plus")
            }
            Button {
                showPaste = true
            } label: {
                Label("粘贴文本", systemImage: "text.alignleft")
            }
            Button {
                showDiscover = true
            } label: {
                Label("书源找书", systemImage: "magnifyingglass")
            }
        } label: {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 21))
                .accessibilityLabel("添加书籍")
        }
    }

    private var importTypes: [UTType] {
        var types: [UTType] = [.plainText, .text]
        if let epub = UTType(filenameExtension: "epub") {
            types.append(epub)
        }
        return types
    }

    // MARK: - 导入

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            errorMessage = error.localizedDescription
        case .success(let urls):
            guard !urls.isEmpty else { return }
            importing = true

            Task {
                var failures: [String] = []

                for url in urls {
                    let scoped = url.startAccessingSecurityScopedResource()
                    defer { if scoped { url.stopAccessingSecurityScopedResource() } }

                    let ext = url.pathExtension.lowercased()
                    if ext == "epub" {
                        let id = UUID()
                        do {
                            let imported = try BookImporter.importEPUB(from: url, id: id)
                            await MainActor.run {
                                store.add(
                                    title: imported.title,
                                    author: imported.author,
                                    format: .epub,
                                    chapters: imported.chapters,
                                    id: id
                                )
                            }
                        } catch {
                            AppPaths.remove(AppPaths.bookDir(id))
                            failures.append(url.lastPathComponent)
                        }
                    } else {
                        do {
                            let (title, chapters) = try BookImporter.loadTXT(from: url)
                            await MainActor.run {
                                store.add(title: title, author: "", format: .txt, chapters: chapters)
                            }
                        } catch {
                            failures.append(url.lastPathComponent)
                        }
                    }
                }

                await MainActor.run {
                    importing = false
                    if !failures.isEmpty {
                        errorMessage = "这些文件导入失败：\(failures.joined(separator: "、"))"
                    }
                }
            }
        }
    }

    // MARK: - 绑定

    private var deleteBinding: Binding<Bool> {
        Binding(
            get: { pendingDelete != nil },
            set: { newValue in if !newValue { pendingDelete = nil } }
        )
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { newValue in if !newValue { errorMessage = nil } }
        )
    }
}

#Preview {
    LibraryView()
        .environmentObject(LibraryStore())
        .environmentObject(SourceStore())
        .environmentObject(ReaderSettings())
}
