import SwiftUI

struct ReaderView: View {
    @StateObject private var vm: ReaderViewModel
    @EnvironmentObject private var settings: ReaderSettings
    @Environment(\.dismiss) private var dismiss

    init(book: BookMeta, library: LibraryStore, sources: SourceStore, settings: ReaderSettings) {
        _vm = StateObject(wrappedValue: ReaderViewModel(
            book: book,
            library: library,
            sources: sources,
            settings: settings
        ))
    }

    var body: some View {
        ZStack {
            settings.theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                GeometryReader { proxy in
                    pageArea
                        .onAppear { vm.relayout(size: proxy.size) }
                        .onChange(of: proxy.size) { _, newSize in
                            vm.relayout(size: newSize)
                        }
                }
                footer
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, 2)

            if vm.isLoading {
                loadingOverlay
            }

            if vm.showBars {
                bars
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { vm.start() }
        .onChange(of: settings.revision) { _, _ in
            vm.relayout()
        }
        .sheet(isPresented: $vm.showTOC) {
            ChapterListView(vm: vm)
        }
        .sheet(isPresented: $vm.showSettings) {
            ReaderSettingsView()
        }
        .sheet(isPresented: $vm.showSpeech) {
            SpeechPanel(vm: vm)
        }
        .alert("出错了", isPresented: errorBinding) {
            Button("好", role: .cancel) { vm.errorMessage = nil }
        } message: {
            Text(vm.errorMessage ?? "")
        }
        .onDisappear {
            vm.save()
            vm.stopSpeech()
        }
    }

    // MARK: - 正文

    private var pageArea: some View {
        ZStack {
            if let imageURL = vm.pageImageURL {
                ImagePageView(url: imageURL)
                    .id(pageKey)
                    .transition(pageTransition)
            } else {
                PageTextView(attributed: vm.pageText)
                    .id(pageKey)
                    .transition(pageTransition)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 24)
                .onEnded { value in
                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                    if value.translation.width < -40 {
                        withAnimation(turnAnimation) { vm.nextPage() }
                    } else if value.translation.width > 40 {
                        withAnimation(turnAnimation) { vm.previousPage() }
                    }
                }
        )
        .overlay { tapZones }
    }

    private var tapZones: some View {
        HStack(spacing: 0) {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(turnAnimation) { vm.previousPage() }
                }
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { vm.toggleBars() }
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(turnAnimation) { vm.nextPage() }
                }
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            if vm.isSpeaking {
                Image(systemName: "waveform")
                    .font(.system(size: 10))
            }
            Text(vm.chapterTitle)
                .lineLimit(1)
            Spacer(minLength: 8)
            Text("\(vm.pageIndex + 1) / \(max(vm.pages.count, 1))")
                .monospacedDigit()
        }
        .font(.system(size: 11))
        .foregroundStyle(settings.theme.text.opacity(0.4))
        .padding(.top, 6)
    }

    private var loadingOverlay: some View {
        VStack(spacing: 10) {
            ProgressView()
            Text("加载中…")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .padding(22)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - 工具条

    private var bars: some View {
        VStack(spacing: 0) {
            ReaderTopBar(
                title: vm.chapterTitle,
                tint: settings.theme.text,
                onBack: {
                    vm.save()
                    dismiss()
                },
                onTOC: { vm.showTOC = true },
                onSettings: { vm.showSettings = true }
            )
            Spacer(minLength: 0)
                .contentShape(Rectangle())
                .onTapGesture { vm.toggleBars() }
            ReaderBottomBar(vm: vm)
        }
        .transition(.opacity)
    }

    // MARK: - 绑定与动画

    private var pageKey: Int {
        vm.chapterIndex * 100_000 + vm.pageIndex
    }

    private var turnAnimation: Animation? {
        settings.animated ? .easeOut(duration: 0.16) : nil
    }

    private var pageTransition: AnyTransition {
        guard settings.animated else { return .identity }
        let forward = vm.direction >= 0
        return .asymmetric(
            insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity),
            removal: .move(edge: forward ? .leading : .trailing).combined(with: .opacity)
        )
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { vm.errorMessage != nil },
            set: { newValue in if !newValue { vm.errorMessage = nil } }
        )
    }
}

/// EPUB 里的插图页
struct ImagePageView: View {
    let url: URL

    var body: some View {
        GeometryReader { proxy in
            Group {
                if url.isFileURL {
                    if let image = ImageTools.cachedImage(path: url, maxPixel: 2400) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                    } else {
                        placeholder
                    }
                } else {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFit()
                    } placeholder: {
                        ProgressView()
                    }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }

    private var placeholder: some View {
        ProgressView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
