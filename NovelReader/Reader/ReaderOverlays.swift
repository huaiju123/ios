import SwiftUI

// MARK: - 顶部条

struct ReaderTopBar: View {
    let title: String
    let tint: Color
    let onBack: () -> Void
    let onTOC: () -> Void
    let onSettings: () -> Void

    var body: some View {
        HStack(spacing: 18) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
            }
            .accessibilityLabel("返回")

            Text(title)
                .font(.system(size: 15, weight: .medium))
                .lineLimit(1)

            Spacer(minLength: 8)

            Button(action: onTOC) {
                Image(systemName: "list.bullet")
                    .font(.system(size: 16))
            }
            .accessibilityLabel("目录")

            Button(action: onSettings) {
                Image(systemName: "textformat.size")
                    .font(.system(size: 16))
            }
            .accessibilityLabel("阅读设置")
        }
        .foregroundStyle(tint)
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial)
    }
}

// MARK: - 底部条

struct ReaderBottomBar: View {
    @ObservedObject var vm: ReaderViewModel
    @EnvironmentObject private var settings: ReaderSettings

    @State private var scrubValue: Double?

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Text("\(Int((vm.overallProgress * 100).rounded()))%")
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundStyle(settings.theme.text.opacity(0.6))
                    .frame(width: 36, alignment: .leading)

                Slider(
                    value: Binding(
                        get: { scrubValue ?? vm.overallProgress },
                        set: { scrubValue = $0 }
                    ),
                    in: 0...1,
                    onEditingChanged: { editing in
                        guard !editing, let value = scrubValue else { return }
                        scrubValue = nil
                        vm.seek(to: value)
                    }
                )
                .tint(settings.theme.text.opacity(0.7))
            }
            .padding(.horizontal, 20)

            HStack(alignment: .top, spacing: 0) {
                barButton("上一章", icon: "backward.end") {
                    vm.goToChapter(vm.chapterIndex - 1)
                }
                barButton("目录", icon: "list.bullet") {
                    vm.showTOC = true
                }
                barButton("听书", icon: vm.isSpeaking ? "waveform" : "headphones") {
                    vm.showSpeech = true
                }
                barButton("设置", icon: "textformat.size") {
                    vm.showSettings = true
                }
                barButton("下一章", icon: "forward.end") {
                    vm.goToChapter(vm.chapterIndex + 1)
                }
            }
            .padding(.horizontal, 8)
        }
        .padding(.top, 16)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
    }

    private func barButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 17))
                Text(title)
                    .font(.system(size: 10))
            }
            .frame(maxWidth: .infinity)
            .foregroundStyle(settings.theme.text.opacity(0.85))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 目录

struct ChapterListView: View {
    @ObservedObject var vm: ReaderViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(vm.chapters) { chapter in
                Button {
                    vm.goToChapter(chapter.id)
                    dismiss()
                } label: {
                    HStack(spacing: 10) {
                        Text(chapter.title)
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        if chapter.id == vm.chapterIndex {
                            Image(systemName: "checkmark")
                                .font(.system(size: 13, weight: .semibold))
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(chapter.id == vm.chapterIndex ? Color.accentColor : Color.primary)
            }
            .listStyle(.plain)
            .navigationTitle("目录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}

// MARK: - 阅读设置

struct ReaderSettingsView: View {
    @EnvironmentObject private var settings: ReaderSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("字号") {
                    HStack(spacing: 14) {
                        Text("A").font(.system(size: 13))
                        Slider(value: $settings.fontSize, in: 14...30, step: 1)
                        Text("A").font(.system(size: 21))
                        Text("\(Int(settings.fontSize))")
                            .font(.system(size: 13).monospacedDigit())
                            .frame(width: 26, alignment: .trailing)
                    }
                }

                Section("行距") {
                    HStack(spacing: 14) {
                        Image(systemName: "text.alignleft").font(.system(size: 12))
                        Slider(value: $settings.lineSpacing, in: 2...18, step: 1)
                        Text("\(Int(settings.lineSpacing))")
                            .font(.system(size: 13).monospacedDigit())
                            .frame(width: 26, alignment: .trailing)
                    }
                }

                Section("背景") {
                    HStack(spacing: 10) {
                        ForEach(ReaderTheme.allCases) { theme in
                            Button {
                                settings.theme = theme
                            } label: {
                                VStack(spacing: 6) {
                                    ZStack {
                                        Circle().fill(theme.background)
                                        Text("文")
                                            .font(.system(size: 15))
                                            .foregroundStyle(theme.text)
                                    }
                                    .frame(width: 42, height: 42)
                                    .overlay(
                                        Circle().strokeBorder(
                                            settings.theme == theme ? Color.accentColor : Color.secondary.opacity(0.25),
                                            lineWidth: settings.theme == theme ? 2 : 1
                                        )
                                    )
                                    Text(theme.name)
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section {
                    Toggle("翻页动画", isOn: $settings.animated)
                }
            }
            .navigationTitle("阅读设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
