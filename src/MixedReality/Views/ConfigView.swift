//
//  ConfigView.swift
//  MixedReality
//

import SwiftUI

struct RangeSliderRow: View {
    let title: String
    @Binding var minVal: Int
    @Binding var maxVal: Int
    let range: ClosedRange<Int>

    var body: some View {
        VStack(alignment: .leading) {
            Text(title)

            HStack {
                Slider(value: Binding(
                    get: { Double(minVal) },
                    set: { new in
                        minVal = min(Int(new), maxVal)   // don’t cross
                    }
                ), in: Double(range.lowerBound)...Double(range.upperBound))

                Slider(value: Binding(
                    get: { Double(maxVal) },
                    set: { new in
                        maxVal = max(Int(new), minVal)
                    }
                ), in: Double(range.lowerBound)...Double(range.upperBound))
            }

            Text("\(minVal) – \(maxVal)")
                .font(.caption)
        }
    }
}


struct ConfigView: View {
    private let appModel: AppModel
    
    @State private var viewModel: ConfigViewModel
    
    init(_ appModel: AppModel) {
        self.appModel = appModel
        _viewModel = State(wrappedValue: ConfigViewModel(appModel))
    }
    
    var body: some View {
        Form {
            Section("Prompt Context") {
                RangeSliderRow(
                    title: "Prompt Window",
                    minVal: $viewModel.config.minPromptContextWindow,
                    maxVal: $viewModel.config.maxPromptContextWindow,
                    range: 1...100
                )
            }
            
            Section("Summary Context") {
                RangeSliderRow(
                    title: "Summary Window",
                    minVal: $viewModel.config.minSummaryContextWindow,
                    maxVal: $viewModel.config.maxSummaryContextWindow,
                    range: 1...50
                )
            }
            
            Section("Triggers") {
                RangeSliderRow(
                    title: "Trigger Context",
                    minVal: $viewModel.config.minTriggerContext,
                    maxVal: $viewModel.config.maxTriggerContext,
                    range: 1...20
                )
                
                RangeSliderRow(
                    title: "Trigger Delay (ms)",
                    minVal: $viewModel.config.minTriggerDelayMs,
                    maxVal: $viewModel.config.maxTriggerDelayMs,
                    range: 0...5000
                )
                
                RangeSliderRow(
                    title: "Pause Detection (ms)",
                    minVal: $viewModel.config.minPauseDetectionMs,
                    maxVal: $viewModel.config.maxPauseDetectionMs,
                    range: 0...6000
                )
                
                RangeSliderRow(
                    title: "Trigger Cooldown (ms)",
                    minVal: $viewModel.config.minTriggerCooldownMs,
                    maxVal: $viewModel.config.maxTriggerCooldownMs,
                    range: 1000...60000
                )
                
                Stepper("Min Evaluators: \(viewModel.config.minTriggerEvaluators)",
                        value: $viewModel.config.minTriggerEvaluators,
                        in: 1...10)
            }

            Section("Evaluation Strategies") {
                ForEach(TriggerEvaluationStrategy.allCases, id: \.self) { strategy in

                    Toggle(strategy.rawValue,
                        isOn: Binding(
                            get: {
                                viewModel.config.selectedTriggerEvaluationStrategies.contains(strategy)
                            },
                            set: { isOn in
                                if isOn {
                                    viewModel.config.selectedTriggerEvaluationStrategies.insert(strategy)
                                } else {
                                    viewModel.config.selectedTriggerEvaluationStrategies.remove(strategy)
                                }
                            }
                        )
                    )
                }
            }

            Section("LLMs") {
                Section("OpenAI") {
                    ForEach(OpenAIModel.allCases, id: \.self) { (llm) in
                        Toggle(llm.rawValue, isOn: Binding<Bool>(
                            get: { viewModel.config.selectedLLMs.contains(.openAI(llm)) },
                            set: { isOn in
                                if isOn {
                                    viewModel.config.selectedLLMs.insert(.openAI(llm))
                                } else {
                                    viewModel.config.selectedLLMs.remove(.openAI(llm))
                                }
                            }
                        ))
                    }
                }
            }

            Section("Mini LLMs") {
                Section("OpenAI") {
                    ForEach(OpenAIModel.allCases, id: \.self) { (llm) in
                        Toggle(llm.rawValue, isOn: Binding<Bool>(
                            get: { viewModel.config.selectedMiniLLMs.contains(.openAI(llm)) },
                            set: { isOn in
                                if isOn {
                                    viewModel.config.selectedMiniLLMs.insert(.openAI(llm))
                                } else {
                                    viewModel.config.selectedMiniLLMs.remove(.openAI(llm))
                                }
                            }
                        ))
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationView(AppModel(), initView: .configView)
        .background(.regularMaterial)
        .glassBackgroundEffect()
}

