import SwiftUI

// MARK: - Result Panel
// A floating panel showing a text result with actions. Used in two cases:
//  1. Command mode (selected text + spoken instruction) — paste = 替换原文
//  2. Dictation with no editable cursor focused — paste = 插入到光标
// The RESULT is the hero (large, multi-line, scrollable, selectable).

struct CommandResultView: View {
    let title: String
    let subtitle: String        // instruction or hint; empty hides the line
    let result: String
    let pasteLabel: String      // "替换原文" or "插入到光标"
    let onPaste: () -> Void
    let onCopy: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                    if !subtitle.isEmpty {
                        Text(subtitle)
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
                Button(action: onPaste) {
                    Label(pasteLabel, systemImage: "text.insert")
                }
                .help("把结果放到当前光标处（先点回输入框）")

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
