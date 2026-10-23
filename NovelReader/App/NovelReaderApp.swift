import SwiftUI

@main
struct NovelReaderApp: App {
    @StateObject private var library = LibraryStore()
    @StateObject private var comics = ComicStore()
    @StateObject private var dramas = DramaStore()
    @StateObject private var sources = SourceStore()
    @StateObject private var settings = ReaderSettings()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(library)
                .environmentObject(comics)
                .environmentObject(dramas)
                .environmentObject(sources)
                .environmentObject(settings)
        }
    }
}

struct RootView: View {
    var body: some View {
        TabView {
            LibraryView()
                .tabItem { Label("书架", systemImage: "books.vertical") }

            ComicLibraryView()
                .tabItem { Label("漫画", systemImage: "photo.on.rectangle.angled") }

            DramaLibraryView()
                .tabItem { Label("短剧", systemImage: "play.rectangle") }

            SettingsView()
                .tabItem { Label("我的", systemImage: "person.crop.circle") }
        }
    }
}
