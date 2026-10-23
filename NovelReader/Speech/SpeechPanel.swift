import SwiftUI
import AVFoundation

/// 听书面板
struct SpeechPanel: View {
    @ObservedObject var vm: ReaderViewModel
    @EnvironmentObject private var settings: ReaderSettings
    @Environment(\.dismiss) private var dismiss

    private var voices: [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix("zh") }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 20) {
                        Button {
                            vm.toggleSpeech()
                        } label: {
                            Image(systemName: vm.isSpeaking ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 46))
                        }
                        .buttonStyle(.plain)

                        Button {
                            vm.stopSpeech()
                        } label: {
                            Image(systemName: "stop.circle")
                                .font(.system(size: 30))
                                .foregroundStyle(vm.isSpeaking ? Color.primary : Color.secondary)
                        }
                        .buttonStyle(.plain)
                        .disabled(!vm.isSpeaking)

                        Spacer()
                    }
                    .padding(.vertical, 8)
                } footer: {
                    Text("从当前页开始读。锁屏或切到后台会继续朗读，锁屏界面可以直接暂停。")
                }

                Section("语速") {
                    HStack(spacing: 12) {
                        Image(systemName: "tortoise").font(.system(size: 12))
                        Slider(value: $settings.speechRate, in: 0.35...0.7, step: 0.05)
                        Image(systemName: "hare").font(.system(size: 12))
                    }
                }

                Section("音色") {
                    Picker("音色", selection: $settings.voiceIdentifier) {
                        Text("系统默认").tag("")
                        ForEach(voices, id: \.identifier) { voice in
                            Text(voice.name).tag(voice.identifier)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }
            }
            .navigationTitle("听书")
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
