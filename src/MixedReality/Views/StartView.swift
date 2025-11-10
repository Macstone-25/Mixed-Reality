import SwiftUI

struct StartView: View {
    @Environment(AppModel.self) private var appModel
    
    let onStart: () -> Void
    
    var body: some View {
        if appModel.isSessionActive {
            Text("Starting session...")
        } else {
            Button("Start") {
                onStart()
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 12)
        }
    }
}

#Preview {
    StartView {
        print("Started")
    }
}
