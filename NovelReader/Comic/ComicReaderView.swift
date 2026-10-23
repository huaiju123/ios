import SwiftUI

struct ComicReaderView: View {
    let comic: ComicMeta

    @EnvironmentObject private var store: ComicStore
    @Environment(\.dismiss) private var dismiss

    @State private var index = 0
    @State private var showBars = true
    @State private var scrollMode = false
    @State private var pages: [String] = []

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            content

            if showBars {
                bars
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            pages = store.pages(of: comic.id)
            index = comic.lastPage.clamped(to: 0...max(pages.count - 1, 0))
        }
        .onChange(of: index) { _, newValue in
            store.updatePage(newValue, for: comic.id)
        }
        .onDisappear {
            store.updatePage(index, for: comic.id)
        }
    }

    // MARK: - 内容

    @ViewBuilder
    private var content: some View {
        if pages.isEmpty {
            ProgressView()
                .tint(.white)
        } else if scrollMode {
            scrollContent
        } else {
            pagedContent
        }
    }

    private var pagedContent: some View {
        TabView(selection: $index) {
            ForEach(0..<pages.count, id: \.self) { pageIndex in
                pageView(pageIndex)
                    .tag(pageIndex)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .ignoresSafeArea()
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.15)) { showBars.toggle() }
        }
    }

    private var scrollContent: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(0..<pages.count, id: \.self) { pageIndex in
                        if let url = pageURL(pageIndex),
                           let image = ImageTools.cachedImage(path: url, maxPixel: 2200) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity)
                                .id(pageIndex)
                                .onAppear {
                                    if pageIndex > index {
                                        index = pageIndex
                                    }
                                }
                        }
                    }
                }
            }
            .onAppear {
                let start = index
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    proxy.scrollTo(start, anchor: .top)
                }
            }
        }
    }

    @ViewBuilder
    private func pageView(_ pageIndex: Int) -> some View {
        if let url = pageURL(pageIndex),
           let image = ImageTools.cachedImage(path: url, maxPixel: 2200) {
            ZoomableImageView(image: image)
        } else {
            ProgressView()
                .tint(.white)
        }
    }

    private func pageURL(_ pageIndex: Int) -> URL? {
        guard pages.indices.contains(pageIndex) else { return nil }
        return AppPaths.comicDir(comic.id).appendingPathComponent(pages[pageIndex])
    }

    // MARK: - 工具条

    private var bars: some View {
        VStack {
            HStack(spacing: 14) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                }

                Text(comic.title)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)

                Spacer()

                Button {
                    scrollMode.toggle()
                } label: {
                    Text(scrollMode ? "翻页" : "上下")
                        .font(.system(size: 13))
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color.black.opacity(0.45))

            Spacer()

            VStack(spacing: 8) {
                if !scrollMode {
                    Slider(
                        value: Binding(
                            get: { Double(index) },
                            set: { index = Int($0.rounded()) }
                        ),
                        in: 0...Double(max(pages.count - 1, 0))
                    )
                    .tint(.white)
                }
                Text("\(index + 1) / \(max(pages.count, 1))")
                    .font(.system(size: 12).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.85))
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(Color.black.opacity(0.45))
        }
        .transition(.opacity)
    }
}
