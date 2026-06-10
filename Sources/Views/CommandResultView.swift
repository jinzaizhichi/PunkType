import SwiftUI

// MARK: - Command Result Panel
// Shown after a command-mode request (selected text + spoken instruction).
// The RESULT is the hero (large, multi-line, scrollable, selectable); the
// spoken instruction is a small caption for context only.
// Buttons: 替换原文 / 复制 / 关闭.

struct CommandResultView: View {
    let instruction: String
    let result: String
    let onCopy: () -> Void
    let onReplace: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header — instruction as a small caption, result label, close
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("处理结果")
                        .font(.system(size: 13, weight: .semibold))
                    if !instruction.isEmpty {
                        Text("指令：\(instruction)")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .help("关闭")
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Divider()

            // Result body — the hero
            ScrollView {
                Text(result)
                    .font(.system(size: 14))
                    .textSelection(.enabled)
                    .lineSpacing(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            // Actions
            HStack(spacing: 10) {
                Button(action: onReplace) {
                    Label("替换原文", systemImage: "arrow.uturn.backward")
                }
                .help("用结果替换你选中的内容（仅在可编辑处有效）")

                Spacer()

                Button(action: onClose) {
                    Text("关闭")
                }

                Button(action: onCopy) {
                    Label("复制", systemImage: "doc.on.doc")
                }
                .keyboardShortcut(.defaultAction)
            }
            .controlSize(.large)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(width: 460, height: 380)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.primary.opacity(0.08))
        )
    }
}
