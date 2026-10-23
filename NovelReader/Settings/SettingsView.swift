import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var comics: ComicStore
    @EnvironmentObject private var dramas: DramaStore
    @EnvironmentObject private var sources: SourceStore
    @EnvironmentObject private var settings: ReaderSettings

    @State private var storageText = "计算中…"
    @State private var showCleanConfirm = false

    private var version: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }

    var body: some View {
        NavigationStack {
            List {
                Section("内容") {
                    NavigationLink {
                        ReaderSettingsView()
                    } label: {
                        Label("阅读设置", systemImage: "textformat")
                    }
                    NavigationLink {
                        SourceManagerView()
                    } label: {
                        Label("书源", systemImage: "antenna.radiowaves.left.and.right")
                    }
                }

                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "tortoise").font(.system(size: 12))
                        Slider(value: $settings.speechRate, in: 0.35...0.7, step: 0.05)
                        Image(systemName: "hare").font(.system(size: 12))
                    }
                } header: {
                    Text("听书")
                } footer: {
                    Text("语速只影响之后开始的朗读。")
                }

                Section("存储") {
                    HStack {
                        Text("已用空间")
                        Spacer()
                        Text(storageText).foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("书 / 漫画 / 短剧")
                        Spacer()
                        Text("\(library.books.count) / \(comics.comics.count) / \(dramas.dramas.count)")
                            .foregroundStyle(.secondary)
                    }
                    Button("清理缓存", role: .destructive) {
                        showCleanConfirm = true
                    }
                }

                Section("关于") {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text(version).foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("墨读 · 小说 / 漫画 / 短剧")
                            .font(.system(size: 14, weight: .medium))
                        Text("纯本地存储：所有内容都在沙盒里，App 不收集任何数据，也不会上传你的书。")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("我的")
            .onAppear { refreshStorage() }
            .confirmationDialog("清理缓存？", isPresented: $showCleanConfirm, titleVisibility: .visible) {
                Button("清理", role: .destructive) {
                    AppPaths.remove(AppPaths.cacheFolder)
                    refreshStorage()
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("只会删掉临时缓存，书和进度不受影响。")
            }
        }
    }

    private func refreshStorage() {
        let size = AppPaths.size(of: AppPaths.root)
        storageText = AppPaths.formatSize(size)
    }
}
