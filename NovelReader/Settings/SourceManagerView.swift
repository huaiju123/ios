import SwiftUI

struct SourceManagerView: View {
    @EnvironmentObject private var sources: SourceStore

    @State private var showEditor = false
    @State private var draft = SourceTemplate.json
    @State private var message: String?

    var body: some View {
        List {
            if sources.sources.isEmpty {
                Section {
                    Text("还没有书源")
                        .foregroundStyle(.secondary)
                }
            } else {
                Section("已添加") {
                    ForEach(sources.sources) { source in
                        row(source)
                    }
                    .onDelete(perform: delete)
                }
            }

            Section {
                Button("粘贴 JSON 添加") {
                    draft = SourceTemplate.json
                    showEditor = true
                }
            } footer: {
                Text("规则是 CSS 选择器：`h3 a` 取文本，`h3 a@href` 取属性。模板是 example.com，要换成你自己的源。左滑删除，开关控制是否参与搜索。")
            }
        }
        .navigationTitle("书源")
        .sheet(isPresented: $showEditor) { editor }
        .alert("导入失败", isPresented: messageBinding) {
            Button("好", role: .cancel) { message = nil }
        } message: {
            Text(message ?? "")
        }
    }

    private func row(_ source: BookSource) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(source.name)
                Text(source.baseURL)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { source.enabled },
                set: { _ in sources.toggle(source.id) }
            ))
            .labelsHidden()
        }
    }

    private var editor: some View {
        NavigationStack {
            TextEditor(text: $draft)
                .font(.system(size: 12, design: .monospaced))
                .padding(8)
                .navigationTitle("书源 JSON")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("取消") { showEditor = false }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("保存") { save() }
                    }
                }
        }
    }

    private var messageBinding: Binding<Bool> {
        Binding(
            get: { message != nil },
            set: { newValue in if !newValue { message = nil } }
        )
    }

    private func save() {
        do {
            let count = try sources.importJSON(draft)
            showEditor = false
            if count <= 0 {
                message = "没有导入任何书源"
            }
        } catch {
            message = "JSON 格式不对：\(error.localizedDescription)"
        }
    }

    private func delete(_ offsets: IndexSet) {
        for index in offsets.sorted(by: >) {
            guard sources.sources.indices.contains(index) else { continue }
            sources.remove(sources.sources[index].id)
        }
    }
}
