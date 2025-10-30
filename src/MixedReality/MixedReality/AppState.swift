import SwiftUI
import Combine   

@MainActor
final class AppState: ObservableObject {
    @Published var hasConsented: Bool {
        didSet { UserDefaults.standard.set(hasConsented, forKey: "hasConsented") }
    }

    init() {
        self.hasConsented = UserDefaults.standard.bool(forKey: "hasConsented")
    }

    func resetConsent() {
        hasConsented = false
    }
}
