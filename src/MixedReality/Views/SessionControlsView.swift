import SwiftUI

struct SessionControlsView: View {
    @Environment(AppModel.self) private var appModel
    
    var elapsedTime: TimeInterval
    var onStop: () -> Void
    
    @State private var isVisible = false

    var body: some View {
        HStack(spacing: 14) {
            if appModel.isSessionActive {
                Text(timeString(from: elapsedTime))
                    .font(.system(size: 18, weight: .medium, design: .monospaced))
                    .frame(minWidth: 60, alignment: .leading)
                
                Spacer()
                
                Button(action: onStop) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 34, height: 34)
                        .overlay(
                            Image(systemName: "stop.fill")
                                .foregroundColor(.white)
                                .font(.system(size: 14, weight: .bold))
                        )
                }
                .buttonStyle(.plain)
            } else {
                Text("Ending session...")
                    .font(.system(size: 18, weight: .medium, design: .monospaced))
                    .frame(alignment: .center)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: Capsule())
        .glassBackgroundEffect()
        .frame(width: 240)
        .opacity(isVisible ? 1: 0)
        .animation(.easeIn(duration: 0.5), value: isVisible)
        .onAppear {
            isVisible = true
        }
        .onDisappear {
            isVisible = false
        }
    }

    private func timeString(from interval: TimeInterval) -> String {
        let seconds = Int(interval) % 60
        let minutes = (Int(interval) / 60) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
