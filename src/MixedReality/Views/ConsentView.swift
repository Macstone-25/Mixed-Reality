import SwiftUI

struct ConsentView: View {
    let onAgree: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Text("Research Consent")
                .font(.largeTitle).bold()
                .multilineTextAlignment(.center)

            Text("""
This application will record and analyze audio conversations to provide conversational suggestions and support academic research. Any data retained for research will be anonymized with personal identifiers removed.
""")
                .multilineTextAlignment(.leading)
                .font(.body)
                .padding()
                .background(.thinMaterial)
                .cornerRadius(12)

            Button("Agree") {
                onAgree()
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 12)
        }
        .padding(32)
    }
}
