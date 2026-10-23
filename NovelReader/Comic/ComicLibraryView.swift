import SwiftUI
import UniformTypeIdentifiers

struct ComicLibraryView: View {
    @EnvironmentObject private var store: ComicStore

    @State private var showImporter = false
    @State private var pendingDelete: ComicMeta?
    @State private var errorMessage: String?
    @State private var importing = false

    private let columns = [
        GridItem(.adaptive(minimum: 104, maximum: 150), spacing: 18, alignment: .top)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                if store.comics.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 22) {
                            ForEach(store.comics) { comic in
                                NavigationLink {
                                    ComicReaderView(comic: comic)
                                } label: {
                                    ComicCard(comic: comic, coverURL: store.coverFile(for: comic))
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        pendingDelete = comic
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

                if importing {
                    ProgressView("解压中…")
                        .padding(20)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
            .navigationTitle("漫画")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showImporter = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 21))
                    }
                    .accessibilityLabel("导入漫画")
                }
            }
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: allowedTypes,
            allowsMultipleSelection: true
        ) { result in
            handleImport(result)
        }
        .confirmationDialog("删除这本漫画？", isPresented: deleteBinding, titleVisibility: .visible) {
            Button("删除", role: .destructive) {
                if let comic = pendingDelete {
                    store.delete(comic.id)
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

    private var allowedTypes: [UTType] {
        var types: [UTType] = [.zip]
        if let cbz = UTType(filenameExtension: "cbz") {
            types.append(cbz)
        }
        return types
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 46, weight: .light))
                .foregroundStyle(.tertiary)
            Text("还没有漫画")
                .font(.system(size: 16, weight: .medium))
            Text("导入 cbz 或 zip（里面是图片），\n会自动按文件名排序成页。")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                showImporter = true
            } label: {
                Text("导入漫画")
                    .font(.system(size: 15, weight: .medium))
                    .padding(.horizontal, 22)
                    .padding(.vertical, 10)
                    .background(Color.accentColor, in: Capsule())
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(32)
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            errorMessage = error.localizedDescription
        case .success(let urls):
            importing = true
            Task {
                var failures: [String] = []
                for url in urls {
                    let scoped = url.startAccessingSecurityScopedResource()
                    defer { if scoped { url.stopAccessingSecurityScopedResource() } }

                    let id = UUID()
                    do {
                        let files = try ComicImporter.extract(zip: url, to: id)
                        let title = url.deletingPathExtension().lastPathComponent
                        await MainActor.run {
                            store.add(title: title, files: files, id: id)
                        }
                    } catch {
                        failures.append(url.lastPathComponent)
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

struct ComicCard: View {
    let comic: ComicMeta
    let coverURL: URL?

    private static let palettes: [(Color, Color)] = [
        (Color(red: 0.36, green: 0.47, blue: 0.62), Color(red: 0.14, green: 0.21, blue: 0.32)),
        (Color(red: 0.72, green: 0.45, blue: 0.36), Color(red: 0.40, green: 0.20, blue: 0.16)),
        (Color(red: 0.40, green: 0.58, blue: 0.48), Color(red: 0.15, green: 0.28, blue: 0.22)),
        (Color(red: 0.56, green: 0.44, blue: 0.62), Color(red: 0.26, green: 0.17, blue: 0.34))
    ]

    private var gradient: LinearGradient {
        let index = (comic.id.hashValue & 0x7FFF_FFFF) % Self.palettes.count
        let palette = Self.palettes[index]
        return LinearGradient(colors: [palette.0, palette.1], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(gradient)

                if let coverURL = coverURL,
                   let image = ImageTools.cachedImage(path: coverURL, maxPixel: 400) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .clipped()
                } else {
                    Image(systemName: "photo")
                        .font(.system(size: 26, weight: .light))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .aspectRatio(3.0 / 4.0, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .shadow(color: .black.opacity(0.15), radius: 5, x: 0, y: 3)

            Text(comic.title)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)
            Text(comic.progressText)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}
