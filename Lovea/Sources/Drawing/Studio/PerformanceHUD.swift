import os
import SwiftUI

/// Frame budgets from the masterplan. Values above them show in red.
enum PerformanceTarget {
    static let frame120Hz = 8.3
    static let frame60Hz = 16.7

    static func budget(maxFPS: Int) -> Double {
        maxFPS >= 120 ? frame120Hz : frame60Hz
    }
}

/// Small overlay: fps, worst frame of the last 2 s, GPU time, free memory, and the glass switch
/// for measuring Liquid Glass. Turned on in Profil → Leistungsanzeige.
/// The canvas only draws when something changes, so without input it shows "Ruhe" instead of a
/// frame rate: a handful of frames per second there means "nothing to draw", not "slow".
struct PerformanceHUD: View {
    let session: DrawingSession
    @AppStorage("studio.glass") private var glass = true

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { _ in
            let log = session.engine?.frameLog ?? []
            let now = CACurrentMediaTime()
            let fps = log.filter { now - $0.time <= 1 }.count
            let idle = now - (log.last?.time ?? 0) > 0.25
            let worst = log.filter { now - $0.time <= 2 }.map(\.milliseconds).max() ?? 0
            let gpu = (session.engine?.gpuLog ?? []).filter { now - $0.time <= 2 }.map(\.milliseconds).max() ?? 0
            let freeMB = Double(os_proc_available_memory()) / 1_048_576
            let maxFPS = session.canvasState.canvas?.window?.windowScene?.screen.maximumFramesPerSecond ?? 60
            let budget = PerformanceTarget.budget(maxFPS: maxFPS)
            VStack(alignment: .leading, spacing: 2) {
                Text(idle ? "Ruhe" : "\(fps) fps")
                Text(String(format: "CPU max %.1f ms", worst)).foregroundStyle(worst > budget ? .red : .primary)
                Text(String(format: "GPU max %.1f ms", gpu)).foregroundStyle(gpu > budget ? .red : .primary)
                Text(String(format: "RAM frei %.0f MB", freeMB))
                Toggle("Glas", isOn: $glass)
                    .toggleStyle(.switch)
                    .controlSize(.mini)
            }
            .font(.caption2.monospacedDigit())
            .padding(8)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
            .fixedSize()
        }
    }
}
