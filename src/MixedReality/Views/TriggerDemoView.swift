// TriggerDemoView.swift
//
// Demo UI to exercise the EventTriggerEngine. Provides controls to:
// - choose the primary speaker ID,
// - toggle LLM confirmation,
// - simulate user/other utterances,
// - view fired interventions.

import SwiftUI

struct TriggerDemoView: View {
    @StateObject private var svc: TriggerDemoService
    @State private var useLLM: Bool
    @State private var selectedPrimary: String = "user"

    init(useLLM: Bool = false) {
        _svc = StateObject(wrappedValue: TriggerDemoService(useLLM: useLLM))
        _useLLM = State(initialValue: useLLM)
    }

    var body: some View {
        VStack(spacing: 12) {
            // Top controls: primary speaker picker, LLM toggle, reset
            HStack(spacing: 12) {
                // Primary speaker picker
                VStack(alignment: .leading, spacing: 4) {
                    Text("Primary speaker (monitor for pauses)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        Picker("", selection: $selectedPrimary) {
                            Text("user").tag("user")
                            Text("spk_0").tag("spk_0")
                            Text("spk_1").tag("spk_1")
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 260)

                        Button("Apply") {
                            svc.setPrimaryUserID(selectedPrimary)
                        }
                    }
                    Text("Current: \(svc.primaryID)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // LLM gate toggle
                Toggle("LLM augmented", isOn: $useLLM)
                    .onChange(of: useLLM) { svc.setUseLLM($0) }

                Button("Reset") { svc.reset() }
            }

            // Simulate utterances
            HStack {
                Button("User: “I think...”") { svc.userSays("I think...") }
                Button("User: short 'um'") { svc.userSays("um") }
                Button("User: question?") { svc.userSays("should we try this?") }
            }
            HStack {
                Button("Other: okay") { svc.otherSays("okay") }
                Button("Other: long reply") { svc.otherSays("that sounds good, we could try option A first") }
            }

            // Instructions for triggering a pause
            Text("Tip: After a user utterance, wait ~4 seconds to trigger a pause event. If someone else talks after the user, the threshold extends by ~2 seconds.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 6)

            Divider().padding(.vertical, 6)

            // Events log
            List(svc.eventsLog.reversed(), id: \.at) { evt in
                VStack(alignment: .leading, spacing: 4) {
                    Text(evt.reasonSummary)
                        .font(.headline)
                    Text(evt.at.formatted(date: .omitted, time: .standard))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if !evt.context.isEmpty {
                        ForEach(evt.context.indices, id: \.self) { i in
                            let c = evt.context[i]
                            Text("[\(c.speakerID)] \(c.text)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
        .onAppear {
            // Sync picker with current service primary on first load
            selectedPrimary = svc.primaryID
        }
    }
}
