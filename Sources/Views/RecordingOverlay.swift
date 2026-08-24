import SwiftUI

// MARK: - Recording Overlay (bottom-center compact bar)
//
// Kept deliberately CHEAP to render. Earlier versions used `.regularMaterial`
// (live backdrop blur), `.shadow`, and `.repeatForever` / `.symbolEffect`
// animations — each of those forces a GPU re-composite every frame. During a
// long "processing" wait the panel kept committing Core Animation transactions,
// and the main thread blocked on the render-server sync (waitForCommitId),
// starving STT delivery and the streaming consumer. That was the real cause of
// the "freezes, click the menu bar to recover" hangs. Now: solid background, no
// shadow, and only a native ProgressView (driven by the render server, not the
// main thread) for the busy state.

struct RecordingOverlay: View {
    @ObservedObject var appDelegate: AppDelegate

    var body: some View {
        switch appDelegate.overlayPhase {
        case .listening:  bar { listeningContent }
        case .processing: bar { processingContent }
        case .done:       bar { doneContent }
        case .hidden:     EmptyView()
        }
    }

    @ViewBuilder private func bar<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(width: 240)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(nsColor: .windowBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.primary.opacity(0.12))
                    )
            )
    }

    private var listeningContent: some View {
        HStack(spacing: 10) {
            AudioWaveform(level: appDelegate.audioLevel)
                .frame(width: 75, height: 24)
            Text(appDelegate.statusText)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer()
            Image(systemName: "mic.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.red)
        }
    }

    private var processingContent: some View {
        HStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)
            Text(appDelegate.statusText)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)
            Spacer()
        }
    }

    private var doneContent: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(.green)
            Text(appDelegate.statusText)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)
        }
    }
}

// MARK: - Audio Waveform (listening only)

struct AudioWaveform: View {
    let level: Float

    @State private var samples: [Float] = Array(repeating: 0.05, count: 16)

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<samples.count, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.accentColor.opacity(0.85))
                    .frame(width: 3, height: max(3, CGFloat(samples[i]) * 22))
            }
        }
        .onChange(of: level) { _, newLevel in
            var updated = samples
            updated.removeFirst()
            updated.append(newLevel)
            samples = updated
        }
    }
}
