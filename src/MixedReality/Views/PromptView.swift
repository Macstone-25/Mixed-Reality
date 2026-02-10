import SwiftUI

struct PromptView: View {
    private let appModel: AppModel
    private let sessionViewModel: SessionViewModel

    @State private var viewModel: PromptViewModel

    // Stores measured heights for each candidate width
    @State private var heightByWidth: [CGFloat: CGFloat] = [:]
    @State private var chosenWidth: CGFloat = 420
    @State private var chosenHeight: CGFloat = 120

    init(appModel: AppModel, sessionViewModel: SessionViewModel) {
        self.appModel = appModel
        self.sessionViewModel = sessionViewModel
        _viewModel = State(wrappedValue: PromptViewModel(appModel: appModel, sessionViewModel: sessionViewModel))
    }

    private struct HeightMapKey: PreferenceKey {
        static var defaultValue: [CGFloat: CGFloat] = [:]
        static func reduce(value: inout [CGFloat: CGFloat], nextValue: () -> [CGFloat: CGFloat]) {
            value.merge(nextValue(), uniquingKeysWith: { _, new in new })
        }
    }

    var body: some View {
        let fontSize: CGFloat = 30
        let hPad: CGFloat = 24
        let vPad: CGFloat = 14
        let bottomSafety: CGFloat = 18

        let candidateWidths: [CGFloat] = [420, 480, 540, 600]

        // If the bubble would exceed this height, we widen it (instead of scrolling)
        let targetMaxHeight: CGFloat = 240

        // Cap so it never becomes very long
        let hardMaxHeight: CGFloat = 320

        let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)

        let trimmed = sessionViewModel.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let wordCount = trimmed.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
        let isShortPrompt = !trimmed.isEmpty && trimmed.count <= 18 && wordCount <= 2

        let textAlignment: TextAlignment = isShortPrompt ? .center : .leading
        let frameAlignment: Alignment = isShortPrompt ? .center : .leading

        // Base text
        let promptText = Text(sessionViewModel.prompt)
            .font(.system(size: fontSize))
            .foregroundStyle(.white)
            .multilineTextAlignment(textAlignment)
            .lineLimit(nil)
            .frame(maxWidth: .infinity, alignment: frameAlignment)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 2)
            .padding(.bottom, bottomSafety)

        // Visible bubble (No ScrollView)
        let visible = promptText
            .padding(.horizontal, hPad)
            .padding(.vertical, vPad)
            .frame(width: chosenWidth, height: chosenHeight, alignment: frameAlignment)
            .background(.thickMaterial, in: shape)
            .overlay(shape.stroke(.white.opacity(0.18), lineWidth: 1))
            .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 6)
            .contentShape(shape)
            .onTapGesture { sessionViewModel.prompt = "" }
            .opacity(viewModel.isVisible ? 1 : 0)
            .animation(.easeInOut(duration: 0.25), value: viewModel.isVisible)

        // Hidden measurers for each candidate width
        let measurers = ZStack {
            ForEach(candidateWidths, id: \.self) { w in
                promptText
                    .padding(.horizontal, hPad)
                    .padding(.vertical, vPad)
                    .frame(width: w, alignment: frameAlignment)
                    .background(
                        GeometryReader { proxy in
                            Color.clear.preference(key: HeightMapKey.self, value: [w: proxy.size.height])
                        }
                    )
                    .hidden()
                    .allowsHitTesting(false)
            }
        }

        return ZStack {
            visible
            measurers
        }
        // Reset measurements when the prompt changes (prevents stale sizing)
        .onChange(of: sessionViewModel.prompt) { _, _ in
            heightByWidth = [:]
        }
        .onPreferenceChange(HeightMapKey.self) { map in
            heightByWidth.merge(map, uniquingKeysWith: { _, new in new })

            // Pick the smallest width that keeps height under targetMaxHeight
            if let bestWidth = candidateWidths.first(where: { (heightByWidth[$0] ?? .greatestFiniteMagnitude) <= targetMaxHeight }),
               let bestHeight = heightByWidth[bestWidth] {
                chosenWidth = bestWidth
                chosenHeight = min(bestHeight, hardMaxHeight)
                return
            }

            // If none fit under targetMaxHeight, use max width and allow up to hardMaxHeight
            if let maxWidth = candidateWidths.last,
               let heightAtMax = heightByWidth[maxWidth] {
                chosenWidth = maxWidth
                chosenHeight = min(heightAtMax, hardMaxHeight)
            }
        }
    }
}
