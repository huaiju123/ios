import SwiftUI
import UniformTypeIdentifiers

struct DramaLibraryView: View {
    @EnvironmentObject private var store: DramaStore

    @State private var showImporter = false
    @State private var playing: DramaMeta?
    @State private var pendingDelete: DramaMeta?
    @State private var errorMessage: String?
    @State private var importing = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                if store.dramas.isEmpty {
                    emptyState
                } else {
                    list
                }

                if importing {
                    ProgressView("导入中…")
                        .padding(20)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
            .navigationTitle("短剧")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showImporter = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 21))
                    }
                    .accessibilityLabel("导入视频")
                }
            }
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.movie, .video],
            allowsMultipleSelection: true
        ) { result in
            handleImport(result)
        }
        .fullScreenCover(item: $playing) { drama in
            DramaPlayerView(drama: drama)
        }
        .confirmationDialog("删除这部短剧？", isPresented: deleteBinding, titleVisibility: .visible) {
            Button("删除", role: .destructive) {
                if let drama = pendingDelete {
                    store.delete(drama.id)
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

    private var list: some View {
        List {
            ForEach(store.dramas) { drama in
                Button {
                    playing = drama
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(LinearGradient(
                                    colors: [Color(red: 0.30, green: 0.36, blue: 0.46),
                                             Color(red: 0.12, green: 0.15, blue: 0.20)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                                .frame(width: 66, height: 88)
                            Image(systemName: "play.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(.white.opacity(0.9))
                        }

                        VStack(alignment: .leading, spacing: 5) {
                            Text(drama.title)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            Text("\(drama.countText) · \(drama.progressText)")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button(role: .destructive) {
                        pendingDelete = drama
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "play.rectangle")
                .font(.system(size: 46, weight: .light))
                .foregroundStyle(.tertiary)
            Text("还没有短剧")
                .font(.system(size: 16, weight: .medium))
            Text("导入 mp4 / mov，一次选多个文件就会\n按文件名顺序排成多集。")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                showImporter = true
            } label: {
                Text("导入视频")
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
            guard !urls.isEmpty else { return }
            importing = true

            Task {
                let id = UUID()
                var episodes: [Episode] = []
                var failures: [String] = []

                for url in urls {
                    let scoped = url.startAccessingSecurityScopedResource()
                    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                    do {
                        let copied = try VideoImporter.copy([url], to: id)
                        episodes.append(contentsOf: copied)
                    } catch {
                        failures.append(url.lastPathComponent)
                    }
                }

                await MainActor.run {
                    importing = false

                    if !episodes.isEmpty {
                        let title: String
                        if urls.count == 1 {
                            title = urls[0].deletingPathExtension().lastPathComponent
                        } else {
                            let folder = urls[0].deletingLastPathComponent().lastPathComponent
                            title = folder.isEmpty ? "短剧合集" : folder
                        }
                        store.add(title: title, episodes: episodes, id: id)
                    }

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
