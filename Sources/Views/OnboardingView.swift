import SwiftUI

// MARK: - Onboarding / Permissions window
// Walks the user through the three permissions, shows live status, and links
// straight to the right System Settings pane. Re-checks status on a timer so the
// ticks flip green as soon as the user grants in System Settings.

struct OnboardingView: View {
    weak var appDelegate: AppDelegate?
    var onDone: () -> Void

    @State private var tick = 0   // bumped by timer to re-read live status

    private let timer = Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("欢迎使用 PunkType 🎙️")
                    .font(.title2).fontWeight(.bold)
                Text("按 ⌥Space 说话，AI 整理后自动打进光标处。开始前，需要授予三个权限：")
                    .font(.callout).foregroundStyle(.secondary)
            }

            permissionRow(
                icon: "mic.fill", title: "麦克风",
                desc: "录下你的声音",
                status: PermissionsService.microphone(),
                primary: ("授权", { PermissionsService.requestMicrophone { _ in tick += 1 } }),
                secondary: ("打开设置", { PermissionsService.openSettings(PermissionsService.micPane) })
            )
            permissionRow(
                icon: "waveform", title: "语音识别",
                desc: "把语音转成文字（本机）",
                status: PermissionsService.speech(),
                primary: ("授权", { PermissionsService.requestSpeech { _ in tick += 1 } }),
                secondary: ("打开设置", { PermissionsService.openSettings(PermissionsService.speechPane) })
            )
            permissionRow(
                icon: "accessibility", title: "辅助功能",
                desc: "自动粘贴、读取选中文字",
                status: PermissionsService.accessibility(),
                primary: ("打开设置", { PermissionsService.openSettings(PermissionsService.accessibilityPane) }),
                secondary: ("提示授权", { PermissionsService.promptAccessibility() })
            )

            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                Text("辅助功能需要在系统设置里手动打开 PunkType 的开关。授权后这里的状态会自动变绿。")
            }
            .font(.caption).foregroundStyle(.secondary)

            Divider()

            HStack {
                Text(PermissionsService.allGranted ? "✅ 全部就绪，可以开始了" : "授予全部权限后即可使用")
                    .font(.callout)
                    .foregroundStyle(PermissionsService.allGranted ? Color.green : .secondary)
                Spacer()
                Button(PermissionsService.allGranted ? "开始使用" : "稍后") { onDone() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 460)
        .id(tick) // force re-read of status on each timer tick
        .onReceive(timer) { _ in tick += 1 }
    }

    @ViewBuilder
    private func permissionRow(
        icon: String, title: String, desc: String,
        status: PermissionsService.Status,
        primary: (String, () -> Void),
        secondary: (String, () -> Void)
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .frame(width: 28)
                .foregroundStyle(status == .granted ? Color.green : .secondary)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title).font(.system(size: 14, weight: .semibold))
                    statusBadge(status)
                }
                Text(desc).font(.caption).foregroundStyle(.secondary)
            }

            Spacer()

            if status != .granted {
                HStack(spacing: 6) {
                    Button(primary.0, action: primary.1)
                    Button(secondary.0, action: secondary.1).buttonStyle(.borderless).font(.caption)
                }
            }
        }
        .padding(12)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func statusBadge(_ s: PermissionsService.Status) -> some View {
        Group {
            switch s {
            case .granted:
                Label("已授权", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
            case .denied:
                Label("未授权", systemImage: "xmark.circle").foregroundStyle(.orange)
            case .notDetermined:
                Label("待授权", systemImage: "circle").foregroundStyle(.secondary)
            }
        }
        .font(.caption2)
        .labelStyle(.titleAndIcon)
    }
}
