import SwiftUI

/// 粘贴文本建书
struct PasteImportView: View {
    @EnvironmentObject private var store: LibraryStore
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var content = ""

    private var canSave: Bool {
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("书名") {
                    TextField("留空则自动命名", text: $title)
                }
                Section("正文") {
                    TextEditor(text: $content)
                        .font(.system(size: 14))
                        .frame(minHeight: 260)
                }
            }
            .navigationTitle("粘贴文本")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") { save() }
                        .disabled(!canSave)
                }
            }
        }
    }

    private func save() {
        let normalized = TextUtil.normalize(content)
        guard !normalized.isEmpty else { return }

        let chapters = ChapterParser.parse(normalized)
        let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = "未命名 \(Date().formatted(date: .numeric, time: .shortened))"

        store.add(
            title: name.isEmpty ? fallback : name,
            author: "",
            format: .txt,
            chapters: chapters
        )
        dismiss()
    }
}
