import SwiftUI

// MARK: - Recording Overlay (bottom-center compact bar)

struct RecordingOverlay: View {
    @ObservedObject var appDelegate: AppDelegate

    var body: some View {
        Group {
            switch appDelegate.overlayPhase {
            case .listening:  listeningBar
            case .processing: processingBar
            case .done:       doneBar
            case .hidden:     EmptyView()
            }
        }
    }

    // Shared frosted background — adapts to light/dark automatically.
    private var barBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(.regularMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.primary.opacity(0.08))
            )
            .shadow(color: .black.opacity(0.18), radius: 8, y: 2)
    }

    // MARK: - Listening: waveform bars

    private var listeningBar: some View {
        HStack(spacing: 10) {
            AudioWaveform(level: appDelegate.audioLevel)
                .frame(width: 75, height: 24)

            // 命令模式时显示「已选中…说出指令」，普通模式显示 Listening...
            Text(appDelegate.statusText)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer()

            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.25))
                    .frame(width: 28, height: 28)
                    .scaleEffect(appDelegate.isRecording ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: appDelegate.isRecording)

                Image(systemName: "mic.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.red)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(width: 240)
        .background(barBackground)
    }

    // MARK: - Processing: progress bar

    private var processingBar: some View {
        HStack(spacing: 10) {
            AnimatedProgressBar()
                .frame(width: 90, height: 4)

            Text(appDelegate.statusText)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)

            Spacer()

            Image(systemName: "brain.head.profile")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .symbolEffect(.pulse, options: .repeating)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(width: 240)
        .background(barBackground)
    }

    // MARK: - Done

    private var doneBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(.green)

            Text(appDelegate.statusText)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(width: 240)
        .background(barBackground)
    }
}

// MARK: - Audio Waveform

struct AudioWaveform: View {
    let level: Float

    @State private var samples: [Float] = Array(repeating: 0.05, count: 16)

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<samples.count, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.accentColor.opacity(0.85))
                    .frame(width: 3, height: max(3, CGFloat(samples[i]) * 22))
                    .animation(.spring(response: 0.15, dampingFraction: 0.6), value: samples[i])
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

// MARK: - Animated Progress Bar

struct AnimatedProgressBar: View {
    @State private var progress: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.primary.opacity(0.15))
                    .frame(height: 4)

                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.accentColor)
                    .frame(width: geo.size.width * progress, height: 4)
                    .animation(.easeInOut(duration: 0.3), value: progress)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                progress = 0.3
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation(.easeOut(duration: 1.5)) {
                    progress = 0.7
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeOut(duration: 2.0)) {
                    progress = 0.95
                }
            }
        }
    }
}
