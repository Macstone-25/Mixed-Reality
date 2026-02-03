//
//  ConfigView.swift
//  MixedReality
//

import SwiftUI

struct ConfigView: View {
    private let appModel: AppModel
    
    @State private var viewModel: ConfigViewModel
    
    init(_ appModel: AppModel) {
        self.appModel = appModel
        _viewModel = State(wrappedValue: ConfigViewModel(appModel))
    }
    
    var body: some View {
        VStack(spacing: 24) {
            Form {
                Section("Context Windows") {
                    RangeSlider(
                        title: "Prompt Generation",
                        description: "The number of transcript lines used to generate prompts.",
                        minVal: $viewModel.config.minPromptContextWindow,
                        maxVal: $viewModel.config.maxPromptContextWindow,
                        lowerBound: 1,
                        upperBound: 100
                    )
                    
                    RangeSlider(
                        title: "Transcript Summarization",
                        description: "The number of transcript lines used to update the conversation summary, which is used to provide additional context during prompt generation beyond the transcript lines set above.",
                        minVal: $viewModel.config.minSummaryContextWindow,
                        maxVal: $viewModel.config.maxSummaryContextWindow,
                        lowerBound: 1,
                        upperBound: 50
                    )
                    
                    RangeSlider(
                        title: "Trigger Evaluation",
                        description: "The number of transcript lines used to evaluate whether a prompt should be generated.",
                        minVal: $viewModel.config.minTriggerContext,
                        maxVal: $viewModel.config.maxTriggerContext,
                        lowerBound: 4,
                        upperBound: 20
                    )
                    
                }
                 
                Section("Trigger Timing") {
                    RangeSlider(
                        title: "Evaluation Delay (ms)",
                        description: "The time between a transcript chunk arriving and trigger evaluators running. If another chunk arrives before the end of the delay, the evaluators will not run. This is important to avoid excessive and unnecessary AI usage while the user is speaking normally.",
                        minVal: $viewModel.config.minTriggerDelayMs,
                        maxVal: $viewModel.config.maxTriggerDelayMs,
                        lowerBound: 250,
                        upperBound: 5000
                    )
                    
                    RangeSlider(
                        title: "Trigger Cooldown (ms)",
                        description: "Sets the minimum time between any two prompts.",
                        minVal: $viewModel.config.minTriggerCooldownMs,
                        maxVal: $viewModel.config.maxTriggerCooldownMs,
                        lowerBound: 1000,
                        upperBound: 60000
                    )
                    
                    RangeSlider(
                        title: "Pause Detection (ms)",
                        description: "The duration of silence necessary to trigger the Pause Evaluator.",
                        minVal: $viewModel.config.minPauseDetectionMs,
                        maxVal: $viewModel.config.maxPauseDetectionMs,
                        lowerBound: 250,
                        upperBound: 5000
                    )
                }
                
                Section("Trigger Evaluation Strategies") {
                    Stepper("Minimum Evaluators: \(viewModel.config.minTriggerEvaluators)",
                            value: $viewModel.config.minTriggerEvaluators,
                            in: 1...10)
                    
                    Text("The trigger engine will use a random subset of the enabled evaluation strategies below (with at least the minimum number set above) to determine if prompts should be generated.")
                    
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
                    
                    Text("""
                    Pause Evaluator: Triggers after a fixed duration of silence.
                        
                    Filler Evaluator: Triggers after 3 sequential sentences ending with a filler word (e.g. "hm", "um", "uh").
                    """)
                        .font(.caption)
                }
                
                Section("Large AI Models") {
                    Text("The models used for infrequent tasks (e.g. prompt generation).")
                    
                    ForEach(OpenAIModel.allCases, id: \.self) { (llm) in
                        Toggle("\(llm.rawValue) (OpenAI)", isOn: Binding<Bool>(
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
                
                Section("Mini AI Models") {
                    Text("The models used for high-frequency tasks (e.g. transcript summarization).")
                    
                    ForEach(OpenAIModel.allCases, id: \.self) { (llm) in
                        Toggle("\(llm.rawValue) (OpenAI)", isOn: Binding<Bool>(
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
            
            HStack(spacing: 12) {
                Button("Reset to Defaults") {
                    viewModel.resetConfig()
                }
                .buttonStyle(.borderedProminent)
                .glassBackgroundEffect()
                .tint(.red)
                
                Spacer()
                
                Button("Cancel") {
                    viewModel.undoChanges()
                }
                .buttonStyle(.borderedProminent)
                .glassBackgroundEffect()
                
                Button("Save Changes") {
                    viewModel.applyChanges()
                }
                .buttonStyle(.borderedProminent)
                .glassBackgroundEffect()
                .tint(.blue)
            }
        }
    }
}

#Preview {
    NavigationView(AppModel(), initView: .configView)
        .background(.thinMaterial)
        .frame(maxWidth: 750, maxHeight: 500)
        .glassBackgroundEffect()
}

