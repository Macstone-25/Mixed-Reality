//
//  RangeSlider.swift
//  MixedReality
//

import SwiftUI

struct RangeSlider: View {
    let title: String
    var description: String? = nil
    @Binding var minVal: Int
    @Binding var maxVal: Int
    let lowerBound: Double
    let upperBound: Double
    
    private let step: Int = 1
    
    private func stepValue(_ value: DragGesture.Value, _ trackWidth: CGFloat) -> Int {
        let x: CGFloat = min(max(0, value.location.x), trackWidth)
        let percent: Double = trackWidth == 0 ? 0 : Double(x / trackWidth)
        let span: Double = (upperBound - lowerBound)
        let rawValue: Double = lowerBound + percent * span
        let stepped: Int = Int((rawValue / Double(step)).rounded()) * step
        return stepped
    }
    
    private func handleX(_ value: Int, width: CGFloat) -> CGFloat {
        let valueD: Double = Double(value)
        let span: Double = (upperBound - lowerBound)
        let percent: Double = span == 0 ? 0 : (valueD - lowerBound) / span
        let clampedPercent: Double = min(max(percent, 0), 1)
        let result: CGFloat = CGFloat(clampedPercent) * width
        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
            
            if let description = description {
                Text(description)
                    .font(.caption)
            }

            GeometryReader { geo in
                let trackWidth: CGFloat = geo.size.width
                let minHandleX: CGFloat = handleX(minVal, width: trackWidth)
                let maxHandleX: CGFloat = handleX(maxVal, width: trackWidth)
                let activeWidth: CGFloat = max(0, maxHandleX - minHandleX)

                ZStack(alignment: .leading) {

                    // Background track
                    Capsule()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 6)

                    // Active range highlight
                    Capsule()
                        .fill(Color.accentColor)
                        .frame(width: activeWidth, height: 6)
                        .offset(x: minHandleX)

                    // Min handle
                    Circle()
                        .fill(Color.white)
                        .frame(width: 22, height: 22)
                        .shadow(radius: 2)
                        .offset(x: minHandleX - 11)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    let stepped: Int = stepValue(value, trackWidth)
                                    let clamped: Int = min(stepped, maxVal)
                                    minVal = clamped
                                }
                        )

                    // Max handle
                    Circle()
                        .fill(Color.white)
                        .frame(width: 22, height: 22)
                        .shadow(radius: 2)
                        .offset(x: maxHandleX - 11)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    let stepped: Int = stepValue(value, trackWidth)
                                    let clamped: Int = max(stepped, minVal)
                                    maxVal = clamped
                                }
                        )
                }
            }
            .frame(height: 30)

            // Value labels
            Text("\(minVal) – \(maxVal)")
                .font(.caption2).bold()
                .monospaced()
        }
    }
}
